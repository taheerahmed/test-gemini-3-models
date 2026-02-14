import CoreLocation

@MainActor
class LocationManager: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
  private var isFetching = false
  private var cachedLocation: (latitude: Double, longitude: Double, description: String)?
  private var cacheTimestamp: Date?
  private let cacheTTL: TimeInterval = 30 // Re-use location for 30s
  private let locationTimeout: TimeInterval = 10 // Timeout if location unavailable

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
  }

  func requestPermission() {
    manager.requestWhenInUseAuthorization()
  }

  func getCurrentLocation() async -> (latitude: Double, longitude: Double, description: String)? {
    // Return cached location if still fresh (avoids concurrent call issues)
    if let cached = cachedLocation,
       let ts = cacheTimestamp,
       Date().timeIntervalSince(ts) < cacheTTL {
      NSLog("[Location] Returning cached location (age: %.1fs)", Date().timeIntervalSince(ts))
      return cached
    }

    // Guard against concurrent calls — second caller waits for cache
    guard !isFetching else {
      NSLog("[Location] Concurrent call blocked — already fetching location")
      try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
      return cachedLocation
    }

    isFetching = true
    manager.requestWhenInUseAuthorization()

    // Start a timeout to prevent infinite hang if permission denied or no GPS
    let timeoutTask = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(10 * 1_000_000_000))
      guard !Task.isCancelled else { return }
      NSLog("[Location] Timeout — resuming with nil")
      self?.locationContinuation?.resume(returning: nil)
      self?.locationContinuation = nil
    }

    let location = await withCheckedContinuation { (cont: CheckedContinuation<CLLocation?, Never>) in
      self.locationContinuation = cont
      manager.requestLocation()
    }

    timeoutTask.cancel()
    isFetching = false

    guard let location else { return nil }

    // Reverse geocode to get hyper-local human-readable location
    let geocoder = CLGeocoder()
    let description: String
    if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
       let place = placemarks.first {
      // Build from most specific to least specific
      // e.g. "Near Innovative Multiplex, Marathahalli, Bengaluru, Karnataka, India"
      var parts: [String] = []

      // POI / landmark name
      if let name = place.name, name != place.subLocality && name != place.locality {
        parts.append("Near \(name)")
      }
      // Street
      if let thoroughfare = place.thoroughfare {
        if let subThoroughfare = place.subThoroughfare {
          parts.append("\(subThoroughfare) \(thoroughfare)")
        } else {
          parts.append(thoroughfare)
        }
      }
      // Neighborhood / area (e.g. Marathahalli, Koramangala)
      if let subLocality = place.subLocality {
        parts.append(subLocality)
      }
      // City
      if let locality = place.locality {
        parts.append(locality)
      }
      // State
      if let state = place.administrativeArea {
        parts.append(state)
      }
      // Country
      if let country = place.country {
        parts.append(country)
      }

      description = parts.joined(separator: ", ")
    } else {
      description = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
    }

    let result = (location.coordinate.latitude, location.coordinate.longitude, description)
    cachedLocation = result
    cacheTimestamp = Date()
    NSLog("[Location] Resolved: %@", description)
    return result
  }

  // MARK: - CLLocationManagerDelegate

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    Task { @MainActor in
      locationContinuation?.resume(returning: locations.last)
      locationContinuation = nil
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      NSLog("[Location] Failed: %@", error.localizedDescription)
      locationContinuation?.resume(returning: nil)
      locationContinuation = nil
    }
  }
}

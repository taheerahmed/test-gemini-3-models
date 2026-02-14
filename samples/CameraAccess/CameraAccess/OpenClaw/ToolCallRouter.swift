import Foundation

@MainActor
class ToolCallRouter {
  private let bridge: OpenClawBridge
  private let locationManager: LocationManager
  private var inFlightTasks: [String: Task<Void, Never>] = [:]

  init(bridge: OpenClawBridge, locationManager: LocationManager) {
    self.bridge = bridge
    self.locationManager = locationManager
  }

  /// Route a tool call from Gemini to OpenClaw. Calls sendResponse with the
  /// JSON dictionary to send back as a toolResponse message.
  func handleToolCall(
    _ call: GeminiFunctionCall,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let callId = call.id
    let callName = call.name

    NSLog("[ToolCall] Received: %@ (id: %@) args: %@",
          callName, callId, String(describing: call.args))

    // Handle get_location locally via CoreLocation
    if callName == "get_location" {
      bridge.lastToolCallStatus = .executing("get_location")
      let task = Task { @MainActor in
        let result = await self.handleGetLocation()
        guard !Task.isCancelled else {
          NSLog("[ToolCall] Task %@ was cancelled, skipping response", callId)
          return
        }
        self.bridge.lastToolCallStatus = .completed("get_location")
        let response = self.buildToolResponse(callId: callId, name: callName, result: result)
        sendResponse(response)
        self.inFlightTasks.removeValue(forKey: callId)
      }
      inFlightTasks[callId] = task
      return
    }

    let task = Task { @MainActor in
      let taskDesc = call.args["task"] as? String ?? String(describing: call.args)
      let result = await bridge.delegateTask(task: taskDesc, toolName: callName)

      guard !Task.isCancelled else {
        NSLog("[ToolCall] Task %@ was cancelled, skipping response", callId)
        return
      }

      NSLog("[ToolCall] Result for %@ (id: %@): %@",
            callName, callId, String(describing: result))

      let response = self.buildToolResponse(callId: callId, name: callName, result: result)
      sendResponse(response)

      self.inFlightTasks.removeValue(forKey: callId)
    }

    inFlightTasks[callId] = task
  }

  /// Cancel specific in-flight tool calls (from toolCallCancellation)
  func cancelToolCalls(ids: [String]) {
    for id in ids {
      if let task = inFlightTasks[id] {
        NSLog("[ToolCall] Cancelling in-flight call: %@", id)
        task.cancel()
        inFlightTasks.removeValue(forKey: id)
      }
    }
    bridge.lastToolCallStatus = .cancelled(ids.first ?? "unknown")
  }

  /// Cancel all in-flight tool calls (on session stop)
  func cancelAll() {
    for (id, task) in inFlightTasks {
      NSLog("[ToolCall] Cancelling in-flight call: %@", id)
      task.cancel()
    }
    inFlightTasks.removeAll()
  }

  // MARK: - Private

  private func handleGetLocation() async -> ToolResult {
    guard let loc = await locationManager.getCurrentLocation() else {
      return .failure("Could not determine location. Location services may be disabled.")
    }
    NSLog("[ToolCall] Location: %@ (%.4f, %.4f)", loc.description, loc.latitude, loc.longitude)
    return .success("Location: \(loc.description) (lat: \(loc.latitude), lon: \(loc.longitude))")
  }

  private func buildToolResponse(
    callId: String,
    name: String,
    result: ToolResult
  ) -> [String: Any] {
    return [
      "toolResponse": [
        "functionResponses": [
          [
            "id": callId,
            "name": name,
            "response": result.responseValue
          ]
        ]
      ]
    ]
  }
}

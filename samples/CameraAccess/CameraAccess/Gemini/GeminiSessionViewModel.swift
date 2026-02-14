import Foundation
import SwiftUI

@MainActor
class GeminiSessionViewModel: ObservableObject {
  @Published var isGeminiActive: Bool = false
  @Published var connectionState: GeminiConnectionState = .disconnected
  @Published var isModelSpeaking: Bool = false
  @Published var errorMessage: String?
  @Published var userTranscript: String = ""
  @Published var aiTranscript: String = ""
  @Published var toolCallStatus: ToolCallStatus = .idle
  @Published var openClawConnectionState: OpenClawConnectionState = .notConfigured
  @Published var alertType: GuardianAlertType = .none
  private let geminiService = GeminiLiveService()
  private let openClawBridge = OpenClawBridge()
  private var toolCallRouter: ToolCallRouter?
  private let audioManager = AudioManager()
  private let locationManager = LocationManager()
  private var lastVideoFrameTime: Date = .distantPast
  private var stateObservation: Task<Void, Never>?

  var streamingMode: StreamingMode = .glasses

  func startSession() async {
    guard !isGeminiActive else { return }

    guard GeminiConfig.isConfigured else {
      errorMessage = "Gemini API key not configured. Open GeminiConfig.swift and replace YOUR_GEMINI_API_KEY with your key from https://aistudio.google.com/apikey"
      return
    }

    isGeminiActive = true

    // Wire audio callbacks
    audioManager.onAudioCaptured = { [weak self] data in
      guard let self else { return }
      Task { @MainActor in
        // iPhone mode: mute mic while model speaks to prevent echo feedback
        // (loudspeaker + co-located mic overwhelms iOS echo cancellation)
        if self.streamingMode == .iPhone && self.geminiService.isModelSpeaking { return }
        self.geminiService.sendAudio(data: data)
      }
    }

    geminiService.onAudioReceived = { [weak self] data in
      self?.audioManager.playAudio(data: data)
    }

    geminiService.onInterrupted = { [weak self] in
      self?.audioManager.stopPlayback()
    }

    geminiService.onTurnComplete = { [weak self] in
      guard let self else { return }
      Task { @MainActor in
        // Clear user transcript when AI finishes responding
        self.userTranscript = ""
      }
    }

    geminiService.onInputTranscription = { [weak self] text in
      guard let self else { return }
      Task { @MainActor in
        self.userTranscript += text
        self.aiTranscript = ""
        self.alertType = .none
      }
    }

    geminiService.onOutputTranscription = { [weak self] text in
      guard let self else { return }
      Task { @MainActor in
        self.aiTranscript += text
        self.detectAlertType()
      }
    }

    // Handle unexpected disconnection
    geminiService.onDisconnected = { [weak self] reason in
      guard let self else { return }
      Task { @MainActor in
        guard self.isGeminiActive else { return }
        self.stopSession()
        self.errorMessage = "Connection lost: \(reason ?? "Unknown error")"
      }
    }

    // Check OpenClaw connectivity and start fresh session
    await openClawBridge.checkConnection()
    openClawBridge.resetSession()

    // Request location permission early so it's ready for scam detection
    locationManager.requestPermission()

    // Wire tool call handling
    toolCallRouter = ToolCallRouter(bridge: openClawBridge, locationManager: locationManager)

    geminiService.onToolCall = { [weak self] toolCall in
      guard let self else { return }
      Task { @MainActor in
        for call in toolCall.functionCalls {
          self.toolCallRouter?.handleToolCall(call) { [weak self] response in
            self?.geminiService.sendToolResponse(response)
          }
        }
      }
    }

    geminiService.onToolCallCancellation = { [weak self] cancellation in
      guard let self else { return }
      Task { @MainActor in
        self.toolCallRouter?.cancelToolCalls(ids: cancellation.ids)
      }
    }

    // Observe service state
    stateObservation = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        guard !Task.isCancelled else { break }
        self.connectionState = self.geminiService.connectionState
        self.isModelSpeaking = self.geminiService.isModelSpeaking
        self.toolCallStatus = self.openClawBridge.lastToolCallStatus
        self.openClawConnectionState = self.openClawBridge.connectionState
      }
    }

    // Setup audio
    do {
      try audioManager.setupAudioSession(useIPhoneMode: streamingMode == .iPhone)
    } catch {
      errorMessage = "Audio setup failed: \(error.localizedDescription)"
      isGeminiActive = false
      return
    }

    // Connect to Gemini and wait for setupComplete
    let setupOk = await geminiService.connect()

    if !setupOk {
      let msg: String
      if case .error(let err) = geminiService.connectionState {
        msg = err
      } else {
        msg = "Failed to connect to Gemini"
      }
      errorMessage = msg
      geminiService.disconnect()
      stateObservation?.cancel()
      stateObservation = nil
      isGeminiActive = false
      connectionState = .disconnected
      return
    }

    // Start mic capture
    do {
      try audioManager.startCapture()
    } catch {
      errorMessage = "Mic capture failed: \(error.localizedDescription)"
      geminiService.disconnect()
      stateObservation?.cancel()
      stateObservation = nil
      isGeminiActive = false
      connectionState = .disconnected
      return
    }
  }

  func stopSession() {
    toolCallRouter?.cancelAll()
    toolCallRouter = nil
    audioManager.stopCapture()
    geminiService.disconnect()
    stateObservation?.cancel()
    stateObservation = nil
    isGeminiActive = false
    connectionState = .disconnected
    isModelSpeaking = false
    userTranscript = ""
    aiTranscript = ""
    toolCallStatus = .idle
    alertType = .none
  }

  // MARK: - Alert Detection

  private func detectAlertType() {
    guard alertType == .none else { return } // Don't override existing alert
    let lower = aiTranscript.lowercased()

    // Fare check keywords (auto, taxi, cab, rickshaw, ride, meter)
    let fareKeywords = ["meter", "fare should be", "fare is", "ride cost", "auto fare", "taxi fare", "cab fare", "rickshaw", "per kilometer", "per km", "base fare", "flag down"]
    if fareKeywords.contains(where: { lower.contains($0) }) {
      alertType = .fareCheck
      return
    }

    // Negotiation coach keywords (rent, deposit, lease, landlord, negotiate, counter, offer)
    let negotiationKeywords = ["rent should be", "monthly rent", "deposit", "security deposit", "lease", "landlord", "negotiate", "counter with", "offer them", "start at", "settle at", "bargain", "walk away if", "don't go above", "opening offer"]
    if negotiationKeywords.contains(where: { lower.contains($0) }) {
      alertType = .negotiationCoach
      return
    }

    // Fair price confirmation
    let fairKeywords = ["fair price", "about right", "reasonable", "good deal", "decent price", "normal price", "standard rate"]
    if fairKeywords.contains(where: { lower.contains($0) }) {
      alertType = .fairPrice
      return
    }

    // Price alert / scam keywords (most general — check last)
    let priceKeywords = ["overcharged", "too expensive", "too much", "scam", "rip-off", "ripoff", "overpriced", "tourist price", "tourist trap", "local price is", "locals pay", "should cost", "way too high", "charging you"]
    if priceKeywords.contains(where: { lower.contains($0) }) {
      alertType = .priceAlert
      return
    }
  }

  func sendVideoFrameIfThrottled(image: UIImage) {
    guard isGeminiActive, connectionState == .ready else { return }
    let now = Date()
    guard now.timeIntervalSince(lastVideoFrameTime) >= GeminiConfig.videoFrameInterval else { return }
    lastVideoFrameTime = now
    geminiService.sendVideoFrame(image: image)
  }

}

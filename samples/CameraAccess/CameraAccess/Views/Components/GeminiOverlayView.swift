import SwiftUI

// MARK: - Status Bar (Top)

struct GeminiStatusBar: View {
  @ObservedObject var geminiVM: GeminiSessionViewModel

  var body: some View {
    HStack(spacing: 6) {
      // Connection indicators — minimal dots
      HStack(spacing: 4) {
        Circle()
          .fill(geminiStatusColor)
          .frame(width: 6, height: 6)
        Circle()
          .fill(openClawStatusColor)
          .frame(width: 6, height: 6)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(.ultraThinMaterial)
      .clipShape(Capsule())

      Spacer()

      // Guardian mode indicator
      if geminiVM.connectionState == .ready {
        GuardianPill(alertType: geminiVM.alertType)
      }
    }
  }

  private var geminiStatusColor: Color {
    switch geminiVM.connectionState {
    case .ready: return .green
    case .connecting, .settingUp: return .yellow
    case .error: return .red
    case .disconnected: return .gray
    }
  }

  private var openClawStatusColor: Color {
    switch geminiVM.openClawConnectionState {
    case .connected: return .green
    case .checking: return .yellow
    case .unreachable: return .red
    case .notConfigured: return .gray
    }
  }
}

// MARK: - Guardian Pill

struct GuardianPill: View {
  let alertType: GuardianAlertType
  @State private var pulseOpacity: Double = 0.4

  private var isAlert: Bool { alertType != .none && alertType != .fairPrice }
  private var accentColor: Color { colorForAlert(alertType) }

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: pillIcon)
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(accentColor)

      Text(pillText)
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundColor(accentColor)
        .tracking(1.5)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(
      Group {
        if isAlert {
          accentColor.opacity(pulseOpacity)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseOpacity)
        } else {
          Color.clear
        }
      }
    )
    .background(.ultraThinMaterial)
    .clipShape(Capsule())
    .overlay(
      Capsule()
        .stroke(accentColor.opacity(isAlert ? 0.8 : 0.3), lineWidth: 1)
    )
    .onAppear {
      if isAlert { pulseOpacity = 0.15 }
    }
    .onChange(of: alertType) {
      pulseOpacity = isAlert ? 0.15 : 0.4
    }
  }

  private var pillIcon: String {
    switch alertType {
    case .none: return "ear.fill"
    case .fairPrice: return "checkmark.shield.fill"
    default: return alertType.headerIcon
    }
  }

  private var pillText: String {
    switch alertType {
    case .none: return "LISTENING"
    case .fairPrice: return "FAIR"
    default: return alertType.headerText
    }
  }
}

// MARK: - Transcript View

struct TranscriptView: View {
  let userText: String
  let aiText: String
  var alertType: GuardianAlertType = .none

  private var hasAlert: Bool { alertType != .none }
  private var isUrgent: Bool { alertType.isUrgent }
  private var accentColor: Color { colorForAlert(alertType) }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Alert header banner
      if hasAlert && alertType != .fairPrice {
        HStack(spacing: 8) {
          Image(systemName: alertType.headerIcon)
            .font(.system(size: 15))
            .foregroundColor(headerForeground)
          Text(alertType.headerText)
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .foregroundColor(headerForeground)
            .tracking(2)
          Spacer()
          // Scenario-specific secondary icon
          scenarioIcon
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(headerGradient)
        .cornerRadius(8)
      }

      // Fair price — compact inline confirmation
      if alertType == .fairPrice {
        HStack(spacing: 6) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 14))
            .foregroundColor(.green)
          Text("Fair price")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.green)
        }
      }

      // Conversation transcript (all speakers — user + vendors/drivers/landlords)
      if !userText.isEmpty {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "waveform")
            .font(.system(size: 10))
            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.6))
            .frame(width: 16)
          VStack(alignment: .leading, spacing: 2) {
            Text("OVERHEARD")
              .font(.system(size: 8, weight: .bold, design: .monospaced))
              .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.4))
              .tracking(1.5)
            Text(userText)
              .font(.system(size: 14))
              .foregroundColor(.white.opacity(0.6))
          }
        }
      }

      // AI transcript (JARVIS response)
      if !aiText.isEmpty {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "shield.fill")
            .font(.system(size: 10))
            .foregroundColor(hasAlert ? accentColor : Color(red: 0.4, green: 0.8, blue: 1.0))
            .frame(width: 16)
          Text(aiText)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white.opacity(0.95))
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(cardBackground)
    .background(.ultraThinMaterial.opacity(hasAlert ? 0.3 : 0.6))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(cardBorder, lineWidth: hasAlert ? 1.5 : 0.5)
    )
  }

  // MARK: - Visual Variants

  @ViewBuilder
  private var scenarioIcon: some View {
    switch alertType {
    case .negotiationCoach:
      Image(systemName: "arrow.left.arrow.right")
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(headerForeground)
    case .fareCheck:
      Image(systemName: "location.fill")
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(headerForeground)
    default:
      EmptyView()
    }
  }

  private var headerForeground: Color {
    switch alertType {
    case .priceAlert: return .black
    case .fareCheck: return .black
    case .negotiationCoach: return .white
    default: return .white
    }
  }

  private var headerGradient: LinearGradient {
    switch alertType {
    case .priceAlert:
      return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
    case .fareCheck:
      return LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .leading, endPoint: .trailing)
    case .negotiationCoach:
      return LinearGradient(colors: [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.3, blue: 0.9)], startPoint: .leading, endPoint: .trailing)
    default:
      return LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
    }
  }

  private var cardBackground: some View {
    Group {
      if isUrgent {
        LinearGradient(
          colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      } else if alertType == .negotiationCoach {
        LinearGradient(
          colors: [Color(red: 0.2, green: 0.3, blue: 0.6).opacity(0.4), Color(red: 0.1, green: 0.15, blue: 0.3).opacity(0.3)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      } else {
        LinearGradient(
          colors: [Color.black.opacity(0.5), Color.black.opacity(0.5)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    }
  }

  private var cardBorder: LinearGradient {
    if hasAlert {
      return LinearGradient(colors: [accentColor, accentColor.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    return LinearGradient(colors: [Color.white.opacity(0.1), Color.clear], startPoint: .top, endPoint: .bottom)
  }
}

// MARK: - Tool Call Status

struct ToolCallStatusView: View {
  let status: ToolCallStatus

  var body: some View {
    if status != .idle {
      HStack(spacing: 8) {
        statusIcon
        Text(statusText)
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(1)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
      .background(.ultraThinMaterial)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
      )
    }
  }

  private var statusText: String {
    switch status {
    case .idle: return ""
    case .executing(let name):
      if name == "get_location" { return "Locating..." }
      return "Researching..."
    case .completed: return "Done"
    case .failed(_, let err): return "Error: \(err)"
    case .cancelled: return "Cancelled"
    }
  }

  @ViewBuilder
  private var statusIcon: some View {
    switch status {
    case .executing:
      ProgressView()
        .scaleEffect(0.6)
        .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
    case .completed:
      Image(systemName: "checkmark")
        .foregroundColor(.green)
        .font(.system(size: 11, weight: .bold))
    case .failed:
      Image(systemName: "xmark")
        .foregroundColor(.red)
        .font(.system(size: 11, weight: .bold))
    case .cancelled:
      Image(systemName: "xmark")
        .foregroundColor(.yellow)
        .font(.system(size: 11, weight: .bold))
    case .idle:
      EmptyView()
    }
  }
}

// MARK: - Speaking Indicator

struct SpeakingIndicator: View {
  @State private var animating = false

  var body: some View {
    HStack(spacing: 2) {
      ForEach(0..<5, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1)
          .fill(
            LinearGradient(
              colors: [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 0.2, green: 0.5, blue: 1.0)],
              startPoint: .bottom,
              endPoint: .top
            )
          )
          .frame(width: 2.5, height: animating ? CGFloat.random(in: 6...18) : 4)
          .animation(
            .easeInOut(duration: 0.25)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.08),
            value: animating
          )
      }
    }
    .onAppear { animating = true }
    .onDisappear { animating = false }
  }
}

// MARK: - Listening Pulse

struct ListeningPulse: View {
  @State private var scale: CGFloat = 1.0
  @State private var opacity: Double = 0.6

  var body: some View {
    Circle()
      .fill(Color(red: 0.4, green: 0.8, blue: 1.0))
      .frame(width: 8, height: 8)
      .scaleEffect(scale)
      .opacity(opacity)
      .animation(
        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
        value: scale
      )
      .onAppear {
        scale = 1.4
        opacity = 0.3
      }
  }
}

// MARK: - Color Helper

func colorForAlert(_ type: GuardianAlertType) -> Color {
  switch type {
  case .none: return Color(red: 0.4, green: 0.8, blue: 1.0)  // Cyan
  case .priceAlert: return .red
  case .negotiationCoach: return Color(red: 0.4, green: 0.4, blue: 1.0)  // Indigo
  case .fareCheck: return .orange
  case .fairPrice: return .green
  }
}

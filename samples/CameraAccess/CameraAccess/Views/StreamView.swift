/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamView.swift
//
// Main UI for video streaming — extended with JARVIS-style guardian overlay.
//

import MWDATCore
import SwiftUI

struct StreamView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  @ObservedObject var wearablesVM: WearablesViewModel
  @ObservedObject var geminiVM: GeminiSessionViewModel

  var body: some View {
    ZStack {
      // Black background
      Color.black
        .edgesIgnoringSafeArea(.all)

      // Video backdrop
      if let videoFrame = viewModel.currentVideoFrame, viewModel.hasReceivedFirstFrame {
        GeometryReader { geometry in
          Image(uiImage: videoFrame)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .edgesIgnoringSafeArea(.all)
      } else {
        ProgressView()
          .scaleEffect(1.5)
          .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
      }

      // JARVIS overlay
      if geminiVM.isGeminiActive {
        VStack(spacing: 0) {
          // Top bar — status indicators
          GeminiStatusBar(geminiVM: geminiVM)
            .padding(.horizontal, 20)
            .padding(.top, 8)

          Spacer()

          // Bottom content area — transcripts, tool status, speaking indicator
          VStack(spacing: 10) {
            // Transcript area
            if !geminiVM.userTranscript.isEmpty || !geminiVM.aiTranscript.isEmpty {
              TranscriptView(
                userText: geminiVM.userTranscript,
                aiText: geminiVM.aiTranscript,
                alertType: geminiVM.alertType
              )
              .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
              ))
            }

            // Tool call status
            ToolCallStatusView(status: geminiVM.toolCallStatus)

            // Speaking indicator
            if geminiVM.isModelSpeaking {
              HStack(spacing: 10) {
                SpeakingIndicator()
                Text("Speaking")
                  .font(.system(size: 11, weight: .medium, design: .monospaced))
                  .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.8))
                  .tracking(1)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(.ultraThinMaterial)
              .clipShape(Capsule())
              .transition(.opacity)
            }
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 90)
          .animation(.easeInOut(duration: 0.3), value: geminiVM.userTranscript)
          .animation(.easeInOut(duration: 0.3), value: geminiVM.aiTranscript)
          .animation(.easeInOut(duration: 0.3), value: geminiVM.isModelSpeaking)
          .animation(.easeInOut(duration: 0.3), value: geminiVM.alertType)
        }
      }

      // Bottom controls
      VStack {
        Spacer()
        ControlsView(viewModel: viewModel, geminiVM: geminiVM)
          .padding(.horizontal, 20)
          .padding(.bottom, 16)
      }
    }
    .onDisappear {
      Task {
        if viewModel.streamingStatus != .stopped {
          await viewModel.stopSession()
        }
        if geminiVM.isGeminiActive {
          geminiVM.stopSession()
        }
      }
    }
    .sheet(isPresented: $viewModel.showPhotoPreview) {
      if let photo = viewModel.capturedPhoto {
        PhotoPreviewView(
          photo: photo,
          onDismiss: {
            viewModel.dismissPhotoPreview()
          }
        )
      }
    }
    .alert("Guardian", isPresented: Binding(
      get: { geminiVM.errorMessage != nil },
      set: { if !$0 { geminiVM.errorMessage = nil } }
    )) {
      Button("OK") { geminiVM.errorMessage = nil }
    } message: {
      Text(geminiVM.errorMessage ?? "")
    }
  }
}

// MARK: - Controls

struct ControlsView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  @ObservedObject var geminiVM: GeminiSessionViewModel

  var body: some View {
    HStack(spacing: 12) {
      // Stop button
      Button {
        Task { await viewModel.stopSession() }
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(.white)
          .frame(width: 48, height: 48)
          .background(Color.red.opacity(0.8))
          .clipShape(Circle())
      }

      Spacer()

      // Photo button (glasses mode only)
      if viewModel.streamingMode == .glasses {
        Button {
          viewModel.capturePhoto()
        } label: {
          Image(systemName: "camera.fill")
            .font(.system(size: 14))
            .foregroundColor(.white)
            .frame(width: 48, height: 48)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(
              Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
        }
      }

      // JARVIS toggle button
      Button {
        Task {
          if geminiVM.isGeminiActive {
            geminiVM.stopSession()
          } else {
            await geminiVM.startSession()
          }
        }
      } label: {
        ZStack {
          // Outer ring glow when active
          if geminiVM.isGeminiActive {
            Circle()
              .stroke(
                LinearGradient(
                  colors: [
                    Color(red: 0.4, green: 0.8, blue: 1.0),
                    Color(red: 0.2, green: 0.5, blue: 1.0)
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 2
              )
              .frame(width: 58, height: 58)

            // Subtle pulse
            ListeningPulse()
              .scaleEffect(6)
              .opacity(0.15)
          }

          VStack(spacing: 2) {
            Image(systemName: geminiVM.isGeminiActive ? "shield.checkered" : "shield")
              .font(.system(size: 16, weight: .semibold))
            if !geminiVM.isGeminiActive {
              Text("GUARD")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .tracking(1)
            }
          }
          .foregroundColor(
            geminiVM.isGeminiActive
              ? Color(red: 0.4, green: 0.8, blue: 1.0)
              : .white.opacity(0.7)
          )
          .frame(width: 52, height: 52)
          .background(
            geminiVM.isGeminiActive
              ? Color(red: 0.1, green: 0.2, blue: 0.3).opacity(0.9)
              : Color.clear
          )
          .background(.ultraThinMaterial)
          .clipShape(Circle())
        }
      }
    }
  }
}

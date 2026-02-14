/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// NonStreamView.swift
//
// Default screen to show getting started tips after app connection
// Initiates streaming
//

import MWDATCore
import SwiftUI

struct NonStreamView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  @ObservedObject var wearablesVM: WearablesViewModel
  @State private var sheetHeight: CGFloat = 300
  @State private var showLanguagePicker = false
  @State private var selectedLanguage = GeminiConfig.userLanguageCode

  var body: some View {
    ZStack {
      Color.black.edgesIgnoringSafeArea(.all)

      VStack {
        HStack {
          // Language selector button
          Button {
            showLanguagePicker = true
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "globe")
                .font(.system(size: 14))
              Text(GeminiConfig.userLanguageName)
                .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
              Capsule()
                .stroke(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.3), lineWidth: 1)
            )
          }

          Spacer()

          Menu {
            Button("Disconnect", role: .destructive) {
              wearablesVM.disconnectGlasses()
            }
            .disabled(wearablesVM.registrationState != .registered)
          } label: {
            Image(systemName: "gearshape")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .foregroundColor(.white)
              .frame(width: 24, height: 24)
          }
        }

        Spacer()

        VStack(spacing: 12) {
          Image(.cameraAccessIcon)
            .resizable()
            .renderingMode(.template)
            .foregroundColor(.white)
            .aspectRatio(contentMode: .fit)
            .frame(width: 120)

          Text("Guardian Mode")
            .font(.system(size: 22, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .tracking(1)

          Text("Your AI guardian watches through your camera and listens to conversations around you. It stays silent until you need it — detecting scams, checking prices, and coaching negotiations.")
            .font(.system(size: 14))
            .multilineTextAlignment(.center)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)

        Spacer()

        HStack(spacing: 8) {
          Image(systemName: "hourglass")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(.white.opacity(0.7))
            .frame(width: 16, height: 16)

          Text("Waiting for an active device")
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 12)
        .opacity(viewModel.hasActiveDevice ? 0 : 1)

        CustomButton(
          title: "Start on iPhone",
          style: .secondary,
          isDisabled: false
        ) {
          Task {
            await viewModel.handleStartIPhone()
          }
        }

        CustomButton(
          title: "Start streaming",
          style: .primary,
          isDisabled: !viewModel.hasActiveDevice
        ) {
          Task {
            await viewModel.handleStartStreaming()
          }
        }
      }
      .padding(.all, 24)
    }
    .sheet(isPresented: $showLanguagePicker) {
      LanguagePickerView(selectedLanguage: $selectedLanguage) {
        GeminiConfig.userLanguageCode = selectedLanguage
        showLanguagePicker = false
      }
    }
    .sheet(isPresented: $wearablesVM.showGettingStartedSheet) {
      if #available(iOS 16.0, *) {
        GettingStartedSheetView(height: $sheetHeight)
          .presentationDetents([.height(sheetHeight)])
          .presentationDragIndicator(.visible)
      } else {
        GettingStartedSheetView(height: $sheetHeight)
      }
    }
  }
}

struct GettingStartedSheetView: View {
  @Environment(\.dismiss) var dismiss
  @Binding var height: CGFloat

  var body: some View {
    VStack(spacing: 24) {
      Text("Getting started")
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.primary)

      VStack(spacing: 12) {
        TipItemView(
          resource: .videoIcon,
          text: "First, Camera Access needs permission to use your glasses camera."
        )
        TipItemView(
          resource: .tapIcon,
          text: "Capture photos by tapping the camera button."
        )
        TipItemView(
          resource: .smartGlassesIcon,
          text: "The capture LED lets others know when you're capturing content or going live."
        )
      }
      .padding(.bottom, 16)

      CustomButton(
        title: "Continue",
        style: .primary,
        isDisabled: false
      ) {
        dismiss()
      }
    }
    .padding(.all, 24)
    .background(
      GeometryReader { geo -> Color in
        DispatchQueue.main.async {
          height = geo.size.height
        }
        return Color.clear
      }
    )
  }
}

struct TipItemView: View {
  let resource: ImageResource
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(resource)
        .resizable()
        .renderingMode(.template)
        .foregroundColor(.primary)
        .aspectRatio(contentMode: .fit)
        .frame(width: 24)
        .padding(.leading, 4)
        .padding(.top, 4)

      Text(text)
        .font(.system(size: 15))
        .foregroundColor(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Language Picker

struct LanguagePickerView: View {
  @Binding var selectedLanguage: String
  let onDone: () -> Void

  var body: some View {
    NavigationView {
      List {
        ForEach(GeminiConfig.supportedLanguages, id: \.code) { lang in
          Button {
            selectedLanguage = lang.code
          } label: {
            HStack {
              Text(lang.flag)
                .font(.system(size: 20))
              VStack(alignment: .leading, spacing: 2) {
                Text(lang.name)
                  .font(.system(size: 16, weight: .medium))
                  .foregroundColor(.primary)
                if lang.code == "auto" {
                  Text("JARVIS detects your language automatically")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
              }
              Spacer()
              if selectedLanguage == lang.code {
                Image(systemName: "checkmark")
                  .font(.system(size: 14, weight: .bold))
                  .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
              }
            }
            .padding(.vertical, 4)
          }
        }
      }
      .navigationTitle("Response Language")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            onDone()
          }
          .fontWeight(.semibold)
        }
      }
    }
  }
}

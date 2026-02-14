# Sentinel

A real-time, multilingual AI guardian for Meta Ray-Ban smart glasses. Sees what you see, hears what you hear, and takes action on your behalf — all through voice, in any language.

### Highlights

- **Vision Integration** — Live camera feed from Meta Ray-Ban glasses (or iPhone) streams to [Gemini Live API](https://ai.google.dev/gemini-api/docs/live) at ~1fps. Gemini fuses video with audio in real-time to understand scenes, read price boards, identify speakers, and detect when you're being overcharged — all without a single button press.

- **OpenClaw Agentic Execution** — When the AI needs to act on your behalf, it delegates to [OpenClaw](https://github.com/nichochar/openclaw), a local gateway with 56+ skills: web search for local prices, sending messages on WhatsApp/Telegram/Signal, managing shopping lists, controlling smart home devices, and more. Gemini thinks, OpenClaw acts.

- **Multilingual Support** — Built to operate across 21+ languages including English, Hindi, Kannada, Tamil, Telugu, Bengali, Marathi, Malayalam, Urdu, Gujarati, Punjabi, Spanish, French, German, Japanese, Korean, Chinese, Arabic, Portuguese, Russian, and Thai. The AI understands all languages simultaneously through the mic — if a vendor switches languages to discuss charging you more, it catches that too.

---

## Built On

This project is a **derivative work** built on top of [**VisionClaw**](https://github.com/sseanliu/VisionClaw) by [Sean Liu](https://github.com/sseanliu), which itself extends Meta's [CameraAccess sample](https://github.com/facebook/meta-wearables-dat-ios) from the Wearables DAT SDK.

### What VisionClaw provides (the foundation we build on)

Sean Liu's VisionClaw established the core real-time AI pipeline for Meta Ray-Ban glasses:

- **Gemini Live API integration** — bidirectional WebSocket streaming of audio + video to Google's multimodal model
- **Audio pipeline** — mic capture at PCM 16kHz, AI playback at PCM 24kHz, with proper echo cancellation
- **Video pipeline** — camera frames throttled to ~1fps, JPEG-compressed, and streamed to Gemini
- **OpenClaw bridge** — HTTP client that gives Gemini access to 56+ real-world tools (messaging, web search, smart home, etc.) via the [OpenClaw](https://github.com/nichochar/openclaw) gateway
- **Streaming transcript UI** — real-time display of user speech and AI responses
- **Session management** — conversation history, session keys, and graceful reconnection

### What we added (Guardian AI layer)

We took VisionClaw's vision + audio + agentic foundation and built **Sentinel** — an intelligent guardian — on top of it:

| Feature | What it does |
|---------|-------------|
| **JARVIS Guardian Mode** | Complete system instruction that transforms Gemini from a general assistant into a silent, proactive guardian that only speaks when it has something genuinely useful to say |
| **Multi-party conversation awareness** | Distinguishes the user from vendors, drivers, landlords, and bystanders using context clues + camera feed — never confuses who said what |
| **Hyper-local intelligence** | GPS + reverse geocoding to neighborhood/POI level ("Near Innovative Multiplex, Marathahalli, Bengaluru") — all price research uses exact location |
| **Proactive research** | The moment a price is mentioned or a price board is seen, tools fire immediately — the answer is ready before the user needs it |
| **Live negotiation coaching** | Phase-aware bargaining guidance (opening → counter → closing) with BATNA awareness |
| **Non-blocking tool calls** | Gemini keeps listening to the conversation while tools execute in the background — no dead silence during research |
| **Transcript context injection** | Buffers what was said during async tool calls and injects it into the result, so Gemini never loses conversational context |
| **Alert classification UI** | Glass-morphism overlay with scenario-specific alerts (price alert, negotiation coach, fare check, fair price) — urgent vs. informational visual treatment |
| **iPhone camera mode** | Full pipeline testing without glasses using the iPhone's back camera |
| **Interruption hardening** | Background speech from vendors/bystanders no longer cuts off AI alerts mid-sentence |
| **Latency optimization** | Tuned video frame interval, JPEG quality, audio chunk size, and network settings for faster end-to-end response |

### The stack

```
┌─────────────────────────────────────────────────────────────┐
│  Sentinel (this project)                                     │
│  JARVIS personality, multi-party awareness, hyper-local      │
│  intelligence, negotiation coaching, alert classification    │
├─────────────────────────────────────────────────────────────┤
│  VisionClaw by Sean Liu                                      │
│  Gemini Live WebSocket, audio/video pipelines, OpenClaw      │
│  bridge, transcript UI, session management                   │
├─────────────────────────────────────────────────────────────┤
│  Meta Wearables DAT SDK (CameraAccess sample)                │
│  Ray-Ban glasses camera streaming, device pairing            │
├─────────────────────────────────────────────────────────────┤
│  Gemini Live API          │  OpenClaw Gateway                │
│  Real-time multimodal AI  │  56+ tools, messaging, search    │
└───────────────────────────┴─────────────────────────────────┘
```

---

## What It Does

Put on your glasses, tap the AI button, and talk:

- **"What am I looking at?"** — Gemini sees through your glasses camera and describes the scene
- **"How much is this coconut water?"** — Instantly researches local prices and whispers "That's 200? In Koramangala that's 30-40 rupees. Counter with 35."
- **"Add milk to my shopping list"** — Delegates to OpenClaw, which executes via your connected apps
- **"Send a message to John saying I'll be late"** — Routes through OpenClaw to WhatsApp/Telegram/iMessage

The glasses camera streams at ~1fps to Gemini for visual context while audio flows bidirectionally in real-time. When Gemini needs to take action, it calls tools through OpenClaw's gateway running on your Mac.

---

## Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Meta Ray-Ban Glasses                             │
│               (or iPhone camera for testing)                         │
│                                                                      │
│    Camera: 24fps video    Mic: ambient + user speech                 │
└──────────────┬──────────────────────────┬────────────────────────────┘
               │                          │
               ▼                          ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      iOS App (Sentinel)                              │
│                                                                      │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────────┐  │
│  │ StreamSession    │  │ AudioManager     │  │ LocationManager    │  │
│  │ ViewModel        │  │                  │  │                    │  │
│  │                  │  │ Mic → PCM 16kHz  │  │ GPS + reverse      │  │
│  │ Throttles video  │  │ mono, 100ms      │  │ geocoding →        │  │
│  │ to ~1fps JPEG    │  │ chunks           │  │ "Near Cafe Coffee  │  │
│  │ (50% quality)    │  │                  │  │  Day, Koramangala, │  │
│  │                  │  │ Speaker ← PCM    │  │  Bengaluru"        │  │
│  │                  │  │ 24kHz playback   │  │                    │  │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬───────────┘  │
│           │                     │                      │             │
│           ▼                     ▼                      │             │
│  ┌──────────────────────────────────────────┐          │             │
│  │       GeminiLiveService (WebSocket)      │          │             │
│  │                                          │          │             │
│  │  Sends: base64 JPEG frames + PCM audio   │          │             │
│  │  Receives: PCM audio + text + tool calls │          │             │
│  └──────────────────┬───────────────────────┘          │             │
│                     │                                  │             │
│                     ▼                                  │             │
│  ┌──────────────────────────────────────────┐          │             │
│  │         ToolCallRouter                   │◄─────────┘             │
│  │                                          │                        │
│  │  get_location → LocationManager          │                        │
│  │  execute      → OpenClawBridge (HTTP)    │                        │
│  │                                          │                        │
│  │  Injects transcript context into results │                        │
│  └──────────────────┬───────────────────────┘                        │
└─────────────────────┼────────────────────────────────────────────────┘
                      │
                      │ HTTP POST /v1/chat/completions
                      │ (Bearer token auth, session continuity)
                      ▼
┌──────────────────────────────────────────────────────────────────────┐
│                   OpenClaw Gateway (Your Mac)                        │
│                   ws://your-mac.local:18789                          │
│                                                                      │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────────────┐  │
│  │ HTTP Server     │  │ Agent Runtime   │  │ Channel Integrations │  │
│  │                 │  │ (Pi agent, RPC) │  │                      │  │
│  │ OpenAI-compat   │  │                 │  │ WhatsApp, Telegram,  │  │
│  │ /v1/chat/       │  │ Tool execution  │  │ Slack, Discord,      │  │
│  │ completions     │  │ with 56+ skills │  │ Signal, iMessage     │  │
│  └────────────────┘  └─────────────────┘  └──────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Gemini Live API (Cloud)                            │
│            gemini-2.5-flash-native-audio-preview                     │
│                                                                      │
│  Multimodal fusion: audio + video processed together                 │
│  Native audio I/O: no STT/TTS round-trip latency                    │
│  Function calling: built-in tool execution protocol                  │
│  Bidirectional WebSocket: real-time streaming                        │
└──────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Camera** captures frames from glasses (DAT SDK, 24fps) or iPhone (`AVCaptureSession`, 30fps)
2. **Throttle** to ~1fps, compress to JPEG (35% quality), base64 encode
3. **Mic** captures audio via `AVAudioEngine`, converts to PCM Int16 16kHz mono, accumulates 100ms chunks
4. **WebSocket** sends video frames + audio chunks to Gemini Live API
5. **Gemini** fuses audio + video context, decides to respond with speech or a tool call
6. **Speech path**: Gemini returns PCM 24kHz audio, `AudioManager` plays through speaker
7. **Tool path**: Gemini sends `toolCall` → `ToolCallRouter` dispatches to `LocationManager` or `OpenClawBridge`
8. **OpenClaw** executes the task (web search, messaging, lists, etc.) and returns the result
9. **Tool response** goes back to Gemini with any buffered transcript context
10. **Gemini** speaks the result to the user

---

## What We Built on Top of Gemini

Standard Gemini Live provides real-time audio + vision over WebSocket. Sentinel adds several layers that transform it into an agentic guardian:

### Multi-Party Conversation Awareness

Base Gemini hears audio as a single stream. Sentinel's system prompt + camera feed enable speaker attribution:

- Distinguishes the **user** from **vendors**, **drivers**, **landlords**, and **bystanders**
- Uses camera context to identify who's behind the counter vs. who's holding the phone
- Tracks conversational flow: price quote → question → counter-offer
- Attributes speech correctly: "The vendor is asking 500" — never "you said 500"

### Proactive Research (Anticipate, Don't React)

Sentinel doesn't wait for the user to ask. The moment it hears a price inquiry or sees a price board through the camera, it **immediately** calls tools to start researching local market rates — so the answer is ready before the user needs it.

### Hyper-Local Intelligence

GPS + reverse geocoding produces neighborhood-level context: not "Bengaluru" but "Near Innovative Multiplex, Marathahalli, Bengaluru." All price research and negotiation coaching uses this exact location for accuracy.

### Agentic Execution via OpenClaw

Gemini alone can only respond with text/audio. Through OpenClaw, Sentinel can **take real actions**: search the web, send messages on WhatsApp/Telegram, manage shopping lists, control smart home devices — 56+ skills.

### Live Negotiation Coaching

Real-time bargaining guidance through three phases:

| Phase | Example |
|-------|---------|
| **Opening** | "They're asking 25,000 for a 1BHK. Market is 14,000. Start at 12,000." |
| **Counter** | "They said 18,000. Good, they're coming down. Hold at 14,000 one more round." |
| **Closing** | "16,000 is fair for this area. Take it." |

Includes BATNA awareness: "If this doesn't work, there are 3 similar PGs within 500m for 8,000-10,000."

### Transcript Context Injection

When Gemini makes a tool call, the user's conversation continues. VisionClaw buffers what was said during the async research and injects it into the tool response, so Gemini never loses conversational context.

### Alert Classification

Responses are categorized by urgency for visual priority in the UI:

- `priceAlert` — Urgent: vendor overcharging
- `negotiationCoach` — Active bargaining
- `fareCheck` — Urgent: taxi fare verification
- `fairPrice` — Brief: price is acceptable

---

## Key Files

All source code is in `samples/CameraAccess/CameraAccess/`:

| File | Purpose |
|------|---------|
| `Gemini/GeminiConfig.swift` | Model config, system prompt (JARVIS personality), tool declarations |
| `Gemini/GeminiLiveService.swift` | WebSocket client for Gemini Live API |
| `Gemini/AudioManager.swift` | Mic capture (PCM 16kHz) + audio playback (PCM 24kHz) |
| `Gemini/GeminiSessionViewModel.swift` | Session lifecycle, tool call wiring, transcript state |
| `OpenClaw/ToolCallModels.swift` | Tool declarations and data types |
| `OpenClaw/OpenClawBridge.swift` | HTTP client for OpenClaw gateway with session continuity |
| `OpenClaw/ToolCallRouter.swift` | Routes Gemini tool calls to OpenClaw or local services |
| `iPhone/IPhoneCameraManager.swift` | `AVCaptureSession` wrapper for iPhone camera mode |
| `iPhone/LocationManager.swift` | GPS + reverse geocoding for hyper-local context |

---

## Audio Pipeline

```
iPhone Mic → AVAudioEngine tap (Float32, 48kHz)
           → AVAudioConverter (Int16 PCM, 16kHz mono)
           → Accumulate 100ms chunks (3200 bytes)
           → Base64 encode → Gemini WebSocket

Gemini → PCM 24kHz audio (base64) → AudioManager playback queue → Speaker
```

- **iPhone mode**: `.voiceChat` audio session — aggressive echo cancellation + mic gating during AI speech
- **Glasses mode**: `.videoChat` audio session — mic is on glasses, speaker is on phone (no echo)

## Video Pipeline

```
Meta Ray-Ban (24fps via DAT SDK)  OR  iPhone back camera (30fps via AVCaptureSession)
  → Throttle to ~1fps
  → JPEG compression (35% quality, ~15-30KB)
  → Base64 encode → Gemini WebSocket
```

---

## Quick Start

### 1. Clone and open

```bash
git clone https://github.com/sseanliu/VisionClaw.git
cd VisionClaw/samples/CameraAccess
open CameraAccess.xcodeproj
```

### 2. Add your Gemini API key

Get a free API key at [Google AI Studio](https://aistudio.google.com/apikey).

Copy the secrets template and fill in your key:

```bash
cp CameraAccess/Secrets.swift.example CameraAccess/Secrets.swift
```

Edit `Secrets.swift`:

```swift
static let geminiAPIKey = "YOUR_GEMINI_API_KEY"  // paste your key here
```

### 3. Set your Development Team

Open `CameraAccess.xcodeproj` in Xcode, go to **Signing & Capabilities**, and select your Apple Development Team.

### 4. Build and run

Select your iPhone as the target device and hit **Run** (Cmd+R).

### 5. Try it out

**Without glasses (iPhone mode):**
1. Tap **"Start on iPhone"** — uses your iPhone's back camera
2. Tap the **AI button** to start a Gemini Live session
3. Talk to the AI — it can see through your iPhone camera

**With Meta Ray-Ban glasses:**

First, enable Developer Mode in the Meta AI app:
1. Open the **Meta AI** app on your iPhone
2. Go to **Settings** (gear icon, bottom left)
3. Tap **App Info**
4. Tap the **App version** number **5 times** — this unlocks Developer Mode
5. Go back to Settings — you'll now see a **Developer Mode** toggle. Turn it on.

Then in VisionClaw:
1. Tap **"Start Streaming"** in the app
2. Tap the **AI button** for voice + vision conversation

---

## Setup: OpenClaw (Optional)

OpenClaw gives Gemini the ability to take real-world actions: send messages, search the web, manage lists, control smart home devices, and more. Without it, Gemini is voice + vision only.

### 1. Install and configure OpenClaw

Follow the [OpenClaw setup guide](https://github.com/nichochar/openclaw). Make sure the gateway is enabled:

In `~/.openclaw/openclaw.json`:

```json
{
  "gateway": {
    "port": 18789,
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "your-gateway-token-here"
    },
    "http": {
      "endpoints": {
        "chatCompletions": { "enabled": true }
      }
    }
  }
}
```

Key settings:
- `bind: "lan"` — exposes the gateway on your local network so your iPhone can reach it
- `chatCompletions.enabled: true` — enables the `/v1/chat/completions` endpoint (off by default)
- `auth.token` — the token your iOS app will use to authenticate

### 2. Configure the iOS app

In `Secrets.swift`, update the OpenClaw settings:

```swift
static let openClawHost = "http://Your-Mac.local"           // your Mac's Bonjour hostname
static let openClawPort = 18789
static let openClawGatewayToken = "your-gateway-token-here"  // must match gateway.auth.token
```

To find your Mac's Bonjour hostname: **System Settings > General > Sharing** — it's shown at the top (e.g., `Johns-MacBook-Pro.local`).

### 3. Start the gateway

```bash
openclaw gateway restart
```

Verify it's running:

```bash
curl http://localhost:18789/health
```

Now when you talk to the AI, it can execute tasks through OpenClaw.

---

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Gemini API key ([get one free](https://aistudio.google.com/apikey))
- Meta Ray-Ban glasses (optional — use iPhone mode for testing)
- OpenClaw on your Mac (optional — for agentic actions)

## Troubleshooting

**"Gemini API key not configured"** — Make sure you copied `Secrets.swift.example` to `Secrets.swift` and added your API key.

**OpenClaw connection timeout** — Make sure your iPhone and Mac are on the same Wi-Fi network, the gateway is running (`openclaw gateway restart`), and the hostname in `Secrets.swift` matches your Mac's Bonjour name.

**Echo/feedback in iPhone mode** — The app mutes the mic while the AI is speaking. If you still hear echo, try turning down the volume.

**Gemini doesn't hear me** — Check that microphone permission is granted. The app uses aggressive voice activity detection — speak clearly and at normal volume.

For DAT SDK issues, see the [developer documentation](https://wearables.developer.meta.com/docs/develop/) or the [discussions forum](https://github.com/facebook/meta-wearables-dat-ios/discussions).

## License

This source code is licensed under the license found in the [LICENSE](LICENSE) file in the root directory of this source tree.

# Forge — an iPhone app whose screens the AI writes on the go

You type a request ("organize my day as a timeline", "a quick expense logger").
A chat model (reached through your **sub2api** gateway / ChatGPT subscription)
writes a complete HTML/JS screen. The app renders it in a `WKWebView`, and that
AI-generated UI can call back into native iOS to read your **calendar**, add
**events**, fire **notifications**, and open **WhatsApp**.

Built for **personal use** with a **free Apple ID** (no $99 developer program
needed — apps re-sign every 7 days).

---

## How it works

```
You type a request
        │
        ▼
LLMClient ──POST /v1/chat/completions──▶ sub2api gateway ──▶ your ChatGPT sub
        │                                        │
        │◀──────── HTML document ────────────────┘
        ▼
WKWebView renders the HTML
        │  the HTML calls nativeCall("calendar.add", {...})
        ▼
NativeBridge → EventKit / UserNotifications / WhatsApp deep link
```

The model is told (in `SystemPrompt.swift`) to return one self-contained HTML
document and is given the `nativeCall(action, payload)` bridge API. That bridge
is implemented natively in `NativeBridge.swift`.

### Bridge actions available to the AI-generated UI
| Action | Payload | Returns |
|---|---|---|
| `calendar.list` | `{ days }` | `{ events: [{title,start,end,calendar}] }` |
| `calendar.add` | `{ title, start, end?, notes? }` | `{ ok: true }` |
| `notify` | `{ title, body, date }` | `{ ok: true }` |
| `whatsapp` | `{ phone, text }` | opens chat (outbound only) |
| `haptic` | `{}` | `{ ok: true }` |

---

## Project layout

```
project.yml              XcodeGen spec — generates Forge.xcodeproj
Resources/Info.plist     Permissions (calendar/reminders), WhatsApp scheme, ATS
Sources/
  ForgeApp.swift         @main entry
  ContentView.swift      Prompt bar + WebView + Settings sheet
  SettingsView.swift     Base URL / API key / model (stored in UserDefaults)
  WebView.swift          WKWebView wrapper + injects nativeCall()
  NativeBridge.swift     Handles bridge calls (EventKit, notifications, WhatsApp)
  LLMClient.swift        OpenAI-compatible /v1/chat/completions client
  SystemPrompt.swift     Instructions that make the model emit UI
  UIHTML.swift           Built-in welcome + error screens
```

---

## Build & run (on a Mac)

### 1. Generate the Xcode project
The repo intentionally does **not** commit `Forge.xcodeproj`. Generate it with
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
cd Personal-app
xcodegen generate
open Forge.xcodeproj
```

> No XcodeGen / prefer the GUI? Create a new iOS App project in Xcode
> (SwiftUI, name **Forge**), delete its starter files, drag the `Sources/`
> files and `Resources/Info.plist` in, and set the Info.plist + the
> permission keys to match `Resources/Info.plist`.

### 2. Sign with your free Apple ID
In Xcode → target **Forge** → **Signing & Capabilities**:
- Check **Automatically manage signing**
- **Team** → add your Apple ID (free is fine)
- If the bundle id `com.personalapp.forge` is taken, change it to something
  unique like `com.<yourname>.forge`

### 3. Run on your iPhone
- Plug in your iPhone, select it as the run destination, press ▶.
- First launch: on the iPhone, **Settings → General → VPN & Device Management**
  → trust your developer certificate.
- Free-account apps stop launching after **7 days** — just re-run from Xcode to
  re-sign. (Tools like AltStore/SideStore can automate the weekly re-sign.)

### 4. Point it at your LLM endpoint
Open the app → tap the **gear** icon → set:
- **Base URL** — your sub2api host, e.g. `https://your-sub2api-host`
  (the app appends `/v1/chat/completions`)
- **API key** — the key sub2api issues you
- **Model** — e.g. `gpt-4o`

Tap **Show today's schedule** on the welcome screen to confirm the calendar
bridge works, then type a real request.

---

## About the sub2api backend

This app is just an OpenAI-compatible client — it works with **any** endpoint
that speaks `/v1/chat/completions`. You stand up
[sub2api](https://github.com/Wei-Shaw/sub2api) separately and give the app its
URL + key.

⚠️ **Heads-up:** sub2api routes requests through your **ChatGPT subscription**
rather than the official API. Its own README warns this **may violate
OpenAI/Anthropic terms of service** and can get the **account banned**. Use a
secondary account, not your main one. To switch to a clean, stable setup later,
just put the **official OpenAI (or Anthropic-compatible) API** URL + key in
Settings — no code changes.

---

## Known limits (by design)

- **WhatsApp is outbound only.** iOS sandboxing + WhatsApp's lack of a personal
  API mean an app *cannot read your chats*. `whatsapp` just opens a pre-filled
  chat for you to send. Anything claiming to read personal WhatsApp uses the
  unofficial WhatsApp-Web protocol and will get your number banned — not
  included here.
- **No on-device native code compilation.** iOS forbids downloading and running
  new native code, so the AI writes **HTML/JS** (rendered in the WebView), not
  Swift. This is the supported, App-Store-legal way to "code the UI on the go".
- **Real alarms** (ring through silent/Focus) need iOS 26's AlarmKit; this
  starter uses local notifications. Easy to add later.

---

## Next ideas
- Persist generated screens as "saved tools" you can relaunch
- A WidgetKit extension showing your next events on the home screen
- A JS↔Swift event so generated UIs can stream/refresh
- Swap in AlarmKit for true alarms on iOS 26+

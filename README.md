# Nest

Nest turns a messy Downloads folder into something you can search and trust.
It watches for new files, works out what each one actually is, tracks the
important dates buried inside them, and lets you find anything by describing
it in plain English — or by talking to it. It never deletes or moves a file
without you saying so.

---

## What Nest Is

Nest is three things working together:

1. **A quiet filesystem watcher.** The moment a file finishes downloading
   into your chosen folder, Nest reads it — text, metadata, even OCR on
   images — and works out what it is: an invoice, a passport scan, a lecture
   slide, a screenshot, a boarding pass.
2. **A document-intelligence layer.** Beyond naming the category, Nest looks
   for dates that matter — a passport expiry, a policy renewal, a payment
   deadline — and tells them apart from dates that don't (a flight date isn't
   an "expiry").
3. **A local, private assistant.** Type or speak a question — "show me
   insurance documents", "what expires this month", "Hey Nest, find the
   invoice from Amazon" — and Nest answers from what it already knows about
   your files, using an AI model that runs entirely on your Mac if you choose
   to turn it on.

Nothing about Nest requires the cloud. Local rule-based classification and
search work with zero setup; AI (via a free, local Ollama model) and voice
commands are both optional, off until you explicitly enable them, and
everything stays on your machine either way.

---

## Download

**[Download Nest for Mac (.dmg)](https://github.com/debmukdm-jioinstitute/nest/releases/latest/download/Nest-1.0.dmg)**
— for Apple Silicon Macs (M1 and later) running macOS 14 (Sonoma) or later.

Open the `.dmg` and drag **Nest** into the **Applications** shortcut in the
same window. This build isn't notarized (no paid Apple Developer certificate
is involved in producing it), so the first time you open it macOS will warn
that it's from an unidentified developer — right-click (Control-click) **Nest**
in Applications, choose **Open**, then confirm **Open** in the dialog. You
only need to do this once. See the [releases page](https://github.com/debmukdm-jioinstitute/nest/releases)
for past versions and full notes.

---

## How to Use Nest

### 1. Build and run

```bash
swift build
swift run
```

This opens a real, windowed macOS app. (See [Running from source](#running-from-source)
under *For Developers* for what this does and doesn't set up yet.)

### 2. First launch

- **Pick a folder.** Defaults to `~/Downloads`, but any folder works.
- **Decide on AI.** You'll be asked whether to set up local AI. Say yes and
  Nest installs/starts Ollama and downloads a small model for you — no
  terminal commands needed. Say no (or skip) and Nest still works fully,
  just with rule-based classification instead of AI.
- That's it — Nest starts watching immediately and classifies whatever's
  already in the folder as well as anything new.

### 3. Everyday use

- **Drop files in as usual.** Nest classifies them in the background; the
  **Activity** tab shows it happening in real time.
- **Search instead of browsing.** Open **Search** and type naturally:
  *"invoice from Amazon last month"*, *"receipts over ₹5,000"*, *"the
  presentation from yesterday"*.
- **Check what needs attention.** **Overview** shows what's new, what's
  unorganized, and — once you have tracked dates — a "Today's Attention" list.
- **Track important dates.** Open **Expiry Center** to see everything
  expiring, due, or renewing, grouped by urgency, and run "Scan for
  Important Dates" over files you already had before installing Nest.
- **Clean up in bulk.** **Rules** groups everything Nest hasn't filed away
  yet and lets you approve moves in batches instead of one at a time.
- **Talk to it.** Press **⌘ + ⌥ (Command+Option)** together anywhere on your
  Mac, say what you're looking for, and Nest searches for you. Turn on "Hey
  Nest" in Settings if you'd rather use a wake word than a key combo.

### 4. Turning features on or off

Everything optional lives in **Settings**:

| Section | Controls |
|---|---|
| **AI Processing** | Enable/disable local AI classification, pick a different Ollama model, check connection status. |
| **Expiry Notifications** | Choose how many days before something expires you want a heads-up (90/30/7/on-the-day), and whether low-confidence detections should stay silent. |
| **Talk to Nest** | Enable voice commands, the "Hey Nest" wake word, and spoken confirmations. |

---

## Capabilities

What Nest can actually do for you:

| Capability | What it means for you |
|---|---|
| **Automatic understanding** | Every new download gets read, classified, and filed by type — no manual tagging. |
| **Plain-English search** | Ask for what you want instead of remembering filenames or folder structure. |
| **Voice control** | Talk to Nest with a hotkey or wake word instead of typing. |
| **Date & deadline tracking** | Nest finds expiry dates, deadlines, and renewals inside your documents and warns you before they matter. |
| **Duplicate detection** | Identical files are flagged, never silently duplicated across folders. |
| **Safe organization** | Files only move when you approve it — every move is logged and reversible. |
| **Works fully offline** | Local classification, search, hashing, and OCR need no internet connection at all. |
| **Private by default** | AI, when enabled, runs on your Mac via Ollama; nothing is ever uploaded. |

---

## Functionalities (Feature by Feature)

**Overview** — your dashboard: files processed today/this week, how many are
unorganized, storage used, and (once you have tracked dates) a "Today's
Attention" list of what's expiring soon.

**All Files** — every file Nest knows about, filterable by name.

**Categories** — your library organized by type (Work, Finance, Education,
Personal, Images, Other), each with relevant subcategories (Invoices,
Receipts, Assignments, Screenshots, ...), plus a "Needs Review" bucket for
anything Nest wasn't confident about.

**Search** — type a natural-language query and get ranked results across
filenames, metadata, extracted text, and tags. Ask something more specific
("invoices over ₹10,000 from last month") and, with AI enabled, Nest turns
that into structured filters automatically.

**Expiry Center** — everything with a date that matters, grouped into
**Expired**, **Expiring Soon**, and **Upcoming**, with a **Needs Review**
queue for anything ambiguous. Every detected date shows *why* it was flagged
(the exact source text) and its confidence. From here you can:
- Confirm, correct, or ignore a detection
- Edit the date by hand
- Add it to your Calendar with a reminder offset (90/60/30/7 days before)
- Filter by status, category, or a plain-English query like "what expires
  this month"
- Run "Scan for Important Dates" to retroactively check files you already had

**Rules** — click "Organize Downloads" to see everything unfiled grouped by
where it would go (e.g. "12 invoices → Finance/Invoices"), review the list,
and apply the move in one click. Nothing moves without this explicit step.

**Activity** — a running log of everything Nest has done: files detected,
classified, moved, renamed, flagged as duplicates, or undone.

**Settings** — manage the Downloads folder Nest watches, AI processing,
expiry notification timing, and voice commands.

**Talk to Nest** — press **⌘+⌥** anywhere, or say **"Hey Nest"** (if
enabled), then say what you're looking for. Nest transcribes it on-device
and runs it as a search, optionally confirming out loud what it's searching
for.

**File detail actions** — select any file to see its thumbnail, size,
category, tags, AI summary, detected entities, and duplicate status, with
one-click **Open**, **Reveal in Finder**, **Rename** (AI can suggest a
clearer name — you approve it), **Move**, **Change Category**, and **Ask
AI** for a question about that specific document.

---

## For Developers

The sections below are engineering notes: architecture decisions, real bugs
found and fixed along the way, what's deliberately out of scope for this
pass, and the honest limitations of running this as a bare Swift Package in
an environment without full Xcode.

### Running from source

```bash
swift build
swift run
```

This opens a real windowed SwiftUI app, but App Sandbox / notarization aren't
configured in this SPM form — do that when you migrate to an Xcode app
target (see below).

### Why it's a Swift Package, not an `.xcodeproj`

This was built in an environment with Xcode Command Line Tools only (no
Xcode.app), so SwiftData's `@Model` macro — which ships only inside Xcode's
toolchain — isn't available here. The app therefore uses a small local-first
JSON-file store (`LibraryStore`) behind the same insert/query interface
SwiftData would offer, so swapping in SwiftData or Core Data later is a
contained change, not a rewrite. Everything else (FSEvents monitoring, PDFKit,
Vision OCR, UniformTypeIdentifiers, QuickLook thumbnails) uses the real macOS
frameworks the spec asked for.

If you open this in Xcode, you can drag `Package.swift` in directly (File ▸
Open) and run it as-is, or wrap `Sources/Nest` in a proper `.xcodeproj` app
target with an Info.plist/entitlements for sandboxing, microphone/speech
usage-description keys (see Talk to Nest below), and distribution.

### AI setup, in detail

No terminal commands required. During onboarding (or later in Settings ▸ AI
Processing), the app walks through setup itself:

1. Checks whether [Ollama](https://ollama.com) is installed and running.
2. If it's already running, skips straight to step 4.
3. If it's installed but not running, starts it. If it isn't installed at
   all, offers a one-click "Install via Homebrew" (only if Homebrew is
   present — this is the one step that changes anything outside the app, so
   it's the one step that always waits for an explicit click) or a link to
   download it manually.
4. Automatically pulls the default model (`llama3.2:1b`, ~1.3GB, chosen for a
   fast first run) via Ollama's own API, with a live progress bar.
5. Enables AI classification once the model is ready.

`OllamaSetupCoordinator` drives this state machine and is shared between the
onboarding screen and Settings, so a setup started in one place shows live in
the other. Everything works without Ollama at all — you just get
local/rule-based classification instead, and can turn AI on later whenever
you want.

### Talk to Nest, in detail

- **Command+Option, held together, anywhere** (`GlobalHotkeyMonitor`) opens a
  floating mic overlay and listens until you pause or 12 seconds pass, then
  routes the transcript into the Search tab exactly like typing it would.
- **"Hey Nest"** (optional sub-toggle) runs the same continuous on-device
  recognition (`VoiceCommandService`, `SFSpeechRecognizer` with
  `requiresOnDeviceRecognition` where the Mac supports it) listening for the
  wake phrase; whatever follows it in the same utterance becomes the query.
  Saying "Hey Nest" with nothing after it opens the same overlay as the
  hotkey, so you can finish the sentence separately.
- An optional "speak results aloud" toggle gives a short spoken confirmation
  (`SpeechOutputService`, `AVSpeechSynthesizer`, output-only, no permission
  needed) while the Search tab runs the actual query.

**Real constraints, not glossed over:**
- The ⌘⌥ hotkey firing while Nest isn't the frontmost app requires
  Accessibility permission (System Settings ▸ Privacy & Security ▸
  Accessibility) — `GlobalHotkeyMonitor.requestAccessibilityIfNeeded()`
  prompts for it once. Without that grant, the hotkey still works whenever
  Nest itself is focused.
- Speech framework recognition tasks have a bounded lifetime (roughly a
  minute); continuous "Hey Nest" listening restarts itself before that limit
  to stay effectively continuous, which means a very brief (sub-second) gap
  every ~50 seconds where a wake phrase could theoretically be missed.
- Microphone and Speech Recognition permission prompts are governed by TCC
  and keyed to a signed app bundle with `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription` in its Info.plist — this repo's bare
  SPM executable has neither, so on some setups macOS may attribute the
  permission prompt to the invoking terminal rather than to "Nest," or reuse
  a prior grant. This is the same category of limitation documented below for
  SwiftData/XCTest/notifications: fully correct end-to-end behavior needs the
  Xcode `.xcodeproj` app-target migration, not just `swift build`.
- Wake-word matching is a plain substring check on live transcription, not a
  dedicated low-power wake-word engine (Apple doesn't expose "Hey Siri"'s
  engine publicly) — it works, but keeps the microphone actively transcribing
  the whole time it's on, which is real (if modest) CPU/battery cost. That
  trade-off is exactly why it's a separate, off-by-default sub-toggle rather
  than bundled into the base voice-commands switch.

### Architecture, module by module

- **Onboarding**: folder picker (defaults to `~/Downloads`), explains local vs.
  AI processing before anything happens.
- **Filesystem monitoring**: `FSEventStream`-based watcher (`FolderMonitor`)
  with debounced "has this file stopped growing" settling logic, so
  `.crdownload`/`.part`/`.tmp` partial downloads are ignored until they
  resolve to their final name.
- **Ingest pipeline** (`FileIngestPipeline`): metadata → SHA-256 content hash
  (`HashService`, streamed, not loaded fully into memory) → duplicate-group
  detection → PDFKit/plain-text extraction → Vision OCR for images →
  rule-based local classification (`ClassificationEngine`) → optional local-LLM
  classification → persistence → activity log entry.
- **Categories**: fixed taxonomy (`CategoryTaxonomy`) matching the product
  spec (Work/Finance/Education/Personal/Images/Other), with a confidence
  threshold that routes low-confidence files to "Needs Review" instead of
  forcing a guess.
- **AI service abstraction** (`AIService` protocol): `OllamaAIService` talks to
  a local Ollama server (`/api/chat`) and is the only thing that ever sees
  extracted text; `NullAIService` is the default when AI is off or Ollama
  isn't running, so every call site works identically either way.
  Classification prompts request strict JSON, validate the returned
  category/subcategory against the fixed taxonomy, and retry once with a
  correction prompt before giving up.
- **Search** (`SearchService`): staged local search — filename → metadata →
  extracted/OCR text → tags — plus an optional AI-interpreted structured
  filter pass (dates, amounts, currency, vendor) applied as hard constraints
  on top. Only the query text is ever sent to the local model, never the file
  library.
- **Safe file operations** (`FileOrganizerService`): every move/rename is
  logged as an `OperationRecord` with the original path, never overwrites an
  existing file (Finder-style " 2", " 3" suffixing), and is undoable.
- **Rules / Organize Downloads**: groups unapproved files by
  category/subcategory, shows counts, and moves only on explicit
  Review/Apply — never automatically.
- **Expiry Center — a generic "Document Events" engine**, not an
  expiry-only feature (deliberately, per the product spec's own architectural
  note — expiry, deadlines, renewals and event dates all flow through the same
  pipeline):
  - `DateDetectionEngine`: deterministic regex-based date detection (ISO,
    numeric with `/`, `-`, `.` separators and 2- or 4-digit years, and month-name
    formats in both orders), plus a "valid for N months from issue" duration
    parser. **Not** built on `NSDataDetector` — see the bug story below.
  - `ExpiryContextClassifier`: local, offline keyword-window heuristics that
    decide what a date *means* — the Expiry vs. Deadline vs. Renewal vs. Event
    distinction the whole feature depends on (a flight date is an `EVENT_DATE`,
    never an `EXPIRY`). Also detects "X to Y" ranges (e.g. "Policy Period: ...
    to ...") and correctly splits them into a start (`VALID_FROM`) and an
    expiry, matching the spec's own worked example.
  - AI refinement (optional): `AIService.extractDocumentEvents` asks the local
    model for the same structured `{type, date, confidence, explicit,
    source_text}` schema from the spec, validated against the fixed event-type
    list and a real date before being trusted; falls back to the local result
    if AI is off, fails, or returns nothing.
  - Confidence-gated: anything below 75% confidence lands in **Needs Review**
    with its source text shown, never silently promoted to a critical
    reminder — matches the spec's "never claim expiry from ambiguous text"
    safety rule.
  - Runs automatically on every newly-ingested file, plus an explicit **Scan
    for Important Dates** button that retroactively scans the *existing*
    library (not just new downloads), with a funnel summary (files → docs with
    text → docs with dates → new records).
  - Local notifications (`ExpiryNotificationService`, `UserNotifications`) at
    90/30/7-days-before and on-expiry, gated by a "high-confidence only"
    setting — everything scheduled on-device, nothing sent anywhere.
  - Calendar integration (`CalendarService`, EventKit) with a configurable
    alarm offset — always an explicit per-record action, never automatic.

### A real bug found and fixed during development

The obvious first choice for date parsing is `NSDataDetector`. Testing it
against the spec's own example phrases showed it silently resolves "valid
until 31 March 2027" and "passport valid until: 12 March 2027" to **today's
date** (it appears to treat "until"/"through" + a date as a
relative-duration expression), and collapses "Policy Period: 01/04/2026 to
31/03/2027" into a single match that drops the end date — the expiry date,
the one that matters most. Both were verified with a standalone script
before writing a line of the real engine. `DateDetectionEngine` uses
explicit, deterministic regexes instead, verified against all of the spec's
listed formats plus both of these exact regression cases (see `Tests/`).

### What's intentionally thin for this MVP

- DOC/DOCX/XLSX/PPTX are indexed by filesystem metadata and filename/extension
  heuristics only — no bundled Office-format text extraction library.
- Rules are currently generated from "Organize Downloads" review/apply
  sessions rather than having a full rule-builder UI.
- No code signing / sandbox entitlements yet (needs an Xcode app target).
- AI quality depends on which local model you pull; smaller models (e.g. 3B)
  classify faster but less reliably than larger ones — pick based on your
  Mac's memory.
- Expiry Center scope: this ships the V1 core (detection → classification →
  dashboard) plus OCR support and the V1.2 items (notifications, calendar).
  Deliberately deferred, per the spec's own recommended phased sequence:
  - **AI-assisted natural-language expiry queries** — the search bar uses a
    deterministic local parser only; routing free-text queries through the
    local LLM for looser phrasing is a documented next step, not done here.
  - **Deep recurring-subscription semantics** — recurrence is detected via a
    simple keyword scan (monthly/yearly/quarterly/weekly) and stored as a
    label; it doesn't track billing cycles or compute `nextOccurrence`.
  - **Correction-learning loop** (spec §21) — corrections currently just edit
    the record; they aren't fed back into future classification.
  - **Unified "Attention Center"** merging expiry with duplicates/other
    signals (spec §25) — Overview shows a lightweight expiry-only "Today's
    Attention" list instead of a full cross-feature center.
- `Tests/NestTests` exists and is real (XCTest against
  `DateDetectionEngine`/`ExpiryContextClassifier`, including both regressions
  above), but **`swift test` needs Xcode.app** in this environment for the
  same reason SwiftData does — `XCTest.framework` isn't part of the
  standalone Command Line Tools. It wasn't left unverified for that reason:
  the same production source files were compiled and run as a standalone
  driver (`swiftc` + explicit binary, not `swift test`) with all 31 assertions
  passing before this was committed. Open the package in real Xcode and
  `swift test` will run normally.
- `ExpiryNotificationService` (UserNotifications), `CalendarService`
  (EventKit), and the voice stack (Speech/AVFoundation) are real, but
  authorization prompts and delivery are only reliable from a properly signed
  `.app` bundle with the relevant usage-description keys in Info.plist —
  another thing that needs the Xcode app-target migration mentioned above to
  fully verify end-to-end.

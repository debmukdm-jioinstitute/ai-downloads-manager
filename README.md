# AI Downloads Manager

A native macOS utility that watches your Downloads folder, understands what each
file is (invoice, receipt, assignment, screenshot, research paper, ...), and
lets you search and organize it in plain English — without ever deleting or
moving a file without your say-so.

AI classification runs on a free, open-source local LLM via
[Ollama](https://ollama.com) — no API key, no per-call cost, no rate limit,
and nothing ever leaves your Mac.

## Why it's a Swift Package, not an `.xcodeproj`

This was built in an environment with Xcode Command Line Tools only (no
Xcode.app), so SwiftData's `@Model` macro — which ships only inside Xcode's
toolchain — isn't available here. The app therefore uses a small local-first
JSON-file store (`LibraryStore`) behind the same insert/query interface
SwiftData would offer, so swapping in SwiftData or Core Data later is a
contained change, not a rewrite. Everything else (FSEvents monitoring, PDFKit,
Vision OCR, UniformTypeIdentifiers, QuickLook thumbnails) uses the real macOS
frameworks the spec asked for.

If you open this in Xcode, you can drag `Package.swift` in directly (File ▸
Open) and run it as-is, or wrap `Sources/AIDownloadsManager` in a proper
`.xcodeproj` app target with an Info.plist/entitlements for sandboxing and
distribution.

## Running it

```bash
swift build
swift run
```

This opens a real windowed SwiftUI app (App Sandbox / notarization aren't
configured in this SPM form — do that when you migrate to an Xcode app target).

### Optional: enable AI classification — fully automatic

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

## What's implemented

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
    parser. **Not** built on `NSDataDetector` — see the note below, this was a
    deliberate correction after finding a real bug.
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
  - Dashboard (`ExpiryCenterView`): Expired / Expiring Soon / Upcoming buckets
    with configurable day-thresholds (`ExpiryUrgencyWindows`), structured
    Status/Category filters, and a local (non-AI) natural-language query parser
    (`ExpiryQueryParser`) for phrasings like "what expires this month" or
    "show insurance documents".
  - Detail view: full "Why?" breakdown (source text, OCR vs. text, confidence),
    Edit Date, Confirm/Ignore, and an explicit "Add to Calendar" action
    (`CalendarService`, EventKit) with a configurable alarm offset.
  - Local notifications (`ExpiryNotificationService`, `UserNotifications`) at
    90/30/7-days-before and on-expiry, gated by a "high-confidence only"
    setting — everything scheduled on-device, nothing sent anywhere.

  **A real bug found and fixed during development:** the obvious first choice
  for date parsing is `NSDataDetector`. Testing it against the spec's own
  example phrases showed it silently resolves "valid until 31 March 2027" and
  "passport valid until: 12 March 2027" to **today's date** (it appears to
  treat "until"/"through" + a date as a relative-duration expression), and
  collapses "Policy Period: 01/04/2026 to 31/03/2027" into a single match that
  drops the end date — the expiry date, the one that matters most. Both were
  verified with a standalone script before writing a line of the real engine.
  `DateDetectionEngine` uses explicit, deterministic regexes instead, verified
  against all of the spec's listed formats plus both of these exact regression
  cases (see `Tests/`).

## What's intentionally thin for an MVP

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
- `Tests/AIDownloadsManagerTests` exists and is real (XCTest against
  `DateDetectionEngine`/`ExpiryContextClassifier`, including both regressions
  above), but **`swift test` needs Xcode.app** in this environment for the
  same reason SwiftData does — `XCTest.framework` isn't part of the
  standalone Command Line Tools. It wasn't left unverified for that reason:
  the same production source files were compiled and run as a standalone
  driver (`swiftc` + explicit binary, not `swift test`) with all 27 assertions
  passing before this was committed. Open the package in real Xcode and
  `swift test` will run normally.
- `ExpiryNotificationService` (UserNotifications) and `CalendarService`
  (EventKit) are real, but authorization prompts and delivery are only
  reliable from a properly signed `.app` bundle with the relevant
  usage-description keys in Info.plist — another thing that needs the Xcode
  app-target migration mentioned above to fully verify end-to-end.

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

### Optional: enable AI classification

1. Install [Ollama](https://ollama.com) and pull a model:
   ```bash
   ollama pull llama3.2
   ```
2. In the app: Settings ▸ AI Processing ▸ Test Connection ▸ toggle "Enable AI
   classification (Ollama)". You'll see a consent screen explaining that
   extracted text is sent to the local model (never the files themselves,
   never over the internet).

Everything works without Ollama running — you just get local/rule-based
classification instead.

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

## What's intentionally thin for an MVP

- DOC/DOCX/XLSX/PPTX are indexed by filesystem metadata and filename/extension
  heuristics only — no bundled Office-format text extraction library.
- Rules are currently generated from "Organize Downloads" review/apply
  sessions rather than having a full rule-builder UI.
- No code signing / sandbox entitlements yet (needs an Xcode app target).
- AI quality depends on which local model you pull; smaller models (e.g. 3B)
  classify faster but less reliably than larger ones — pick based on your
  Mac's memory.

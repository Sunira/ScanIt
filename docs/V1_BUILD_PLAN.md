# ScanIt — Version 1 Build Plan

Status: **All decisions made. Waiting for approval to start building.**
Based on: `docs/PRODUCT_SPEC.md` and the ScanIt mockup (design canvas).

## 1. What V1 delivers

An iPhone app (iOS 26+) that lets one person:

1. Scan documents with the camera (edge detection, several pages per document), or import from Photos, Files/PDFs and the Share Sheet.
2. Have the phone read the text, including English handwriting.
3. Have Claude sort each scan into a category, suggest a title and tags, write a summary, and pull out key details such as amount, dates, vendor and account number. Regular photos get a description.
4. Search every word, and filter by category, date and amount.
5. Fix anything the AI got wrong, with ScanIt learning from the fixes.
6. Keep working offline: scans are saved and searchable straight away, and the AI runs once the phone is back online.
7. Lock the app with Face ID or the passcode.
8. Export as PDF, share, copy text, print, and confirm suggested reminders for due dates.
9. Sync their library across their own Apple devices through iCloud.

**Not in V1:** the Family space, detecting which family member a document is about, the Ask screen (questions in plain language), and iPad and Mac layouts. Those come in V2 and V3.

> Suggested reminders were planned for V2 but are now part of V1, as shown in the mockup.

## 2. How a scan flows through the app

```
Camera / Photos / Files / Share Sheet
        │
        ▼
1. Save the images and PDF on the device ──► document appears in the list immediately
        │
        ▼
2. Read the text on the device (Apple Vision)
        │   → keyword search works now, even offline
        ▼
3. AI queue (waits if offline)
        ├─ Document → only the TEXT is sent to Claude
        └─ Photo    → a resized IMAGE is sent to Claude to be described
        │
        ▼
4. Claude returns structured JSON: category, title, tags, summary, details
        │
        ▼
5. Apply learned rules (e.g. "City Water → Bills") → save → update search index
        │
        ▼
6. Result card fills in; suggest a reminder if a due date was found
```

## 3. Technology choices

| Area | Choice | Why |
|---|---|---|
| Language / UI | Swift 6, SwiftUI | Native Apple look, Liquid Glass, and the same code adapts to iPad and Mac later |
| Scanning | VisionKit `VNDocumentCameraViewController` | Apple's own scanner, with edge detection, perspective correction and multiple pages |
| Importing | `PhotosPicker`, `fileImporter`, Share Extension | Covers Photos, Files/PDFs, and sharing from other apps |
| Reading text | Apple Vision (iOS 26 document recognition) | Runs on the device, free and private, and reads handwriting |
| Telling photos from documents | Vision image analysis plus how much text was found | Decides whether to send text or an image to Claude |
| Data storage | SwiftData + CloudKit (private database) | Built-in iCloud sync, no server. Page images are stored outside the database file |
| Search | SQLite FTS5 index on the device (GRDB library) | Fast full-text search with highlighted matches; SwiftData can't do full-text search |
| AI | Claude Messages API over HTTPS (`URLSession`) | There's no official Swift SDK, so ScanIt calls the REST API directly |
| AI output | Structured outputs (`output_config.format` with a JSON schema) | The reply is guaranteed valid JSON in the expected shape |
| API key | Keychain (synced through iCloud Keychain) | Encrypted, and available on all of the user's devices |
| App lock | LocalAuthentication | Face ID or passcode, and a blurred screen in the app switcher |
| Reminders | EventKit | Adds reminders to the Apple Reminders app after the user confirms |
| PDF / print | PDFKit, `UIPrintInteractionController`, `ShareLink` | Built in |
| Project setup | XcodeGen (`project.yml`) | The Xcode project is generated from a text file, so it can be written and reviewed here |

The only library from outside Apple is **GRDB** (for the search index).

## 4. Data model

```
Document
  id, createdAt, kind (document | photo)
  title, summary, categoryID, tags[]
  details { amount, currency, date, dueDate, vendor, accountLast4, other[] }
  pages[]  → PageImage (image stored outside the database, synced by CloudKit)
  ocrText, photoDescription
  aiStatus (pending | processing | done | failed), aiError
  userEdited fields (so the AI never overwrites a user's fix)

Category   id, name, color, icon, sortOrder, isBuiltIn
LearnedRule  match (vendor / keyword) → set category / add tags   (created from user fixes)
Reminder suggestion  documentID, dueDate, accepted / dismissed
```

**Starter categories:** Receipts, Bills, Medical, Insurance, Legal, ID, School, Personal. You can edit them all.

## 5. The AI request

- **Model:** Claude Opus 5.5 (`claude-opus-5-5`) at `low` effort.
- **One request per scan:**
  - the system prompt
  - your category list and learned rules
  - the recognized text, or the photo
  - a JSON schema the reply must follow
- **Reply schema:** `category`, `title`, `summary`, `tags[]`, `details{…}`, `isPhoto`, `photoDescription`, `confidence`.
- **Learning from fixes:** your rules go in the prompt, *and* ScanIt applies them itself after the reply comes back, so a rule always wins.
- **Robustness:**
  - retries when the network drops or Claude is busy (429/5xx)
  - a clear message if the API key is wrong
  - the "Waiting for internet" counter in Settings
- **Privacy:** documents send text only, and photos send a resized image (about 1,500 px). Nothing is stored on any server of ours, because there isn't one.

**Estimated cost per scan** (a one-page document, about 1,500 tokens in and 400 out, at Anthropic's current published prices):

| Model | Per scan | 100 scans/month |
|---|---|---|
| Claude Opus 5.5 (low effort) | ~1–2¢ | ~$1–2 |
| Claude Haiku 5.5 | ~0.05¢ | ~$0.05 |

Earlier I said scans would cost "well under a cent". That holds for Haiku, but Opus costs about 1–2¢ per scan.

## 6. Screens (matching the mockup)

| Screen | V1 contents |
|---|---|
| Welcome setup | Welcome → Face ID → API key (can be skipped) |
| Documents | List with thumbnails, category filter buttons, sort, floating Scan button, import button |
| After a scan | Live result card filling in, "Add reminder?", Edit / Done / Scan more |
| Document | Pages you can swipe through, summary, details, tags, full text you can expand, editing, and share / PDF / print / copy |
| Search | Keyword search with highlighted matches, and filters for Category, Date and Amount (Person comes in V2). The Ask tab shows "Coming soon" |
| Settings | Face ID lock, API key, describe photos on/off, offline queue, categories, learned rules, iCloud sync, appearance |
| Tab bar | Documents · Search · Family (greyed out, "Coming in V2") · Settings |

## 7. Milestones

Each milestone ends with something you can install and try on your iPhone.

| # | Milestone | You can… |
|---|---|---|
| M0 | Project skeleton, tab bar, colors, app icon, CI | Install a shell app with the icon and tabs |
| M1 | Scan and import, save pages, Documents list, Document screen (view only) | Scan and import, and see your documents |
| M2 | On-device text reading + keyword search | Search any word in your scans, offline |
| M3 | Claude classification, extracted details, photo descriptions, result card | Watch documents get sorted automatically |
| M4 | Editing, learned rules, category management, filters | Fix mistakes, and have ScanIt remember them |
| M5 | Offline queue, app lock, welcome setup, Settings | Use it day to day, privately |
| M6 | PDF export, share, print, copy, reminders, Share Extension | Get documents out, and share them in from other apps |
| M7 | iCloud sync, polish, dark mode check, accessibility pass, TestFlight build | Install the finished V1 through TestFlight |

## 8. Testing and how you'll run it

- **Unit tests:** the AI reply parsing, learned rules, the search index, and the offline queue. Claude is replaced by fake replies, so tests cost nothing.
- **A small set of sample documents:** a receipt, a bill, a medical form, an insurance card and a handwritten note, used to check the AI prompt.
- **Building:** this cloud session runs Linux, so it cannot compile iOS code. GitHub Actions macOS CI compiles and tests every push instead.
- **Your role:** at the end of each milestone, install it on your iPhone and tell me what to change.

## 9. Build decisions (agreed)

1. **AI model:** Claude Opus 5.5 (`claude-opus-5-5`) at `low` effort, ~1–2¢ per scan.
2. **Building and checking:** GitHub Actions macOS CI builds and tests every push.
3. **Reminders:** included in V1.
4. **Share Extension:** included in V1 (milestone M6).
5. **Bundle ID:** `com.sunira.scanit`, with the extension at `com.sunira.scanit.share` and the iCloud container `iCloud.com.sunira.scanit`. The Apple Developer Team ID is set in Xcode before the first TestFlight build.

## 10. Risks

| Risk | What we'll do |
|---|---|
| Handwriting is read poorly | Show the original page alongside the text; Claude can often still classify from partial text |
| The API key on each device can be misused | Family-only use; spending limits can be set in the Anthropic Console |
| iCloud sync conflicts | SwiftData + CloudKit merges by record; the user's edits always win over the AI's results |
| Large libraries use a lot of iCloud storage | Pages are stored as compressed images (HEIC) |

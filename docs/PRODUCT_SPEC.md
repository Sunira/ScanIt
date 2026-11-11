# ScanIt — Product Spec

Status: **Product decisions agreed.** Look & feel: not decided yet. No code until every decision is made.

## Purpose
An app for iPhone, iPad and Mac that scans documents and photos. AI reads each scan, classifies it and pulls out the key details, and everything goes into a searchable library that a family can share.

## Decisions

| # | Topic | Decision |
|---|-------|----------|
| 1 | Audience | Me and my family |
| 2 | Family model | Each person has a private library and can share with the family |
| 3 | Document types | Receipts & bills, medical & insurance, legal & ID, school & personal |
| 4 | AI location | Hybrid: the phone reads the text, and only the text goes to the cloud AI (Claude) for classification |
| 5 | Categories | Starter set the user can edit (Receipts, Bills, Medical, Insurance, Legal, ID, School, Personal) |
| 6 | AI extras | Pull out key details (dates, amounts, vendor, due dates, names, account numbers), suggest a title & tags, write a short summary, detect the family member |
| 7 | Search | Keyword search, filters (category, person, date, amount), and asking questions in plain language ("How much did we spend at the dentist this year?") |
| 8 | Import sources | Camera with edge detection and multiple pages, Photos library, Files/PDFs, Share Sheet from other apps |
| 9 | Regular photos | The AI writes a description so photos can be searched |
| 10 | Photo AI | Regular photos are sent to the cloud AI to be described. Documents send text only |
| 11 | Handwriting | Printed and handwritten text, English |
| 12 | Corrections | Any field can be edited, and the app learns from corrections (e.g. vendor → category rules) |
| 13 | Sync | iCloud (CloudKit). No separate accounts and no server |
| 14 | Sharing | One shared "Family" space, using CloudKit sharing |
| 15 | Security | Face ID / passcode lock on the whole app |
| 16 | Actions | Export/share as PDF, copy text, print, add to Reminders & Calendar |
| 17 | Reminders | Suggested when a due date is found; the user confirms |
| 18 | Organization | One category plus tags per document, no folders |
| 19 | Platforms | iPhone, iPad, Mac |
| 20 | AI cost | The user's own Anthropic API key, entered in Settings and stored in the Keychain |
| 21 | Offline | Scans are saved and keyword-searchable straight away; AI processing waits in a queue until the device is online |
| 22 | Dev setup | Mac with Xcode and a paid Apple Developer account (TestFlight for family) |
| 23 | Minimum OS | iOS 26 (iPadOS 26 / macOS 26) |
| 24 | Delivery | Built in phases (below) |

## Phases
- **V1 (iPhone):** scanning and importing, reading text on the device, AI classification, extracted details, titles, tags and summaries, photo descriptions, keyword search with filters, editing and learning from corrections, offline queue, app lock, PDF export / copy / print, iCloud sync for one person's own devices.
- **V2:** shared Family space, family member detection, asking questions about your documents, suggested reminders and calendar events.
- **V3:** iPad and Mac layouts.

## Technical direction (proposed)
SwiftUI, SwiftData + CloudKit, VisionKit (document camera), Vision (text recognition), SQLite FTS for keyword search, Claude API for classification, extraction and descriptions, LocalAuthentication, EventKit.

## Open — look & feel (next step)
Visual style, colors and theme, app icon, navigation structure, main screens, scanning flow, how results are shown after a scan.

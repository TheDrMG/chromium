# PDF Editor (iOS)

A simple iPhone/iPad app to **import PDFs, edit them, and export the edited copy**.
Built with SwiftUI + Apple's PDFKit. No third-party dependencies.

## Features

- **Import** one or many PDFs from the Files app (iCloud Drive, On My iPhone, Google Drive, etc.).
  You can also use **Share → PDF Editor** from Mail, Safari, etc.
- **Edit**
  - ✋ Select/Scroll – pinch-zoom, scroll, and long-press text to select it, then **Highlight**, **Underline** or **Strike Out**
  - ✏️ Pen – draw or sign with your finger or Apple Pencil
  - 🖍 Highlighter – translucent freehand marker
  - 🔤 Text – tap anywhere on a page and type to add text
  - 🧽 Eraser – tap or drag over any mark to remove it
  - Color picker and 4 sizes for pen / highlighter / text
  - **Pages** menu: rotate, insert a blank page, delete a page
  - **Undo** for everything
- **Save** back into the app (it also auto-saves when you go back to the list).
- **Export** with the standard share sheet: Save to Files, AirDrop, Mail, Messages, Print…
- Library: rename, duplicate, delete (swipe or long-press a file).
- Your PDFs are also visible in the **Files app → On My iPhone → PDF Editor**.

## Putting it on your iPhone

You need a Mac with **Xcode 16 or newer** (free on the Mac App Store). A free Apple ID is enough.

1. Open `PDFEditor.xcodeproj` in Xcode.
2. Click the **PDFEditor** project in the left sidebar → **PDFEditor** target → **Signing & Capabilities**.
   - Check **Automatically manage signing**.
   - **Team**: pick your Apple ID (Xcode → Settings → Accounts to add one).
   - **Bundle Identifier**: change `com.yourname.PDFEditor` to something unique, e.g. `com.<yourname>.PDFEditor`.
3. Plug in your iPhone (or use Wi-Fi pairing) and select it at the top of the Xcode window.
4. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode** (it'll restart) if asked.
5. Press **▶ Run** (⌘R).
6. First launch only: on the iPhone go to **Settings → General → VPN & Device Management**,
   tap your Apple ID and choose **Trust**.

> With a free Apple ID the app stops opening after 7 days — just press Run in Xcode again to refresh it.
> A paid Apple Developer account ($99/yr) makes it last a year and lets you use TestFlight.

## Code overview

| File | What it does |
| --- | --- |
| `PDFEditorApp.swift` | App entry point; handles PDFs opened from other apps |
| `DocumentStore.swift` | Manages the PDFs saved in the app's Documents folder |
| `LibraryView.swift` | Home screen list, import, rename/duplicate/delete/share |
| `EditorView.swift` | Editing screen, toolbars, export share sheet |
| `PDFEditorController.swift` | All editing logic: drawing, text, eraser, markup, pages, undo, save |
| `PDFKitView.swift` | Wraps `PDFView` plus a touch overlay used by the drawing tools |

Requires iOS 17 or later.

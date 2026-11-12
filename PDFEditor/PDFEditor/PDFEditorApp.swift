import SwiftUI

@main
struct PDFEditorApp: App {
    @State private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(store)
                // Handles "Open in PDF Editor" / "Copy to PDF Editor" from other apps.
                .onOpenURL { url in
                    store.importFiles([url])
                }
        }
    }
}

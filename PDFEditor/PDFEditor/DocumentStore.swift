import Foundation
import Observation

/// A PDF that lives in the app's Documents folder.
struct PDFFile: Identifiable, Hashable {
    let url: URL
    let modified: Date

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

/// Keeps track of the PDFs stored inside the app.
/// Files are kept in the app's Documents folder, which is also visible
/// in the Files app under "On My iPhone > PDF Editor".
@Observable
final class DocumentStore {
    private(set) var files: [PDFFile] = []
    let folder: URL

    init() {
        folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        reload()
    }

    func reload() {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        files = urls
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .map { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                return PDFFile(url: url, modified: values?.contentModificationDate ?? .distantPast)
            }
            .sorted { $0.modified > $1.modified }
    }

    /// Copies PDFs picked from Files (or sent from another app) into the app.
    @discardableResult
    func importFiles(_ urls: [URL]) -> [Error] {
        var errors: [Error] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            // Already in our folder (e.g. created via the Files app) – nothing to do.
            if url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL {
                continue
            }
            do {
                let destination = uniqueURL(for: url.deletingPathExtension().lastPathComponent)
                try FileManager.default.copyItem(at: url, to: destination)
            } catch {
                errors.append(error)
            }
        }
        reload()
        return errors
    }

    func delete(_ file: PDFFile) {
        try? FileManager.default.removeItem(at: file.url)
        reload()
    }

    func rename(_ file: PDFFile, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != file.name else { return }
        let destination = uniqueURL(for: trimmed)
        try? FileManager.default.moveItem(at: file.url, to: destination)
        reload()
    }

    func duplicate(_ file: PDFFile) {
        let destination = uniqueURL(for: file.name + " copy")
        try? FileManager.default.copyItem(at: file.url, to: destination)
        reload()
    }

    /// Returns "Name.pdf", or "Name 2.pdf", "Name 3.pdf"… if that name is taken.
    private func uniqueURL(for baseName: String) -> URL {
        let safe = baseName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let name = safe.isEmpty ? "Document" : safe
        var candidate = folder.appendingPathComponent(name).appendingPathExtension("pdf")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(name) \(counter)").appendingPathExtension("pdf")
            counter += 1
        }
        return candidate
    }
}

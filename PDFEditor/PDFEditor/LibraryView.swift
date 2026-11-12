import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// The home screen: a list of all PDFs in the app.
struct LibraryView: View {
    @Environment(DocumentStore.self) private var store

    @State private var showImporter = false
    @State private var fileToRename: PDFFile?
    @State private var newName = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.files.isEmpty {
                    ContentUnavailableView {
                        Label("No PDFs Yet", systemImage: "doc.richtext")
                    } description: {
                        Text("Import a PDF from Files to start editing it.")
                    } actions: {
                        Button("Import PDF") { showImporter = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(store.files) { file in
                            NavigationLink(value: file) {
                                FileRow(file: file)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.delete(file)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    newName = file.name
                                    fileToRename = file
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button {
                                    store.duplicate(file)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                ShareLink(item: file.url) {
                                    Label("Export / Share", systemImage: "square.and.arrow.up")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    store.delete(file)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .refreshable { store.reload() }
                }
            }
            .navigationTitle("My PDFs")
            .navigationDestination(for: PDFFile.self) { file in
                EditorView(file: file)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import PDF", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    let errors = store.importFiles(urls)
                    if let first = errors.first {
                        errorMessage = first.localizedDescription
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .alert("Rename PDF", isPresented: Binding(
                get: { fileToRename != nil },
                set: { if !$0 { fileToRename = nil } }
            )) {
                TextField("Name", text: $newName)
                Button("Save") {
                    if let file = fileToRename { store.rename(file, to: newName) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear { store.reload() }
        }
    }
}

private struct FileRow: View {
    let file: PDFFile

    @State private var thumbnail: UIImage?
    @State private var pageCount = 0

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "doc.richtext")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 58)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(2)
                Text("\(pageCount) page\(pageCount == 1 ? "" : "s") · \(file.modified.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .task(id: file) {
            let url = file.url
            let result = await Task.detached(priority: .utility) { () -> (UIImage?, Int) in
                guard let document = PDFDocument(url: url) else { return (nil, 0) }
                let image = document.page(at: 0)?.thumbnail(of: CGSize(width: 88, height: 116), for: .cropBox)
                return (image, document.pageCount)
            }.value
            thumbnail = result.0
            pageCount = result.1
        }
    }
}

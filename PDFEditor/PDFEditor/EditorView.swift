import SwiftUI
import PDFKit

/// Opens one PDF for editing.
struct EditorView: View {
    @Environment(DocumentStore.self) private var store
    @State private var controller: PDFEditorController
    @State private var shareItem: ShareItem?
    @State private var showSaveError = false
    @State private var confirmDeletePage = false

    init(file: PDFFile) {
        _controller = State(initialValue: PDFEditorController(fileURL: file.url))
    }

    var body: some View {
        Group {
            if controller.document != nil {
                PDFKitView(controller: controller)
            } else {
                ContentUnavailableView(
                    "Can't Open PDF",
                    systemImage: "doc.questionmark",
                    description: Text("This file may be damaged or password protected.")
                )
            }
        }
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { topToolbar }
        .safeAreaInset(edge: .bottom) {
            if controller.document != nil { bottomToolbar }
        }
        .alert("Add Text", isPresented: $controller.isPromptingForText) {
            TextField("Type something", text: $controller.textInput)
            Button("Add") { controller.commitText() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The text will be placed where you tapped.")
        }
        .alert("Couldn't save the PDF", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        }
        .confirmationDialog("Delete this page?", isPresented: $confirmDeletePage, titleVisibility: .visible) {
            Button("Delete Page", role: .destructive) { controller.deleteCurrentPage() }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
        }
        .onDisappear {
            // Auto-save when you go back to the list.
            if controller.hasUnsavedChanges {
                controller.save()
                store.reload()
            }
        }
    }

    // MARK: - Top bar: undo, page tools, save, export

    @ToolbarContentBuilder
    private var topToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                controller.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!controller.canUndo)

            Menu {
                Button {
                    controller.rotateCurrentPage()
                } label: {
                    Label("Rotate Page", systemImage: "rotate.right")
                }
                Button {
                    controller.insertBlankPage()
                } label: {
                    Label("Insert Blank Page After", systemImage: "doc.badge.plus")
                }
                Button(role: .destructive) {
                    confirmDeletePage = true
                } label: {
                    Label("Delete Page", systemImage: "trash")
                }
                .disabled(!controller.canDeletePage)
            } label: {
                Label("Pages", systemImage: "doc.on.doc")
            }
            .disabled(controller.document == nil)

            Button {
                if !controller.save() { showSaveError = true }
                store.reload()
            } label: {
                Label("Save", systemImage: controller.hasUnsavedChanges ? "square.and.arrow.down.fill" : "checkmark.circle")
            }
            .disabled(!controller.hasUnsavedChanges)

            Button {
                // Save first so the exported file includes every edit.
                if controller.hasUnsavedChanges && !controller.save() {
                    showSaveError = true
                    return
                }
                store.reload()
                shareItem = ShareItem(url: controller.fileURL)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(controller.document == nil)
        }
    }

    // MARK: - Bottom bar: tools, color, size

    private var bottomToolbar: some View {
        VStack(spacing: 8) {
            if controller.tool == .select && controller.hasSelection {
                HStack(spacing: 12) {
                    Button("Highlight") { controller.markupSelection(.highlight) }
                    Button("Underline") { controller.markupSelection(.underline) }
                    Button("Strike Out") { controller.markupSelection(.strikeOut) }
                }
                .buttonStyle(.bordered)
                .font(.subheadline)
            }

            HStack(spacing: 4) {
                ForEach(EditTool.allCases) { tool in
                    Button {
                        controller.tool = tool
                    } label: {
                        Image(systemName: tool.icon)
                            .font(.title3)
                            .frame(width: 44, height: 38)
                            .background(
                                controller.tool == tool ? Color.accentColor.opacity(0.2) : .clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .accessibilityLabel(tool.title)
                }

                Divider().frame(height: 28)

                ColorPicker("Color", selection: $controller.color, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 36)

                Menu {
                    Picker("Size", selection: $controller.sizeLevel) {
                        Text("Small").tag(0)
                        Text("Medium").tag(1)
                        Text("Large").tag(2)
                        Text("Extra Large").tag(3)
                    }
                } label: {
                    Image(systemName: "lineweight")
                        .font(.title3)
                        .frame(width: 40, height: 38)
                }
                .accessibilityLabel("Size")
            }

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var statusText: String {
        let page = "Page \(controller.currentPageIndex + 1) of \(controller.pageCount)"
        switch controller.tool {
        case .select: return "\(page) · Long-press text to select & highlight"
        case .pen, .highlighter: return "\(page) · Switch to ✋ to scroll or zoom"
        case .text: return "\(page) · Tap where you want to add text"
        case .eraser: return "\(page) · Tap or drag over a mark to erase it"
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// The standard iOS share sheet (AirDrop, Mail, Save to Files, Print, …).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

import SwiftUI
import UIKit
import PDFKit
import Observation

enum EditTool: String, CaseIterable, Identifiable {
    case select, pen, highlighter, text, eraser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "Select / Scroll"
        case .pen: "Pen"
        case .highlighter: "Highlighter"
        case .text: "Text"
        case .eraser: "Eraser"
        }
    }

    var icon: String {
        switch self {
        case .select: "hand.point.up.left"
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .text: "textformat"
        case .eraser: "eraser"
        }
    }
}

/// Something that can be undone.
private enum EditAction {
    case added(PDFAnnotation, PDFPage)
    case removed(PDFAnnotation, PDFPage)
    case rotated(PDFPage, oldRotation: Int)
    case insertedPage(PDFPage)
    case deletedPage(PDFPage, index: Int)
    case group([EditAction])
}

/// Holds the open PDF and performs all edits on it.
@Observable
final class PDFEditorController {
    let fileURL: URL
    let document: PDFDocument?

    var tool: EditTool = .select {
        didSet { overlay?.isUserInteractionEnabled = (tool != .select) }
    }
    var color: Color = .red
    /// 0 = small … 3 = extra large. Used for pen width, highlighter width and font size.
    var sizeLevel = 1

    var hasUnsavedChanges = false
    var hasSelection = false
    var canUndo = false
    var currentPageIndex = 0
    var pageCount = 0

    // Text tool prompt
    var isPromptingForText = false
    var textInput = ""

    var title: String { fileURL.deletingPathExtension().lastPathComponent }

    @ObservationIgnored private weak var pdfView: PDFView?
    @ObservationIgnored private weak var overlay: UIView?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var undoStack: [EditAction] = [] {
        didSet { canUndo = !undoStack.isEmpty }
    }

    // In-progress stroke
    @ObservationIgnored private var strokePage: PDFPage?
    @ObservationIgnored private var strokePath: UIBezierPath?
    @ObservationIgnored private var strokeAnnotation: PDFAnnotation?
    @ObservationIgnored private var pendingTextLocation: (page: PDFPage, point: CGPoint)?

    init(fileURL: URL) {
        self.fileURL = fileURL
        // Load into memory so we can safely overwrite the file when saving.
        if let data = try? Data(contentsOf: fileURL) {
            document = PDFDocument(data: data)
        } else {
            document = nil
        }
        pageCount = document?.pageCount ?? 0
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func attach(pdfView: PDFView, overlay: UIView) {
        self.pdfView = pdfView
        self.overlay = overlay
        overlay.isUserInteractionEnabled = (tool != .select)

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .PDFViewPageChanged, object: pdfView, queue: .main) { [weak self] _ in
            self?.refreshPageInfo()
        })
        observers.append(center.addObserver(forName: .PDFViewSelectionChanged, object: pdfView, queue: .main) { [weak self] _ in
            guard let self, let pdfView = self.pdfView else { return }
            self.hasSelection = !(pdfView.currentSelection?.string ?? "").isEmpty
        })
        refreshPageInfo()
    }

    // MARK: - Appearance

    private var uiColor: UIColor { UIColor(color) }

    private var strokeWidth: CGFloat {
        let widths: [CGFloat] = [1.5, 3, 6, 10]
        let base = widths[min(max(sizeLevel, 0), widths.count - 1)]
        return tool == .highlighter ? base * 4 : base
    }

    private var strokeColor: UIColor {
        tool == .highlighter ? uiColor.withAlphaComponent(0.35) : uiColor
    }

    private var fontSize: CGFloat {
        let sizes: [CGFloat] = [12, 18, 26, 36]
        return sizes[min(max(sizeLevel, 0), sizes.count - 1)]
    }

    // MARK: - Touch handling (called by the drawing overlay)

    func touchBegan(at overlayPoint: CGPoint) {
        switch tool {
        case .pen, .highlighter:
            beginStroke(at: overlayPoint)
        case .eraser:
            erase(at: overlayPoint)
        case .text, .select:
            break
        }
    }

    func touchesMoved(to overlayPoints: [CGPoint]) {
        switch tool {
        case .pen, .highlighter:
            continueStroke(to: overlayPoints)
        case .eraser:
            overlayPoints.forEach { erase(at: $0) }
        case .text, .select:
            break
        }
    }

    func touchEnded(at overlayPoint: CGPoint) {
        switch tool {
        case .pen, .highlighter:
            endStroke()
        case .text:
            guard let hit = locate(overlayPoint) else { return }
            pendingTextLocation = hit
            textInput = ""
            isPromptingForText = true
        case .eraser, .select:
            break
        }
    }

    /// Converts a point in the overlay into a page and a point in that page's coordinates.
    private func locate(_ overlayPoint: CGPoint) -> (page: PDFPage, point: CGPoint)? {
        guard let pdfView, let overlay else { return nil }
        let viewPoint = pdfView.convert(overlayPoint, from: overlay)
        guard let page = pdfView.page(for: viewPoint, nearest: true) else { return nil }
        return (page, pdfView.convert(viewPoint, to: page))
    }

    // MARK: - Drawing

    private func beginStroke(at overlayPoint: CGPoint) {
        guard let hit = locate(overlayPoint) else { return }
        let bounds = hit.page.bounds(for: .cropBox)
        let start = CGPoint(x: hit.point.x - bounds.minX, y: hit.point.y - bounds.minY)

        let path = UIBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: start)
        path.addLine(to: start) // so a single tap draws a dot

        // While drawing, the annotation covers the whole page; it's shrunk to fit when the stroke ends.
        let annotation = makeInkAnnotation(bounds: bounds, path: path)
        hit.page.addAnnotation(annotation)

        strokePage = hit.page
        strokePath = path
        strokeAnnotation = annotation
    }

    private func continueStroke(to overlayPoints: [CGPoint]) {
        guard let page = strokePage, let path = strokePath, let annotation = strokeAnnotation,
              let pdfView, let overlay else { return }
        let origin = annotation.bounds.origin

        annotation.remove(path)
        for overlayPoint in overlayPoints {
            let viewPoint = pdfView.convert(overlayPoint, from: overlay)
            let p = pdfView.convert(viewPoint, to: page)
            path.addLine(to: CGPoint(x: p.x - origin.x, y: p.y - origin.y))
        }
        annotation.add(path)

        // Re-adding forces PDFKit to redraw the annotation.
        page.removeAnnotation(annotation)
        page.addAnnotation(annotation)
    }

    private func endStroke() {
        defer {
            strokePage = nil
            strokePath = nil
            strokeAnnotation = nil
        }
        guard let page = strokePage, let path = strokePath, let annotation = strokeAnnotation else { return }
        page.removeAnnotation(annotation)

        // Replace the page-sized annotation with one that tightly fits the stroke,
        // so the eraser only hits what you actually drew.
        let pad = strokeWidth + 2
        let tight = path.bounds.insetBy(dx: -pad, dy: -pad)
        let finalPath = path.copy() as! UIBezierPath
        finalPath.apply(CGAffineTransform(translationX: -tight.minX, y: -tight.minY))
        let finalBounds = tight.offsetBy(dx: annotation.bounds.minX, dy: annotation.bounds.minY)

        let finalAnnotation = makeInkAnnotation(bounds: finalBounds, path: finalPath)
        page.addAnnotation(finalAnnotation)
        record(.added(finalAnnotation, page))
    }

    private func makeInkAnnotation(bounds: CGRect, path: UIBezierPath) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.color = strokeColor
        let border = PDFBorder()
        border.lineWidth = strokeWidth
        annotation.border = border
        annotation.add(path)
        return annotation
    }

    // MARK: - Text

    func commitText() {
        defer { pendingTextLocation = nil }
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let location = pendingTextLocation else { return }

        let font = UIFont.systemFont(ofSize: fontSize)
        let size = (text as NSString).boundingRect(
            with: CGSize(width: 400, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: font],
            context: nil
        ).size
        let width = ceil(size.width) + 12
        let height = ceil(size.height) + 8
        // Place the text so its top-left corner is where you tapped (PDF y-axis points up).
        let bounds = CGRect(x: location.point.x, y: location.point.y - height, width: width, height: height)

        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = font
        annotation.fontColor = uiColor
        annotation.color = .clear
        annotation.alignment = .left
        let border = PDFBorder()
        border.lineWidth = 0
        annotation.border = border

        location.page.addAnnotation(annotation)
        record(.added(annotation, location.page))
    }

    // MARK: - Eraser

    private func erase(at overlayPoint: CGPoint) {
        guard let hit = locate(overlayPoint) else { return }
        let nonErasable: Set<String> = ["Link", "Widget", "Popup"]
        for annotation in hit.page.annotations.reversed() {
            let type = (annotation.type ?? "").replacingOccurrences(of: "/", with: "")
            guard !nonErasable.contains(type) else { continue }
            if annotation.bounds.insetBy(dx: -6, dy: -6).contains(hit.point) {
                hit.page.removeAnnotation(annotation)
                record(.removed(annotation, hit.page))
                return
            }
        }
    }

    // MARK: - Text markup (highlight / underline / strikethrough selected text)

    func markupSelection(_ type: PDFAnnotationSubtype) {
        guard let pdfView, let selection = pdfView.currentSelection else { return }
        var actions: [EditAction] = []

        for line in selection.selectionsByLine() {
            for page in line.pages {
                let bounds = line.bounds(for: page)
                guard bounds.width > 0, bounds.height > 0 else { continue }

                let annotation = PDFAnnotation(bounds: bounds, forType: type, withProperties: nil)
                annotation.color = (type == .highlight) ? uiColor.withAlphaComponent(0.45) : uiColor
                // Quad points (relative to the bounds) make the markup show up in other PDF apps too.
                annotation.quadrilateralPoints = [
                    NSValue(cgPoint: CGPoint(x: 0, y: bounds.height)),
                    NSValue(cgPoint: CGPoint(x: bounds.width, y: bounds.height)),
                    NSValue(cgPoint: CGPoint(x: 0, y: 0)),
                    NSValue(cgPoint: CGPoint(x: bounds.width, y: 0)),
                ]
                page.addAnnotation(annotation)
                actions.append(.added(annotation, page))
            }
        }
        pdfView.clearSelection()
        hasSelection = false
        if !actions.isEmpty { record(.group(actions)) }
    }

    // MARK: - Pages

    func rotateCurrentPage() {
        guard let page = pdfView?.currentPage else { return }
        let old = page.rotation
        page.rotation = (old + 90) % 360
        record(.rotated(page, oldRotation: old))
    }

    func insertBlankPage() {
        guard let document, let current = pdfView?.currentPage else { return }
        let index = document.index(for: current) + 1
        let page = PDFPage()
        page.setBounds(current.bounds(for: .mediaBox), for: .mediaBox)
        document.insert(page, at: index)
        record(.insertedPage(page))
        pdfView?.layoutDocumentView()
        pdfView?.go(to: page)
    }

    var canDeletePage: Bool { pageCount > 1 }

    func deleteCurrentPage() {
        guard let document, document.pageCount > 1, let page = pdfView?.currentPage else { return }
        let index = document.index(for: page)
        document.removePage(at: index)
        record(.deletedPage(page, index: index))
        pdfView?.layoutDocumentView()
    }

    // MARK: - Undo

    private func record(_ action: EditAction) {
        undoStack.append(action)
        hasUnsavedChanges = true
        refreshPageInfo()
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }
        revert(action)
        hasUnsavedChanges = true
        pdfView?.layoutDocumentView()
        refreshPageInfo()
    }

    private func revert(_ action: EditAction) {
        switch action {
        case .added(let annotation, let page):
            page.removeAnnotation(annotation)
        case .removed(let annotation, let page):
            page.addAnnotation(annotation)
        case .rotated(let page, let oldRotation):
            page.rotation = oldRotation
        case .insertedPage(let page):
            if let document {
                let index = document.index(for: page)
                if index != NSNotFound { document.removePage(at: index) }
            }
        case .deletedPage(let page, let index):
            if let document {
                document.insert(page, at: min(index, document.pageCount))
            }
        case .group(let actions):
            actions.reversed().forEach(revert)
        }
    }

    private func refreshPageInfo() {
        pageCount = document?.pageCount ?? 0
        if let document, let page = pdfView?.currentPage {
            let index = document.index(for: page)
            if index != NSNotFound { currentPageIndex = index }
        }
    }

    // MARK: - Saving

    /// Writes the edited PDF back to its file. Returns false if it failed.
    @discardableResult
    func save() -> Bool {
        guard let document, let data = document.dataRepresentation() else { return false }
        do {
            try data.write(to: fileURL, options: .atomic)
            hasUnsavedChanges = false
            return true
        } catch {
            return false
        }
    }
}

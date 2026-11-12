import SwiftUI
import PDFKit

/// Wraps Apple's PDFView, with a transparent overlay on top that captures
/// finger / Apple Pencil input while a drawing tool is active.
struct PDFKitView: UIViewRepresentable {
    let controller: PDFEditorController

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        let pdfView = PDFView()
        pdfView.document = controller.document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .secondarySystemBackground
        pdfView.translatesAutoresizingMaskIntoConstraints = false

        let overlay = DrawingOverlayView()
        overlay.backgroundColor = .clear
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.onBegan = { [weak controller] point in controller?.touchBegan(at: point) }
        overlay.onMoved = { [weak controller] points in controller?.touchesMoved(to: points) }
        overlay.onEnded = { [weak controller] point in controller?.touchEnded(at: point) }

        container.addSubview(pdfView)
        container.addSubview(overlay)
        for view in [pdfView, overlay] as [UIView] {
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                view.topAnchor.constraint(equalTo: container.topAnchor),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }

        controller.attach(pdfView: pdfView, overlay: overlay)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

final class DrawingOverlayView: UIView {
    var onBegan: ((CGPoint) -> Void)?
    var onMoved: (([CGPoint]) -> Void)?
    var onEnded: ((CGPoint) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        onBegan?(touch.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        // Coalesced touches give smoother lines, especially with Apple Pencil.
        let samples = event?.coalescedTouches(for: touch) ?? [touch]
        onMoved?(samples.map { $0.location(in: self) })
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        onEnded?(touch.location(in: self))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        onEnded?(touch.location(in: self))
    }
}

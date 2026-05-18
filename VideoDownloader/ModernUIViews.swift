//
//  ModernUIViews.swift
//  VideoDownloader
//
//  Small AppKit view helpers for the glass-style downloader interface.
//

import Cocoa

final class BackgroundImageView: NSImageView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageScaling = .scaleAxesIndependently
        wantsLayer = true
        layer?.contentsGravity = .resizeAspectFill
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        imageScaling = .scaleAxesIndependently
        wantsLayer = true
        layer?.contentsGravity = .resizeAspectFill
        layer?.masksToBounds = true
    }

    override var image: NSImage? {
        didSet {
            layer?.contents = image
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard image == nil else {
            super.draw(dirtyRect)
            return
        }

        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.03, green: 0.08, blue: 0.14, alpha: 1),
            NSColor(calibratedRed: 0.13, green: 0.08, blue: 0.20, alpha: 1),
            NSColor(calibratedRed: 0.04, green: 0.03, blue: 0.07, alpha: 1)
        ])
        gradient?.draw(in: bounds, angle: 315)
    }
}

final class RoundedPanelView: NSView {
    var fillColor: NSColor = NSColor(calibratedWhite: 0.10, alpha: 0.65) {
        didSet { updateLayerStyle() }
    }

    var borderColor: NSColor = NSColor.white.withAlphaComponent(0.16) {
        didSet { updateLayerStyle() }
    }

    var cornerRadius: CGFloat = 16 {
        didSet { updateLayerStyle() }
    }

    var shadowOpacity: Float = 0 {
        didSet { updateLayerStyle() }
    }

    var shadowRadius: CGFloat = 0 {
        didSet { updateLayerStyle() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layout() {
        super.layout()
        updateLayerStyle()
    }

    private func setup() {
        wantsLayer = true
        updateLayerStyle()
    }

    private func updateLayerStyle() {
        guard let layer else { return }
        layer.backgroundColor = fillColor.cgColor
        layer.borderColor = borderColor.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = cornerRadius
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowRadius = shadowRadius
        layer.shadowOffset = NSSize(width: 0, height: -8)
        layer.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
    }
}

final class GradientButton: NSButton {
    var symbolName: String?

    override var isHighlighted: Bool {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
    }

    private func setup() {
        isBordered = false
        wantsLayer = true
        focusRingType = .none
        contentTintColor = .white
    }

    override func draw(_ dirtyRect: NSRect) {
        let drawBounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: drawBounds, xRadius: 9, yRadius: 9)
        let topColor = isHighlighted
            ? NSColor(calibratedRed: 0.40, green: 0.19, blue: 0.85, alpha: 1)
            : NSColor(calibratedRed: 0.58, green: 0.29, blue: 1.0, alpha: 1)
        let bottomColor = isHighlighted
            ? NSColor(calibratedRed: 0.30, green: 0.12, blue: 0.70, alpha: 1)
            : NSColor(calibratedRed: 0.39, green: 0.18, blue: 0.86, alpha: 1)

        NSGradient(starting: topColor, ending: bottomColor)?.draw(in: path, angle: 0)
        NSColor.white.withAlphaComponent(0.18).setStroke()
        path.lineWidth = 1
        path.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]

        let titleSize = title.size(withAttributes: attributes)
        let symbolSize = NSSize(width: 18, height: 18)
        let spacing: CGFloat = symbolName == nil ? 0 : 10
        let totalWidth = titleSize.width + spacing + (symbolName == nil ? 0 : symbolSize.width)
        var x = bounds.midX - totalWidth / 2

        if let symbolName,
           let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            image.isTemplate = true
            NSColor.white.set()
            let imageRect = NSRect(x: x, y: bounds.midY - symbolSize.height / 2, width: symbolSize.width, height: symbolSize.height)
            image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
            x += symbolSize.width + spacing
        }

        let titleRect = NSRect(
            x: x,
            y: bounds.midY - titleSize.height / 2,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: attributes)
    }
}

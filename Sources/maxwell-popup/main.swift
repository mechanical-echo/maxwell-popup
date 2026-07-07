import AppKit
import QuartzCore

class DraggableImageView: NSImageView {
    var initialMouseLocation: NSPoint = .zero
    var onDrag: ((CGFloat) -> Void)?
    var onClick: (() -> Void)?
    private var didDrag = false

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = event.locationInWindow
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }
        let currentLocation = event.locationInWindow
        let deltaX = currentLocation.x - initialMouseLocation.x
        let deltaY = currentLocation.y - initialMouseLocation.y
        if abs(deltaX) > 3 || abs(deltaY) > 3 {
            didDrag = true
        }
        let newOrigin = NSPoint(
            x: window.frame.origin.x + deltaX,
            y: window.frame.origin.y + deltaY
        )
        window.setFrameOrigin(newOrigin)
        onDrag?(newOrigin.y)
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onClick?()
        }
    }
}

class AnimatedGIFView: NSView {
    var initialMouseLocation: NSPoint = .zero
    var onDrag: ((CGFloat) -> Void)?
    var onClick: (() -> Void)?
    private var didDrag = false

    private var frames: [(image: CGImage, duration: Double)] = []
    private var currentFrameIndex = 0
    private var frameTimer: Timer?
    private var imageLayer: CALayer!

    var draggable: Bool = true

    var speed: Double = 1.0 {
        didSet {
            if speed != oldValue {
                restartAnimation()
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        wantsLayer = true
        imageLayer = CALayer()
        imageLayer.frame = bounds
        imageLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(imageLayer)
    }

    override func layout() {
        super.layout()
        imageLayer?.frame = bounds
    }

    func loadGIF(from url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        let count = CGImageSourceGetCount(source)
        stopAnimation()
        currentFrameIndex = 0
        frames.removeAll()

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            var frameDuration = 0.1

            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProps = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                if let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, delay > 0 {
                    frameDuration = delay
                } else if let delay = gifProps[kCGImagePropertyGIFDelayTime as String] as? Double, delay > 0 {
                    frameDuration = delay
                }
            }
            frames.append((cgImage, frameDuration))
        }

        if !frames.isEmpty {
            displayFrame(0)
            startAnimation()
        }
    }

    private func displayFrame(_ index: Int) {
        guard index < frames.count else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = frames[index].image
        CATransaction.commit()
    }

    private func startAnimation() {
        guard frames.count > 1 else { return }
        scheduleNextFrame()
    }

    private func scheduleNextFrame() {
        guard !frames.isEmpty else { return }
        let duration = frames[currentFrameIndex].duration / speed
        let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            self?.advanceFrame()
        }
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    private func advanceFrame() {
        currentFrameIndex = (currentFrameIndex + 1) % frames.count
        displayFrame(currentFrameIndex)
        scheduleNextFrame()
    }

    private func restartAnimation() {
        frameTimer?.invalidate()
        frameTimer = nil
        if !frames.isEmpty {
            scheduleNextFrame()
        }
    }

    func stopAnimation() {
        frameTimer?.invalidate()
        frameTimer = nil
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = event.locationInWindow
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard draggable, let window = self.window else { return }
        let currentLocation = event.locationInWindow
        let deltaX = currentLocation.x - initialMouseLocation.x
        let deltaY = currentLocation.y - initialMouseLocation.y
        if abs(deltaX) > 3 || abs(deltaY) > 3 {
            didDrag = true
        }
        let newOrigin = NSPoint(
            x: window.frame.origin.x + deltaX,
            y: window.frame.origin.y + deltaY
        )
        window.setFrameOrigin(newOrigin)
        onDrag?(newOrigin.y)
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onClick?()
        }
    }
}

class SpeechBubble: NSView {
    var message: String = "" {
        didSet { textLabel.stringValue = message }
    }
    var isClickable: Bool = false {
        didSet { updateClickableAppearance() }
    }
    var onTap: (() -> Void)?

    private var visualEffectView: NSVisualEffectView?
    private var textLabel: NSTextField!
    private var arrowLabel: NSTextField?
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false

        let bubbleRect = NSRect(x: 0, y: 12, width: bounds.width, height: bounds.height - 12)

        let effect = NSVisualEffectView(frame: bubbleRect)
        effect.material = .popover
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.borderWidth = 0.5
        effect.layer?.borderColor = NSColor.gray.withAlphaComponent(0.3).cgColor
        addSubview(effect)
        visualEffectView = effect

        textLabel = NSTextField(labelWithString: "")
        textLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        textLabel.textColor = NSColor.labelColor
        textLabel.alignment = .center
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.maximumNumberOfLines = 2
        textLabel.cell?.wraps = true
        textLabel.cell?.truncatesLastVisibleLine = true
        effect.addSubview(textLabel)

        let arrow = NSTextField(labelWithString: "›")
        arrow.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        arrow.textColor = NSColor.secondaryLabelColor
        arrow.alignment = .center
        arrow.isHidden = true
        effect.addSubview(arrow)
        arrowLabel = arrow
    }

    private func updateClickableAppearance() {
        arrowLabel?.isHidden = !isClickable
        if isClickable {
            textLabel?.frame = NSRect(x: 8, y: 4, width: (visualEffectView?.bounds.width ?? bounds.width) - 28, height: (visualEffectView?.bounds.height ?? bounds.height - 12) - 8)
        } else {
            textLabel?.frame = NSRect(x: 8, y: 4, width: (visualEffectView?.bounds.width ?? bounds.width) - 16, height: (visualEffectView?.bounds.height ?? bounds.height - 12) - 8)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        if isClickable {
            NSCursor.pointingHand.set()
            visualEffectView?.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
            visualEffectView?.layer?.borderWidth = 1.0
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        visualEffectView?.layer?.borderColor = NSColor.gray.withAlphaComponent(0.3).cgColor
        visualEffectView?.layer?.borderWidth = 0.5
    }

    override func mouseDown(with event: NSEvent) {
        if isClickable {
            onTap?()
        }
    }

    override func layout() {
        super.layout()
        let bubbleRect = NSRect(x: 0, y: 12, width: bounds.width, height: bounds.height - 12)
        visualEffectView?.frame = bubbleRect
        let textWidth = isClickable ? bubbleRect.width - 28 : bubbleRect.width - 16
        textLabel?.frame = NSRect(x: 8, y: 4, width: textWidth, height: bubbleRect.height - 8)
        arrowLabel?.frame = NSRect(x: bubbleRect.width - 20, y: 8, width: 16, height: bubbleRect.height - 16)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let tailPath = NSBezierPath()
        let tailWidth: CGFloat = 12
        let centerX = bounds.width / 2
        tailPath.move(to: NSPoint(x: centerX - tailWidth / 2, y: 12))
        tailPath.line(to: NSPoint(x: centerX, y: 4))
        tailPath.line(to: NSPoint(x: centerX + tailWidth / 2, y: 12))
        tailPath.close()

        NSColor.windowBackgroundColor.withAlphaComponent(0.9).setFill()
        tailPath.fill()

        NSColor.gray.withAlphaComponent(0.3).setStroke()
        tailPath.lineWidth = 0.5
        tailPath.stroke()
    }
}

struct RemoteConfig: Codable {
    var name: String
    var host: String
    var user: String
    var keyPath: String
    var enabled: Bool
}

struct SessionInfo {
    var message: String
    var cwd: String
    var sessionId: String
    var isRemote: Bool
    var remoteName: String?
}

struct MaxwellConfig: Codable {
    var remotes: [RemoteConfig]
    var gifSpeed: Double
    var showDoneBubbles: Bool
    var theme: String
    var clickMessage: String
    var settingsStyle: String

    static let configPath = NSString(string: "~/.maxwell/config.json").expandingTildeInPath
    static let defaultTheme = "Maxwell.gif"
    static let defaultClickMessage = "meow"
    static let defaultSettingsStyle = "y2k"

    init(remotes: [RemoteConfig] = [], gifSpeed: Double = 1.0, showDoneBubbles: Bool = false,
         theme: String = MaxwellConfig.defaultTheme,
         clickMessage: String = MaxwellConfig.defaultClickMessage,
         settingsStyle: String = MaxwellConfig.defaultSettingsStyle) {
        self.remotes = remotes
        self.gifSpeed = gifSpeed
        self.showDoneBubbles = showDoneBubbles
        self.theme = theme
        self.clickMessage = clickMessage
        self.settingsStyle = settingsStyle
    }

    enum CodingKeys: String, CodingKey {
        case remotes, gifSpeed, showDoneBubbles, theme, clickMessage, settingsStyle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        remotes = (try? c.decode([RemoteConfig].self, forKey: .remotes)) ?? []
        gifSpeed = (try? c.decode(Double.self, forKey: .gifSpeed)) ?? 1.0
        showDoneBubbles = (try? c.decode(Bool.self, forKey: .showDoneBubbles)) ?? false
        theme = (try? c.decode(String.self, forKey: .theme)) ?? MaxwellConfig.defaultTheme
        clickMessage = (try? c.decode(String.self, forKey: .clickMessage)) ?? MaxwellConfig.defaultClickMessage
        settingsStyle = (try? c.decode(String.self, forKey: .settingsStyle)) ?? MaxwellConfig.defaultSettingsStyle
    }

    static func load() -> MaxwellConfig {
        guard let data = FileManager.default.contents(atPath: configPath),
              let config = try? JSONDecoder().decode(MaxwellConfig.self, from: data) else {
            return MaxwellConfig()
        }
        return config
    }

    func save() {
        let dir = NSString(string: "~/.maxwell").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: URL(fileURLWithPath: MaxwellConfig.configPath))
        }
    }
}

enum ThemeManager {
    static let gifsDirectory = NSString(string: "~/.maxwell/gifs").expandingTildeInPath
    static let bundledGifs = ["Maxwell", "Maxwell_pixel"]

    static func seedIfNeeded() {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: gifsDirectory, withIntermediateDirectories: true)
        for name in bundledGifs {
            let dest = (gifsDirectory as NSString).appendingPathComponent("\(name).gif")
            guard !fm.fileExists(atPath: dest),
                  let src = Bundle.module.url(forResource: name, withExtension: "gif") else { continue }
            try? fm.copyItem(at: src, to: URL(fileURLWithPath: dest))
        }
    }

    static func availableThemes() -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: gifsDirectory),
            includingPropertiesForKeys: nil) else { return [] }
        return items
            .filter { $0.pathExtension.lowercased() == "gif" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func gifURL(for theme: String) -> URL? {
        let path = (gifsDirectory as NSString).appendingPathComponent(theme)
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        let base = (theme as NSString).deletingPathExtension
        return Bundle.module.url(forResource: base.isEmpty ? "Maxwell" : base, withExtension: "gif")
            ?? Bundle.module.url(forResource: "Maxwell", withExtension: "gif")
    }

    static func displayName(for url: URL) -> String {
        return (url.lastPathComponent as NSString).deletingPathExtension
    }
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

enum SkinKind {
    case pixel
    case chrome
}

struct PixelPalette {
    let cream: NSColor
    let blush: NSColor
    let bubblegum: NSColor
    let raspberry: NSColor
    let plum: NSColor
    let ink: NSColor
    let field: NSColor
    let fieldText: NSColor
}

enum PixelStyle {
    static let unit: CGFloat = 3

    static let styles: [(id: String, icon: String, title: String, kind: SkinKind, palette: PixelPalette)] = [
        ("pixelpop", "♥", "PIXELPOP", .pixel, PixelPalette(
            cream: NSColor(calibratedRed: 1.0, green: 0.941, blue: 0.965, alpha: 1.0),
            blush: NSColor(calibratedRed: 1.0, green: 0.851, blue: 0.910, alpha: 1.0),
            bubblegum: NSColor(calibratedRed: 1.0, green: 0.620, blue: 0.769, alpha: 1.0),
            raspberry: NSColor(calibratedRed: 0.851, green: 0.341, blue: 0.561, alpha: 1.0),
            plum: NSColor(calibratedRed: 0.576, green: 0.212, blue: 0.373, alpha: 1.0),
            ink: NSColor(calibratedRed: 0.576, green: 0.212, blue: 0.373, alpha: 1.0),
            field: .white,
            fieldText: NSColor(calibratedRed: 0.576, green: 0.212, blue: 0.373, alpha: 1.0))),
        ("midnight", "☾", "MIDNIGHT", .pixel, PixelPalette(
            cream: NSColor(calibratedRed: 0.149, green: 0.071, blue: 0.110, alpha: 1.0),
            blush: NSColor(calibratedRed: 0.231, green: 0.114, blue: 0.173, alpha: 1.0),
            bubblegum: NSColor(calibratedRed: 1.0, green: 0.620, blue: 0.769, alpha: 1.0),
            raspberry: NSColor(calibratedRed: 0.929, green: 0.435, blue: 0.659, alpha: 1.0),
            plum: NSColor(calibratedRed: 0.071, green: 0.027, blue: 0.067, alpha: 1.0),
            ink: NSColor(calibratedRed: 1.0, green: 0.851, blue: 0.910, alpha: 1.0),
            field: NSColor(calibratedRed: 0.275, green: 0.133, blue: 0.227, alpha: 1.0),
            fieldText: NSColor(calibratedRed: 1.0, green: 0.851, blue: 0.910, alpha: 1.0))),
        ("y2k", "▶", "Y2K", .chrome, PixelPalette(
            cream: NSColor(calibratedRed: 0.894, green: 0.871, blue: 0.894, alpha: 1.0),
            blush: NSColor(calibratedRed: 0.949, green: 0.914, blue: 0.941, alpha: 1.0),
            bubblegum: NSColor(calibratedRed: 1.0, green: 0.561, blue: 0.753, alpha: 1.0),
            raspberry: NSColor(calibratedRed: 0.839, green: 0.306, blue: 0.573, alpha: 1.0),
            plum: NSColor(calibratedRed: 0.298, green: 0.243, blue: 0.298, alpha: 1.0),
            ink: NSColor(calibratedRed: 0.271, green: 0.227, blue: 0.278, alpha: 1.0),
            field: NSColor(calibratedRed: 0.157, green: 0.110, blue: 0.165, alpha: 1.0),
            fieldText: NSColor(calibratedRed: 1.0, green: 0.620, blue: 0.824, alpha: 1.0)))
    ]

    static var current: PixelPalette = styles[0].palette
    static var currentKind: SkinKind = .pixel

    static var isChrome: Bool { currentKind == .chrome }

    static func apply(styleId: String) {
        let style = styles.first { $0.id == styleId } ?? styles[0]
        current = style.palette
        currentKind = style.kind
    }

    static var cream: NSColor { current.cream }
    static var blush: NSColor { current.blush }
    static var bubblegum: NSColor { current.bubblegum }
    static var raspberry: NSColor { current.raspberry }
    static var plum: NSColor { current.plum }
    static var ink: NSColor { current.ink }
    static var field: NSColor { current.field }
    static var fieldText: NSColor { current.fieldText }

    static func font(_ size: CGFloat, weight: NSFont.Weight = .bold) -> NSFont {
        if isChrome {
            let bold = weight.rawValue >= NSFont.Weight.semibold.rawValue
            return NSFont(name: bold ? "Tahoma-Bold" : "Tahoma", size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    static func lcdFont(_ size: CGFloat) -> NSFont {
        return NSFont(name: "Verdana-Bold", size: size)
            ?? NSFont(name: "Menlo-Bold", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }

    static func logoFont(_ size: CGFloat) -> NSFont {
        return NSFont(name: "Trebuchet-BoldItalic", size: size)
            ?? NSFont(name: "TrebuchetMS-Bold", size: size)
            ?? NSFont(name: "Verdana-BoldItalic", size: size)
            ?? NSFont.boldSystemFont(ofSize: size)
    }

    static func lcdAttributes(size: CGFloat) -> [NSAttributedString.Key: Any] {
        let glow = NSShadow()
        glow.shadowColor = fieldText.withAlphaComponent(0.9)
        glow.shadowBlurRadius = 5
        glow.shadowOffset = .zero
        return [
            .font: lcdFont(size),
            .foregroundColor: fieldText,
            .shadow: glow,
            .kern: 1.5
        ]
    }

    static func label(_ text: String, size: CGFloat, color: NSColor, weight: NSFont.Weight = .bold) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font(size, weight: weight)
        field.textColor = color
        return field
    }

    static func caption(_ text: String) -> NSView {
        if isChrome {
            let content = NSAttributedString(string: text, attributes: lcdAttributes(size: 10))
            let size = content.size()
            let strip = LCDStripView(frame: NSRect(x: 0, y: 0, width: size.width + 32, height: size.height + 16))
            strip.text = text
            return strip
        }
        let result = label(text, size: 11, color: raspberry)
        result.sizeToFit()
        return result
    }

    static func styleField(_ field: NSTextField, size: CGFloat = 11) {
        field.isBordered = false
        field.isBezeled = false
        field.isEditable = true
        field.drawsBackground = true
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.wantsLayer = true
        if isChrome {
            field.backgroundColor = PixelStyle.field
            field.textColor = fieldText
            field.font = lcdFont(size)
            field.layer?.cornerRadius = 4
            field.layer?.borderColor = plum.withAlphaComponent(0.8).cgColor
            field.layer?.borderWidth = 1
        } else {
            field.backgroundColor = PixelStyle.field
            field.textColor = ink
            field.font = font(size, weight: .medium)
            field.layer?.cornerRadius = 0
            field.layer?.borderColor = raspberry.withAlphaComponent(0.6).cgColor
            field.layer?.borderWidth = 2
        }
    }

    static func smoothHeartPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let r = rect.width / 4
        let lobeY = rect.maxY - r
        path.move(to: NSPoint(x: rect.midX, y: rect.minY))
        path.curve(
            to: NSPoint(x: rect.minX, y: lobeY),
            controlPoint1: NSPoint(x: rect.midX - rect.width * 0.38, y: rect.minY + rect.height * 0.28),
            controlPoint2: NSPoint(x: rect.minX, y: rect.minY + rect.height * 0.5))
        path.appendArc(withCenter: NSPoint(x: rect.minX + r, y: lobeY), radius: r, startAngle: 180, endAngle: 0, clockwise: true)
        path.appendArc(withCenter: NSPoint(x: rect.maxX - r, y: lobeY), radius: r, startAngle: 180, endAngle: 0, clockwise: true)
        path.curve(
            to: NSPoint(x: rect.midX, y: rect.minY),
            controlPoint1: NSPoint(x: rect.maxX, y: rect.minY + rect.height * 0.5),
            controlPoint2: NSPoint(x: rect.midX + rect.width * 0.38, y: rect.minY + rect.height * 0.28))
        path.close()
        return path
    }

    static func drawChromeFace(in rect: NSRect, base: NSColor, pressed: Bool, hovered: Bool) {
        let isRound = abs(rect.width - rect.height) < 6
        let radius = isRound ? rect.height / 2 : min(rect.height / 2, 14)
        let rimPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        if !pressed {
            NSGraphicsContext.saveGraphicsState()
            let drop = NSShadow()
            drop.shadowColor = NSColor.black.withAlphaComponent(0.35)
            drop.shadowOffset = NSSize(width: 0, height: -2)
            drop.shadowBlurRadius = 3
            drop.set()
            plum.setFill()
            rimPath.fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        let rimDark = plum.blended(withFraction: 0.35, of: .black) ?? plum
        let rimLight = plum.blended(withFraction: 0.6, of: .white) ?? plum
        NSGradient(colors: pressed ? [rimDark, plum] : [rimLight, rimDark])?.draw(in: rimPath, angle: -90)

        let capRect = rect.insetBy(dx: 2.5, dy: 2.5)
        let capRadius = max(radius - 2.5, 2)
        let capPath = NSBezierPath(roundedRect: capRect, xRadius: capRadius, yRadius: capRadius)
        var face = base
        if hovered && !pressed {
            face = base.blended(withFraction: 0.14, of: .white) ?? base
        }
        let light = face.blended(withFraction: 0.6, of: .white) ?? face
        let dark = face.blended(withFraction: 0.25, of: .black) ?? face
        if pressed {
            NSGradient(colorsAndLocations: (dark, 0.0), (face, 0.7), (face, 1.0))?.draw(in: capPath, angle: 90)
            NSGraphicsContext.saveGraphicsState()
            capPath.addClip()
            NSColor.black.withAlphaComponent(0.25).setFill()
            NSRect(x: capRect.minX, y: capRect.maxY - 3, width: capRect.width, height: 3).fill()
            NSGraphicsContext.restoreGraphicsState()
        } else {
            NSGradient(colorsAndLocations: (light, 0.0), (face, 0.5), (dark, 1.0))?.draw(in: capPath, angle: -90)
            NSGraphicsContext.saveGraphicsState()
            capPath.addClip()
            let specRect = NSRect(
                x: capRect.minX + capRect.width * 0.12,
                y: capRect.minY + capRect.height * 0.5,
                width: capRect.width * 0.76,
                height: capRect.height * 0.44)
            let spec = NSBezierPath(ovalIn: specRect)
            NSGradient(colors: [NSColor.white.withAlphaComponent(0.85), NSColor.white.withAlphaComponent(0.05)])?.draw(in: spec, angle: -90)
            NSColor.white.withAlphaComponent(0.3).setFill()
            NSRect(x: capRect.minX + 3, y: capRect.minY + 0.5, width: capRect.width - 6, height: 1.2).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    @discardableResult
    static func drawLCDBezel(in rect: NSRect) -> NSRect {
        let framePath = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        let frameDark = NSColor.black.withAlphaComponent(0.85)
        let frameMid = plum.blended(withFraction: 0.5, of: .black) ?? plum
        NSGradient(colors: [frameMid, frameDark])?.draw(in: framePath, angle: -90)
        NSColor.white.withAlphaComponent(0.25).setStroke()
        framePath.lineWidth = 1
        framePath.stroke()

        let screen = rect.insetBy(dx: 4, dy: 4)
        let screenPath = NSBezierPath(roundedRect: screen, xRadius: 4, yRadius: 4)
        field.setFill()
        screenPath.fill()
        NSGraphicsContext.saveGraphicsState()
        screenPath.addClip()
        NSColor.black.withAlphaComponent(0.18).setFill()
        var lineY = screen.minY
        while lineY < screen.maxY {
            NSRect(x: screen.minX, y: lineY, width: screen.width, height: 0.6).fill()
            lineY += 2.4
        }
        NSColor.black.withAlphaComponent(0.35).setFill()
        NSRect(x: screen.minX, y: screen.maxY - 2, width: screen.width, height: 2).fill()
        let streak = NSBezierPath()
        streak.move(to: NSPoint(x: screen.minX + screen.width * 0.55, y: screen.maxY))
        streak.line(to: NSPoint(x: screen.minX + screen.width * 0.75, y: screen.maxY))
        streak.line(to: NSPoint(x: screen.minX + screen.width * 0.6, y: screen.minY))
        streak.line(to: NSPoint(x: screen.minX + screen.width * 0.45, y: screen.minY))
        streak.close()
        NSColor.white.withAlphaComponent(0.07).setFill()
        streak.fill()
        NSGraphicsContext.restoreGraphicsState()
        return screen
    }

    static func drawSpeakerGrille(in rect: NSRect) {
        let frame = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        NSColor.black.withAlphaComponent(0.07).setFill()
        frame.fill()
        NSColor.black.withAlphaComponent(0.18).setStroke()
        frame.lineWidth = 1
        frame.stroke()
        NSColor.white.withAlphaComponent(0.5).setStroke()
        let lip = NSBezierPath(roundedRect: rect.offsetBy(dx: 0, dy: -1), xRadius: 10, yRadius: 10)
        lip.lineWidth = 1
        lip.stroke()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect.insetBy(dx: 7, dy: 7), xRadius: 8, yRadius: 8).addClip()
        let step: CGFloat = 9
        var row = 0
        var holeY = rect.minY + 9
        while holeY < rect.maxY - 5 {
            var holeX = rect.minX + 9 + (row % 2 == 0 ? 0 : step / 2)
            while holeX < rect.maxX - 5 {
                NSColor.white.withAlphaComponent(0.55).setFill()
                NSBezierPath(ovalIn: NSRect(x: holeX - 2.2, y: holeY - 3.2, width: 4.4, height: 4.4)).fill()
                NSColor.black.withAlphaComponent(0.5).setFill()
                NSBezierPath(ovalIn: NSRect(x: holeX - 2.2, y: holeY - 2.2, width: 4.4, height: 4.4)).fill()
                holeX += step
            }
            holeY += step * 0.87
            row += 1
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    static func drawWell(in rect: NSRect, radius: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        field.setFill()
        path.fill()
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSColor.black.withAlphaComponent(0.4).setFill()
        NSRect(x: rect.minX, y: rect.maxY - 2, width: rect.width, height: 2).fill()
        NSColor.white.withAlphaComponent(0.28).setFill()
        NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1.5).fill()
        NSGraphicsContext.restoreGraphicsState()
        plum.withAlphaComponent(0.7).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    static func drawScrew(at center: NSPoint, radius: CGFloat) {
        let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let path = NSBezierPath(ovalIn: rect)
        NSGradient(colors: [NSColor(calibratedWhite: 0.95, alpha: 1.0), NSColor(calibratedWhite: 0.6, alpha: 1.0)])?.draw(in: path, angle: -90)
        NSColor(calibratedWhite: 0.35, alpha: 0.8).setStroke()
        path.lineWidth = 0.8
        path.stroke()
        let slot = NSBezierPath()
        slot.move(to: NSPoint(x: center.x - radius * 0.55, y: center.y))
        slot.line(to: NSPoint(x: center.x + radius * 0.55, y: center.y))
        slot.move(to: NSPoint(x: center.x, y: center.y - radius * 0.55))
        slot.line(to: NSPoint(x: center.x, y: center.y + radius * 0.55))
        NSColor(calibratedWhite: 0.3, alpha: 0.9).setStroke()
        slot.lineWidth = 1.2
        slot.stroke()
    }

    static func glowDotImage(size: CGFloat, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let center = NSPoint(x: size / 2, y: size / 2)
        NSGradient(colors: [color.withAlphaComponent(0.95), color.withAlphaComponent(0.0)])?
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: size / 2, options: [])
        image.unlockFocus()
        return image
    }

    static func steppedPath(in rect: NSRect, step s: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: rect.minX + 2 * s, y: rect.minY))
        p.line(to: NSPoint(x: rect.maxX - 2 * s, y: rect.minY))
        p.line(to: NSPoint(x: rect.maxX - 2 * s, y: rect.minY + s))
        p.line(to: NSPoint(x: rect.maxX - s, y: rect.minY + s))
        p.line(to: NSPoint(x: rect.maxX - s, y: rect.minY + 2 * s))
        p.line(to: NSPoint(x: rect.maxX, y: rect.minY + 2 * s))
        p.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 2 * s))
        p.line(to: NSPoint(x: rect.maxX - s, y: rect.maxY - 2 * s))
        p.line(to: NSPoint(x: rect.maxX - s, y: rect.maxY - s))
        p.line(to: NSPoint(x: rect.maxX - 2 * s, y: rect.maxY - s))
        p.line(to: NSPoint(x: rect.maxX - 2 * s, y: rect.maxY))
        p.line(to: NSPoint(x: rect.minX + 2 * s, y: rect.maxY))
        p.line(to: NSPoint(x: rect.minX + 2 * s, y: rect.maxY - s))
        p.line(to: NSPoint(x: rect.minX + s, y: rect.maxY - s))
        p.line(to: NSPoint(x: rect.minX + s, y: rect.maxY - 2 * s))
        p.line(to: NSPoint(x: rect.minX, y: rect.maxY - 2 * s))
        p.line(to: NSPoint(x: rect.minX, y: rect.minY + 2 * s))
        p.line(to: NSPoint(x: rect.minX + s, y: rect.minY + 2 * s))
        p.line(to: NSPoint(x: rect.minX + s, y: rect.minY + s))
        p.line(to: NSPoint(x: rect.minX + 2 * s, y: rect.minY + s))
        p.close()
        return p
    }

    static func heartPath(in rect: NSRect, flipped: Bool = false) -> NSBezierPath {
        let rows: [[Int]] = [
            [0, 1, 1, 0, 1, 1, 0],
            [1, 1, 1, 1, 1, 1, 1],
            [1, 1, 1, 1, 1, 1, 1],
            [0, 1, 1, 1, 1, 1, 0],
            [0, 0, 1, 1, 1, 0, 0],
            [0, 0, 0, 1, 0, 0, 0]
        ]
        let path = NSBezierPath()
        let cellW = rect.width / 7
        let cellH = rect.height / 6
        for (r, row) in rows.enumerated() {
            for (c, v) in row.enumerated() where v == 1 {
                let y = flipped ? rect.minY + CGFloat(r) * cellH : rect.maxY - CGFloat(r + 1) * cellH
                path.appendRect(NSRect(x: rect.minX + CGFloat(c) * cellW, y: y, width: cellW, height: cellH))
            }
        }
        return path
    }

    static func sparkleImage(size: CGFloat, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        color.setFill()
        let cell = size / 5
        NSRect(x: 2 * cell, y: 0, width: cell, height: size).fill()
        NSRect(x: 0, y: 2 * cell, width: size, height: cell).fill()
        image.unlockFocus()
        return image
    }
}

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

class EQBarsView: NSView {
    private var configured = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !configured else { return }
        configured = true
        wantsLayer = true
        let barCount = 9
        let gap: CGFloat = 2
        let barWidth = (bounds.width - gap * CGFloat(barCount - 1)) / CGFloat(barCount)
        let peaks: [CGFloat] = [0.5, 0.85, 0.65, 1.0, 0.45, 0.9, 0.7, 0.55, 0.8]
        for i in 0..<barCount {
            let bar = CALayer()
            bar.backgroundColor = PixelStyle.fieldText.cgColor
            bar.anchorPoint = CGPoint(x: 0.5, y: 0)
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: bounds.height)
            bar.position = CGPoint(x: CGFloat(i) * (barWidth + gap) + barWidth / 2, y: 0)
            bar.shadowColor = PixelStyle.fieldText.cgColor
            bar.shadowOpacity = 0.8
            bar.shadowRadius = 3
            bar.shadowOffset = .zero
            layer?.addSublayer(bar)
            let bounce = CABasicAnimation(keyPath: "transform.scale.y")
            bounce.fromValue = 0.12
            bounce.toValue = peaks[i % peaks.count]
            bounce.duration = 0.35 + Double(i % 4) * 0.09
            bounce.autoreverses = true
            bounce.repeatCount = .infinity
            bounce.beginTime = CACurrentMediaTime() + Double(i) * 0.07
            bar.add(bounce, forKey: "bounce")
        }
    }
}

class LCDStripView: NSView {
    var text: String = "" { didSet { needsDisplay = true } }
    var showsEQ = false
    private var eqView: EQBarsView?

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard showsEQ, eqView == nil, window != nil else { return }
        let eq = EQBarsView(frame: NSRect(x: bounds.width - 60, y: 8, width: 48, height: bounds.height - 17))
        eqView = eq
        addSubview(eq)
    }

    override func draw(_ dirtyRect: NSRect) {
        let screen = PixelStyle.drawLCDBezel(in: bounds)
        let content = NSAttributedString(string: text, attributes: PixelStyle.lcdAttributes(size: showsEQ ? 12 : 10))
        let size = content.size()
        let x = showsEQ ? screen.minX + 10 : screen.midX - size.width / 2
        content.draw(at: NSPoint(x: x, y: screen.midY - size.height / 2))
    }
}

class PixelPanelView: NSView {
    static let bodyRect = NSRect(x: 10, y: 12, width: 600, height: 444)
    static var headerHeight: CGFloat { PixelStyle.isChrome ? 66 : 46 }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    private func earPath(centerX: CGFloat, baseY: CGFloat, columnWidth: CGFloat, heights: [CGFloat]) -> NSBezierPath {
        let path = NSBezierPath()
        let startX = centerX - columnWidth * CGFloat(heights.count) / 2
        path.move(to: NSPoint(x: startX, y: baseY))
        for (i, h) in heights.enumerated() {
            let x = startX + CGFloat(i) * columnWidth
            path.line(to: NSPoint(x: x, y: baseY + h))
            path.line(to: NSPoint(x: x + columnWidth, y: baseY + h))
        }
        path.line(to: NSPoint(x: startX + CGFloat(heights.count) * columnWidth, y: baseY))
        path.close()
        return path
    }

    private func earCenters(body: NSRect) -> [CGFloat] {
        return [body.minX + body.width * 0.2, body.maxX - body.width * 0.2]
    }

    private func panelSilhouette(body: NSRect) -> NSBezierPath {
        let u = PixelStyle.unit
        let path = PixelStyle.steppedPath(in: body, step: u)
        let heights = ([2, 4, 6, 8, 10, 10, 8, 6, 4, 2] as [CGFloat]).map { $0 * u }
        for centerX in earCenters(body: body) {
            path.append(earPath(centerX: centerX, baseY: body.maxY - u, columnWidth: 2 * u, heights: heights))
        }
        return path
    }

    private func smoothEarPath(centerX: CGFloat, baseY: CGFloat, width: CGFloat, height: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let half = width / 2
        path.move(to: NSPoint(x: centerX - half, y: baseY))
        path.curve(
            to: NSPoint(x: centerX, y: baseY + height),
            controlPoint1: NSPoint(x: centerX - half * 0.75, y: baseY + height * 0.35),
            controlPoint2: NSPoint(x: centerX - half * 0.22, y: baseY + height * 0.8))
        path.curve(
            to: NSPoint(x: centerX + half, y: baseY),
            controlPoint1: NSPoint(x: centerX + half * 0.22, y: baseY + height * 0.8),
            controlPoint2: NSPoint(x: centerX + half * 0.75, y: baseY + height * 0.35))
        path.close()
        return path
    }

    private func appendEarRightToLeft(to path: NSBezierPath, centerX: CGFloat, baseY: CGFloat, half: CGFloat, height: CGFloat) {
        path.line(to: NSPoint(x: centerX + half, y: baseY))
        path.curve(
            to: NSPoint(x: centerX, y: baseY + height),
            controlPoint1: NSPoint(x: centerX + half * 0.75, y: baseY + height * 0.35),
            controlPoint2: NSPoint(x: centerX + half * 0.22, y: baseY + height * 0.8))
        path.curve(
            to: NSPoint(x: centerX - half, y: baseY),
            controlPoint1: NSPoint(x: centerX - half * 0.22, y: baseY + height * 0.8),
            controlPoint2: NSPoint(x: centerX - half * 0.75, y: baseY + height * 0.35))
    }

    private func chromeSilhouette(body: NSRect) -> NSBezierPath {
        let r: CGFloat = 20
        let path = NSBezierPath()
        path.move(to: NSPoint(x: body.minX + r, y: body.minY))
        path.line(to: NSPoint(x: body.maxX - r, y: body.minY))
        path.appendArc(withCenter: NSPoint(x: body.maxX - r, y: body.minY + r), radius: r, startAngle: 270, endAngle: 360, clockwise: false)
        path.line(to: NSPoint(x: body.maxX, y: body.maxY - r))
        path.appendArc(withCenter: NSPoint(x: body.maxX - r, y: body.maxY - r), radius: r, startAngle: 0, endAngle: 90, clockwise: false)
        for centerX in earCenters(body: body).sorted(by: >) {
            appendEarRightToLeft(to: path, centerX: centerX, baseY: body.maxY, half: 33, height: 50)
        }
        path.line(to: NSPoint(x: body.minX + r, y: body.maxY))
        path.appendArc(withCenter: NSPoint(x: body.minX + r, y: body.maxY - r), radius: r, startAngle: 90, endAngle: 180, clockwise: false)
        path.line(to: NSPoint(x: body.minX, y: body.minY + r))
        path.appendArc(withCenter: NSPoint(x: body.minX + r, y: body.minY + r), radius: r, startAngle: 180, endAngle: 270, clockwise: false)
        path.close()
        return path
    }

    private func drawChromePanel() {
        let body = PixelPanelView.bodyRect
        let silhouette = chromeSilhouette(body: body)

        NSGraphicsContext.saveGraphicsState()
        let drop = NSShadow()
        drop.shadowColor = NSColor.black.withAlphaComponent(0.35)
        drop.shadowOffset = NSSize(width: 0, height: -5)
        drop.shadowBlurRadius = 14
        drop.set()
        PixelStyle.cream.setFill()
        silhouette.fill()
        NSGraphicsContext.restoreGraphicsState()

        let light = PixelStyle.cream.blended(withFraction: 0.55, of: .white) ?? PixelStyle.cream
        let dark = PixelStyle.cream.blended(withFraction: 0.14, of: .black) ?? PixelStyle.cream
        NSGradient(colorsAndLocations: (light, 0.0), (PixelStyle.cream, 0.45), (dark, 1.0))?.draw(in: silhouette, angle: -90)

        let bandY = body.maxY - PixelPanelView.headerHeight
        NSGraphicsContext.saveGraphicsState()
        silhouette.addClip()
        NSColor.white.withAlphaComponent(0.05).setFill()
        var lineY = body.minY
        while lineY < bandY {
            NSRect(x: body.minX, y: lineY, width: body.width, height: 0.5).fill()
            lineY += 3
        }
        let glossRect = NSRect(x: body.minX, y: body.maxY - body.height * 0.42, width: body.width, height: body.height * 0.42)
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.0), NSColor.white.withAlphaComponent(0.25)])?.draw(in: glossRect, angle: -90)

        let lidRect = NSRect(x: body.minX, y: bandY, width: body.width, height: PixelPanelView.headerHeight + 60)
        let lidLight = PixelStyle.bubblegum.blended(withFraction: 0.5, of: .white) ?? PixelStyle.bubblegum
        let lidDark = PixelStyle.bubblegum.blended(withFraction: 0.15, of: .black) ?? PixelStyle.bubblegum
        NSGradient(colorsAndLocations: (lidLight, 0.0), (PixelStyle.bubblegum, 0.6), (lidDark, 1.0))?.draw(in: lidRect, angle: -90)
        let lidGloss = NSRect(x: body.minX, y: bandY + PixelPanelView.headerHeight * 0.5, width: body.width, height: PixelPanelView.headerHeight * 0.5 + 60)
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.45), NSColor.white.withAlphaComponent(0.02)])?.draw(in: lidGloss, angle: -90)

        NSColor.black.withAlphaComponent(0.3).setFill()
        NSRect(x: body.minX, y: bandY, width: body.width, height: 1.2).fill()
        NSColor.white.withAlphaComponent(0.75).setFill()
        NSRect(x: body.minX, y: bandY - 1.7, width: body.width, height: 1.2).fill()
        NSGraphicsContext.restoreGraphicsState()

        for centerX in earCenters(body: body) {
            let pad = smoothEarPath(centerX: centerX, baseY: body.maxY + 1, width: 38, height: 34)
            NSGradient(colors: [NSColor.white, PixelStyle.blush])?.draw(in: pad, angle: -90)
            PixelStyle.raspberry.withAlphaComponent(0.45).setStroke()
            pad.lineWidth = 1
            pad.stroke()
        }

        PixelStyle.plum.withAlphaComponent(0.8).setStroke()
        silhouette.lineWidth = 1.5
        silhouette.stroke()

        let grooveRect = body.insetBy(dx: 8, dy: 8)
        NSGraphicsContext.saveGraphicsState()
        silhouette.addClip()
        let grooveLight = NSBezierPath(roundedRect: grooveRect.offsetBy(dx: 0, dy: -1.2), xRadius: 15, yRadius: 15)
        NSColor.white.withAlphaComponent(0.55).setStroke()
        grooveLight.lineWidth = 1
        grooveLight.stroke()
        let groove = NSBezierPath(roundedRect: grooveRect, xRadius: 15, yRadius: 15)
        NSColor.black.withAlphaComponent(0.2).setStroke()
        groove.lineWidth = 1.2
        groove.stroke()
        NSGraphicsContext.restoreGraphicsState()

        let logoShadow = NSShadow()
        logoShadow.shadowColor = PixelStyle.raspberry.blended(withFraction: 0.4, of: .black)?.withAlphaComponent(0.9) ?? .black
        logoShadow.shadowOffset = NSSize(width: 0, height: -1.8)
        logoShadow.shadowBlurRadius = 1
        let logo = NSAttributedString(string: "MAXWELL", attributes: [
            .font: PixelStyle.logoFont(23),
            .foregroundColor: NSColor.white,
            .kern: 1.5,
            .shadow: logoShadow
        ])
        logo.draw(at: NSPoint(x: body.minX + 34, y: bandY + 28))
        let model = NSAttributedString(string: "MXW-Y2K · PERSONAL EDITION", attributes: [
            .font: PixelStyle.font(7.5, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85),
            .kern: 1.4
        ])
        model.draw(at: NSPoint(x: body.minX + 37, y: bandY + 13))

        PixelStyle.drawSpeakerGrille(in: NSRect(x: body.minX + 18, y: body.minY + 34, width: 122, height: 192))

        let footer = NSAttributedString(string: "♥ MECHANICAL JESTER ♥", attributes: [
            .font: PixelStyle.font(8, weight: .semibold),
            .foregroundColor: PixelStyle.ink.withAlphaComponent(0.5),
            .kern: 2
        ])
        let footerSize = footer.size()
        footer.draw(at: NSPoint(x: body.minX + 170, y: body.minY + 30 - footerSize.height / 2))

        let inset: CGFloat = 22
        PixelStyle.drawScrew(at: NSPoint(x: body.minX + inset, y: body.minY + inset), radius: 4.5)
        PixelStyle.drawScrew(at: NSPoint(x: body.maxX - inset, y: body.minY + inset), radius: 4.5)
        PixelStyle.drawScrew(at: NSPoint(x: body.minX + inset, y: body.maxY - inset), radius: 4.5)
        PixelStyle.drawScrew(at: NSPoint(x: body.maxX - inset, y: body.maxY - inset), radius: 4.5)
    }

    override func draw(_ dirtyRect: NSRect) {
        if PixelStyle.isChrome {
            drawChromePanel()
            return
        }
        let u = PixelStyle.unit
        let body = PixelPanelView.bodyRect

        PixelStyle.plum.withAlphaComponent(0.3).setFill()
        panelSilhouette(body: body.offsetBy(dx: 2 * u, dy: -2 * u)).fill()

        PixelStyle.plum.setFill()
        panelSilhouette(body: body).fill()

        let inner = body.insetBy(dx: u, dy: u)
        PixelStyle.cream.setFill()
        PixelStyle.steppedPath(in: inner, step: u).fill()

        NSGraphicsContext.saveGraphicsState()
        PixelStyle.steppedPath(in: inner, step: u).addClip()
        let bandY = body.maxY - PixelPanelView.headerHeight
        PixelStyle.blush.setFill()
        NSRect(x: inner.minX, y: bandY, width: inner.width, height: PixelPanelView.headerHeight).fill()
        PixelStyle.raspberry.setFill()
        NSRect(x: inner.minX, y: bandY, width: inner.width, height: u).fill()
        NSGraphicsContext.restoreGraphicsState()

        let innerHeights = ([1, 3, 5, 7, 7, 5, 3, 1] as [CGFloat]).map { $0 * u }
        let accentHeights = ([1, 3, 4, 4, 3, 1] as [CGFloat]).map { $0 * u }
        for centerX in earCenters(body: body) {
            PixelStyle.blush.setFill()
            earPath(centerX: centerX, baseY: body.maxY - 2 * u, columnWidth: 2 * u, heights: innerHeights).fill()
            PixelStyle.bubblegum.setFill()
            earPath(centerX: centerX, baseY: body.maxY - 2 * u, columnWidth: u, heights: accentHeights).fill()
        }
    }
}

class SparkleField: NSView {
    private var configured = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !configured else { return }
        configured = true
        wantsLayer = true

        let spots: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double, color: NSColor)] = [
            (0.06, 0.94, 12, 0.0, PixelStyle.bubblegum),
            (0.27, 0.98, 8, 0.7, PixelStyle.raspberry),
            (0.56, 0.96, 9, 1.3, PixelStyle.bubblegum),
            (0.66, 0.90, 7, 0.4, PixelStyle.raspberry),
            (0.015, 0.55, 9, 1.8, PixelStyle.bubblegum),
            (0.985, 0.42, 8, 1.1, PixelStyle.bubblegum)
        ]

        for spot in spots {
            let sparkle = CALayer()
            sparkle.contents = PixelStyle.isChrome
                ? PixelStyle.glowDotImage(size: spot.size + 4, color: spot.color)
                : PixelStyle.sparkleImage(size: spot.size, color: spot.color)
            sparkle.frame = CGRect(x: bounds.width * spot.x, y: bounds.height * spot.y, width: spot.size, height: spot.size)
            sparkle.opacity = 0.2
            layer?.addSublayer(sparkle)

            let twinkle = CABasicAnimation(keyPath: "opacity")
            twinkle.fromValue = 0.15
            twinkle.toValue = 1.0
            twinkle.duration = 1.2
            twinkle.autoreverses = true
            twinkle.repeatCount = .infinity
            twinkle.beginTime = CACurrentMediaTime() + spot.delay
            sparkle.add(twinkle, forKey: "twinkle")

            let breathe = CABasicAnimation(keyPath: "transform.scale")
            breathe.fromValue = 0.6
            breathe.toValue = 1.1
            breathe.duration = 1.2
            breathe.autoreverses = true
            breathe.repeatCount = .infinity
            breathe.beginTime = CACurrentMediaTime() + spot.delay
            sparkle.add(breathe, forKey: "breathe")
        }
    }
}

class PixelButton: NSControl {
    var title: String { didSet { needsDisplay = true } }
    var faceColor: NSColor = PixelStyle.bubblegum { didSet { needsDisplay = true } }
    var titleColor: NSColor = .white { didSet { needsDisplay = true } }
    var fontSize: CGFloat = 11
    private var isPressed = false { didSet { needsDisplay = true } }
    private var isHovered = false { didSet { needsDisplay = true } }
    private var trackingArea: NSTrackingArea?

    init(title: String, frame: NSRect) {
        self.title = title
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSCursor.pointingHand.set()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
    }

    override func mouseDragged(with event: NSEvent) {
        isPressed = bounds.contains(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)), let action = action {
            _ = NSApp.sendAction(action, to: target, from: self)
        }
        isPressed = false
    }

    override func draw(_ dirtyRect: NSRect) {
        if PixelStyle.isChrome {
            let rect = bounds.insetBy(dx: 1, dy: 1)
            PixelStyle.drawChromeFace(in: rect, base: faceColor, pressed: isPressed, hovered: isHovered)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: PixelStyle.font(fontSize),
                .foregroundColor: titleColor,
                .kern: 0.8
            ]
            let text = NSAttributedString(string: title, attributes: attributes)
            let size = text.size()
            let offset: CGFloat = isPressed ? -1 : 0
            text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2 + offset))
            return
        }
        let u = PixelStyle.unit
        let raised = NSRect(x: 0, y: u, width: bounds.width, height: bounds.height - u)
        let faceRect = isPressed ? raised.offsetBy(dx: 0, dy: -u) : raised
        if !isPressed {
            PixelStyle.plum.setFill()
            PixelStyle.steppedPath(in: raised.offsetBy(dx: 0, dy: -u), step: u).fill()
        }
        PixelStyle.plum.setFill()
        PixelStyle.steppedPath(in: faceRect, step: u).fill()
        var fill = faceColor
        if isHovered && !isPressed {
            fill = faceColor.blended(withFraction: 0.15, of: .white) ?? faceColor
        }
        fill.setFill()
        PixelStyle.steppedPath(in: faceRect.insetBy(dx: u, dy: u), step: u).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: PixelStyle.font(fontSize),
            .foregroundColor: titleColor,
            .kern: 1.2
        ]
        let text = NSAttributedString(string: title, attributes: attributes)
        let size = text.size()
        text.draw(at: NSPoint(x: faceRect.midX - size.width / 2, y: faceRect.midY - size.height / 2))
    }
}

class PixelTabButton: NSControl {
    let icon: String
    let title: String
    var isSelected = false { didSet { needsDisplay = true } }
    var fontSize: CGFloat = 11
    var centersTitle = false
    private var isHovered = false { didSet { needsDisplay = true } }
    private var trackingArea: NSTrackingArea?

    init(icon: String, title: String, frame: NSRect) {
        self.icon = icon
        self.title = title
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSCursor.pointingHand.set()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
    }

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)), let action = action {
            _ = NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if PixelStyle.isChrome {
            let rect = bounds.insetBy(dx: 1, dy: 1)
            PixelStyle.drawChromeFace(
                in: rect,
                base: isSelected ? PixelStyle.bubblegum : PixelStyle.blush,
                pressed: isSelected,
                hovered: isHovered)
            if !centersTitle {
                let ledCenter = NSPoint(x: rect.minX + 11, y: rect.midY)
                let ledRect = NSRect(x: ledCenter.x - 3, y: ledCenter.y - 3, width: 6, height: 6)
                let led = NSBezierPath(ovalIn: ledRect)
                if isSelected {
                    NSGraphicsContext.saveGraphicsState()
                    let glow = NSShadow()
                    glow.shadowColor = PixelStyle.fieldText.withAlphaComponent(0.95)
                    glow.shadowBlurRadius = 5
                    glow.shadowOffset = .zero
                    glow.set()
                    PixelStyle.fieldText.setFill()
                    led.fill()
                    NSGraphicsContext.restoreGraphicsState()
                } else {
                    PixelStyle.plum.withAlphaComponent(0.35).setFill()
                    led.fill()
                }
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: PixelStyle.font(fontSize),
                .foregroundColor: isSelected ? NSColor.white : PixelStyle.ink,
                .kern: 0.8
            ]
            let text = NSAttributedString(string: "\(icon) \(title)", attributes: attributes)
            let size = text.size()
            let x = centersTitle ? rect.midX - size.width / 2 : rect.minX + 20
            text.draw(at: NSPoint(x: x, y: rect.midY - size.height / 2 + (isSelected ? -1 : 0)))
            return
        }
        let u = PixelStyle.unit
        if isSelected {
            PixelStyle.plum.setFill()
            PixelStyle.steppedPath(in: bounds, step: u).fill()
            PixelStyle.bubblegum.setFill()
            PixelStyle.steppedPath(in: bounds.insetBy(dx: u, dy: u), step: u).fill()
        } else if isHovered {
            PixelStyle.blush.setFill()
            PixelStyle.steppedPath(in: bounds, step: u).fill()
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: PixelStyle.font(fontSize),
            .foregroundColor: isSelected ? NSColor.white : PixelStyle.raspberry,
            .kern: 1.2
        ]
        let text = NSAttributedString(string: "\(icon) \(title)", attributes: attributes)
        let size = text.size()
        let x = centersTitle ? bounds.midX - size.width / 2 : 14
        text.draw(at: NSPoint(x: x, y: bounds.midY - size.height / 2))
    }
}

class PixelCheckbox: NSControl {
    var isChecked = false { didSet { needsDisplay = true } }
    let title: String
    private var trackingArea: NSTrackingArea?

    init(title: String, frame: NSRect) {
        self.title = title
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
    }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        isChecked.toggle()
        pop()
        if let action = action {
            _ = NSApp.sendAction(action, to: target, from: self)
        }
    }

    private func pop() {
        guard let layer = layer else { return }
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: frame.midX, y: frame.midY)
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1.0, 1.12, 1.0]
        pop.keyTimes = [0, 0.4, 1]
        pop.duration = 0.22
        layer.add(pop, forKey: "pop")
    }

    override func draw(_ dirtyRect: NSRect) {
        let boxSize: CGFloat = 18
        let box = NSRect(x: 0, y: (bounds.height - boxSize) / 2, width: boxSize, height: boxSize)
        if PixelStyle.isChrome {
            PixelStyle.drawWell(in: box, radius: 4)
            if isChecked {
                NSGraphicsContext.saveGraphicsState()
                let glow = NSShadow()
                glow.shadowColor = PixelStyle.fieldText.withAlphaComponent(0.9)
                glow.shadowBlurRadius = 6
                glow.shadowOffset = .zero
                glow.set()
                PixelStyle.bubblegum.setFill()
                PixelStyle.smoothHeartPath(in: box.insetBy(dx: 4, dy: 4)).fill()
                NSGraphicsContext.restoreGraphicsState()
                NSColor.white.withAlphaComponent(0.7).setFill()
                NSBezierPath(ovalIn: NSRect(x: box.minX + 5.5, y: box.midY + 1.5, width: 3.2, height: 2.2)).fill()
            }
        } else {
            PixelStyle.plum.setFill()
            PixelStyle.steppedPath(in: box, step: 2).fill()
            PixelStyle.field.setFill()
            PixelStyle.steppedPath(in: box.insetBy(dx: 2, dy: 2), step: 2).fill()
            if isChecked {
                PixelStyle.bubblegum.setFill()
                PixelStyle.heartPath(in: box.insetBy(dx: 3, dy: 3)).fill()
            }
        }
        if !title.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: PixelStyle.font(11, weight: .semibold),
                .foregroundColor: PixelStyle.ink,
                .kern: 0.8
            ]
            let text = NSAttributedString(string: title, attributes: attributes)
            let size = text.size()
            text.draw(at: NSPoint(x: boxSize + 10, y: bounds.midY - size.height / 2))
        }
    }
}

class PixelSliderCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let fraction = CGFloat((doubleValue - minValue) / (maxValue - minValue))
        if PixelStyle.isChrome {
            let track = NSRect(x: rect.minX, y: rect.midY - 3, width: rect.width, height: 6)
            PixelStyle.drawWell(in: track, radius: 3)
            if fraction > 0.02 {
                let lit = NSRect(x: track.minX + 1.5, y: track.minY + 1.5, width: (track.width - 3) * fraction, height: track.height - 3)
                NSGraphicsContext.saveGraphicsState()
                let glow = NSShadow()
                glow.shadowColor = PixelStyle.fieldText.withAlphaComponent(0.8)
                glow.shadowBlurRadius = 4
                glow.shadowOffset = .zero
                glow.set()
                PixelStyle.bubblegum.setFill()
                NSBezierPath(roundedRect: lit, xRadius: 1.5, yRadius: 1.5).fill()
                NSGraphicsContext.restoreGraphicsState()
            }
            return
        }
        let track = NSRect(x: rect.minX, y: rect.midY - 4, width: rect.width, height: 8)
        PixelStyle.plum.setFill()
        track.fill()
        PixelStyle.field.setFill()
        track.insetBy(dx: 2, dy: 2).fill()
        PixelStyle.bubblegum.setFill()
        NSRect(x: track.minX + 2, y: track.minY + 2, width: (track.width - 4) * fraction, height: track.height - 4).fill()
    }

    override func drawKnob(_ knobRect: NSRect) {
        if PixelStyle.isChrome {
            let d = min(knobRect.width, knobRect.height) - 2
            let circleRect = NSRect(x: knobRect.midX - d / 2, y: knobRect.midY - d / 2, width: d, height: d)
            let circle = NSBezierPath(ovalIn: circleRect)
            let flipped = controlView?.isFlipped ?? false

            NSGraphicsContext.saveGraphicsState()
            let drop = NSShadow()
            drop.shadowColor = NSColor.black.withAlphaComponent(0.4)
            drop.shadowOffset = NSSize(width: 0, height: flipped ? 1.5 : -1.5)
            drop.shadowBlurRadius = 2.5
            drop.set()
            PixelStyle.plum.setFill()
            circle.fill()
            NSGraphicsContext.restoreGraphicsState()

            let light = PixelStyle.cream.blended(withFraction: 0.75, of: .white) ?? PixelStyle.cream
            let dark = PixelStyle.cream.blended(withFraction: 0.28, of: .black) ?? PixelStyle.cream
            NSGradient(colors: [light, dark])?.draw(in: circle, angle: flipped ? 90 : -90)
            PixelStyle.plum.withAlphaComponent(0.7).setStroke()
            circle.lineWidth = 1
            circle.stroke()

            for i in 0..<12 {
                let angle = CGFloat(i) * .pi / 6
                let ridge = NSBezierPath()
                ridge.move(to: NSPoint(
                    x: circleRect.midX + cos(angle) * d * 0.3,
                    y: circleRect.midY + sin(angle) * d * 0.3))
                ridge.line(to: NSPoint(
                    x: circleRect.midX + cos(angle) * d * 0.46,
                    y: circleRect.midY + sin(angle) * d * 0.46))
                NSColor.black.withAlphaComponent(0.22).setStroke()
                ridge.lineWidth = 1.3
                ridge.stroke()
            }

            let heartRect = circleRect.insetBy(dx: d * 0.31, dy: d * 0.33)
            NSGraphicsContext.saveGraphicsState()
            if flipped {
                let transform = NSAffineTransform()
                transform.translateX(by: 0, yBy: heartRect.midY * 2)
                transform.scaleX(by: 1, yBy: -1)
                transform.concat()
            }
            PixelStyle.raspberry.setFill()
            PixelStyle.smoothHeartPath(in: heartRect).fill()
            NSGraphicsContext.restoreGraphicsState()
            return
        }
        let width = min(knobRect.width - 2, (knobRect.height - 2) * 7 / 6)
        let height = width * 6 / 7
        let heartRect = NSRect(
            x: knobRect.midX - width / 2,
            y: knobRect.midY - height / 2,
            width: width,
            height: height)
        PixelStyle.raspberry.setFill()
        PixelStyle.heartPath(in: heartRect, flipped: controlView?.isFlipped ?? false).fill()
    }
}

class PixelSlider: NSSlider {
    override class var cellClass: AnyClass? {
        get { PixelSliderCell.self }
        set {}
    }
}

class SevenSegmentView: NSView {
    var text: String = "" { didSet { needsDisplay = true } }

    private let segmentMap: [Character: [Int]] = [
        "0": [0, 1, 2, 3, 4, 5],
        "1": [1, 2],
        "2": [0, 1, 6, 4, 3],
        "3": [0, 1, 6, 2, 3],
        "4": [5, 6, 1, 2],
        "5": [0, 5, 6, 2, 3],
        "6": [0, 5, 6, 4, 2, 3],
        "7": [0, 1, 2],
        "8": [0, 1, 2, 3, 4, 5, 6],
        "9": [0, 1, 2, 3, 5, 6]
    ]

    override func draw(_ dirtyRect: NSRect) {
        let screen = PixelStyle.drawLCDBezel(in: bounds)
        var x = screen.minX + 6
        let top = screen.maxY - 4
        let bottom = screen.minY + 4
        let digitW: CGFloat = 10
        for ch in text {
            if let lit = segmentMap[ch] {
                drawDigit(lit, x: x, top: top, bottom: bottom, width: digitW)
                x += digitW + 5
            } else if ch == "." {
                drawGlowing {
                    NSRect(x: x + 0.5, y: bottom, width: 3, height: 3).fill()
                }
                x += 6.5
            } else {
                let text = NSAttributedString(string: String(ch), attributes: PixelStyle.lcdAttributes(size: 11))
                text.draw(at: NSPoint(x: x, y: bottom - 2))
                x += text.size().width + 2
            }
        }
    }

    private func drawGlowing(_ fill: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = PixelStyle.fieldText.withAlphaComponent(0.9)
        glow.shadowBlurRadius = 4
        glow.shadowOffset = .zero
        glow.set()
        PixelStyle.fieldText.setFill()
        fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawDigit(_ lit: [Int], x: CGFloat, top: CGFloat, bottom: CGFloat, width: CGFloat) {
        let midY = (top + bottom) / 2
        let t: CGFloat = 2
        let segments: [NSRect] = [
            NSRect(x: x + 1, y: top - t, width: width - 2, height: t),
            NSRect(x: x + width - t, y: midY + 1, width: t, height: top - midY - 2),
            NSRect(x: x + width - t, y: bottom + 1, width: t, height: midY - bottom - 2),
            NSRect(x: x + 1, y: bottom, width: width - 2, height: t),
            NSRect(x: x, y: bottom + 1, width: t, height: midY - bottom - 2),
            NSRect(x: x, y: midY + 1, width: t, height: top - midY - 2),
            NSRect(x: x + 1, y: midY - t / 2, width: width - 2, height: t)
        ]
        for (index, segment) in segments.enumerated() {
            if lit.contains(index) {
                drawGlowing {
                    segment.fill()
                }
            } else {
                PixelStyle.fieldText.withAlphaComponent(0.1).setFill()
                segment.fill()
            }
        }
    }
}

class PixelBox: NSView {
    override func draw(_ dirtyRect: NSRect) {
        if PixelStyle.isChrome {
            PixelStyle.drawLCDBezel(in: bounds.insetBy(dx: 1, dy: 1))
            return
        }
        let u = PixelStyle.unit
        PixelStyle.raspberry.setFill()
        PixelStyle.steppedPath(in: bounds, step: u).fill()
        PixelStyle.field.setFill()
        PixelStyle.steppedPath(in: bounds.insetBy(dx: u, dy: u), step: u).fill()
    }
}

class PixelTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        if PixelStyle.isChrome {
            PixelStyle.bubblegum.withAlphaComponent(0.22).setFill()
        } else {
            PixelStyle.blush.setFill()
        }
        bounds.fill()
    }
}

class ThemeTileView: NSView {
    let themeFileName: String
    var onSelect: (() -> Void)?
    var isSelected: Bool {
        didSet {
            needsDisplay = true
            if isSelected && !oldValue {
                wiggle()
            }
        }
    }
    private let previewView: AnimatedGIFView

    init(frame frameRect: NSRect, url: URL, isSelected: Bool) {
        self.themeFileName = url.lastPathComponent
        self.isSelected = isSelected
        self.previewView = AnimatedGIFView(
            frame: NSRect(x: 8, y: 24, width: frameRect.width - 16, height: frameRect.height - 32))
        super.init(frame: frameRect)
        wantsLayer = true

        previewView.draggable = false
        previewView.speed = 1.0
        previewView.onClick = { [weak self] in self?.onSelect?() }
        addSubview(previewView)
        previewView.loadGIF(from: url)

        let nameLabel = NSTextField(labelWithString: ThemeManager.displayName(for: url))
        nameLabel.font = PixelStyle.font(9, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.textColor = PixelStyle.isChrome ? PixelStyle.fieldText : PixelStyle.ink
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.frame = NSRect(x: 2, y: 5, width: frameRect.width - 4, height: 14)
        addSubview(nameLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 2, dy: 2)
        if PixelStyle.isChrome {
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
            if isSelected {
                NSGraphicsContext.saveGraphicsState()
                let glow = NSShadow()
                glow.shadowColor = PixelStyle.bubblegum.withAlphaComponent(0.9)
                glow.shadowBlurRadius = 8
                glow.shadowOffset = .zero
                glow.set()
                PixelStyle.bubblegum.withAlphaComponent(0.25).setFill()
                path.fill()
                NSGraphicsContext.restoreGraphicsState()
                PixelStyle.bubblegum.setStroke()
                path.lineWidth = 2
                path.stroke()
            } else {
                NSColor.white.withAlphaComponent(0.06).setFill()
                path.fill()
                NSColor.white.withAlphaComponent(0.16).setStroke()
                path.lineWidth = 1
                path.stroke()
            }
            return
        }
        if isSelected {
            PixelStyle.raspberry.setFill()
            PixelStyle.steppedPath(in: rect, step: 2).fill()
            PixelStyle.blush.setFill()
            PixelStyle.steppedPath(in: rect.insetBy(dx: 3, dy: 3), step: 2).fill()
        } else {
            PixelStyle.blush.setFill()
            PixelStyle.steppedPath(in: rect, step: 2).fill()
            PixelStyle.cream.setFill()
            PixelStyle.steppedPath(in: rect.insetBy(dx: 2, dy: 2), step: 2).fill()
        }
    }

    private func wiggle() {
        guard let layer = layer else { return }
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: frame.midX, y: frame.midY)
        let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wiggle.values = [0, 0.06, -0.06, 0.04, 0]
        wiggle.duration = 0.3
        layer.add(wiggle, forKey: "wiggle")
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
    }
}

class SettingsWindowController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    var window: NSWindow?
    var tableView: NSTableView!
    var config: MaxwellConfig
    var onConfigChanged: (() -> Void)?
    var speedSlider: PixelSlider!
    var speedLabel: NSTextField!
    var showDoneBubblesCheckbox: PixelCheckbox!
    weak var anchorWindow: NSWindow?

    private var speedLCD: SevenSegmentView?
    private var lcdStrip: LCDStripView?

    private var stageView: NSView!
    private var tabButtons: [PixelTabButton] = []
    private var styleChips: [PixelTabButton] = []
    private var saveButton: PixelButton!
    private var contentContainerView: NSView!
    private var sshContentView: NSView!
    private var othersContentView: NSView!
    private var themeContentView: NSView!
    private var themeGridDocView: FlippedView!
    private var messageField: NSTextField!
    private var themeTiles: [ThemeTileView] = []
    private var displayedStyle = MaxwellConfig.defaultSettingsStyle
    private let tabs: [(icon: String, title: String)] = [("✦", "SSH"), ("★", "EXTRAS"), ("✿", "THEME")]

    override init() {
        config = MaxwellConfig.load()
        super.init()
    }

    func show() {
        config = MaxwellConfig.load()
        PixelStyle.apply(styleId: config.settingsStyle)
        if window == nil {
            setupWindow()
        } else if displayedStyle != config.settingsStyle {
            installContent()
        }
        refreshControls()
        positionWindow()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        animateAppear()
    }

    private func positionWindow() {
        guard let w = window else { return }
        guard let anchor = anchorWindow, let screen = anchor.screen ?? NSScreen.main else {
            w.center()
            return
        }
        let anchorFrame = anchor.frame
        let visible = screen.visibleFrame
        let size = w.frame.size
        let body = PixelPanelView.bodyRect
        let gap: CGFloat = 6

        var x: CGFloat
        if anchorFrame.midX > visible.midX {
            x = anchorFrame.maxX - body.maxX
        } else {
            x = anchorFrame.minX - body.minX
        }
        x = max(visible.minX - body.minX, min(x, visible.maxX - body.maxX))

        var y = anchorFrame.maxY + gap - body.minY
        if y + size.height > visible.maxY + (size.height - body.maxY) {
            y = anchorFrame.minY - gap - body.maxY - 40
        }
        y = max(visible.minY - body.minY, min(y, visible.maxY - size.height))

        w.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func refreshControls() {
        tableView.reloadData()
        updateSpeedUI()
        updateDoneBubblesUI()
        updateStyleChips()
        messageField?.stringValue = config.clickMessage
        populateThemeGrid()
    }

    private func updateStyleChips() {
        for (index, chip) in styleChips.enumerated() {
            chip.isSelected = PixelStyle.styles[index].id == config.settingsStyle
        }
    }

    @objc private func styleClicked(_ sender: PixelTabButton) {
        let styleId = PixelStyle.styles[sender.tag].id
        guard config.settingsStyle != styleId else { return }
        config.settingsStyle = styleId
        persist { $0.settingsStyle = styleId }
        PixelStyle.apply(styleId: styleId)
        installContent()
        refreshControls()
        selectTab(2, animated: false)
        animateAppear()
    }

    private func animateAppear() {
        guard let layer = stageView?.layer else { return }
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: stageView.frame.midX, y: stageView.frame.midY)
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [0.85, 1.04, 1.0]
        pop.keyTimes = [0, 0.6, 1]
        pop.duration = 0.3
        pop.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.18
        layer.add(pop, forKey: "pop")
        layer.add(fade, forKey: "fade")
    }

    @objc private func closeWindow() {
        window?.close()
    }

    @objc private func tabClicked(_ sender: PixelTabButton) {
        selectTab(sender.tag, animated: true)
    }

    private func selectTab(_ index: Int, animated: Bool) {
        for (i, tab) in tabButtons.enumerated() {
            tab.isSelected = i == index
        }
        lcdStrip?.text = "▶ \(tabs[index].title)"
        let panes = [sshContentView, othersContentView, themeContentView]
        for (i, pane) in panes.enumerated() {
            pane?.isHidden = i != index
        }
        guard animated, let shown = panes[index] else { return }
        let target = shown.frame.origin
        shown.alphaValue = 0
        shown.setFrameOrigin(NSPoint(x: target.x + 12, y: target.y))
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            shown.animator().alphaValue = 1
            shown.animator().setFrameOrigin(target)
        }
    }

    private func setupWindow() {
        let contentSize = NSSize(width: 622, height: 524)
        let w = KeyableWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.isReleasedWhenClosed = false
        window = w
        installContent()
    }

    private func installContent() {
        guard let w = window else { return }
        displayedStyle = config.settingsStyle
        tabButtons = []
        styleChips = []
        themeTiles = []

        let root = NSView(frame: NSRect(origin: .zero, size: w.frame.size))
        stageView = NSView(frame: root.bounds)
        stageView.wantsLayer = true
        root.addSubview(stageView)

        let panel = PixelPanelView(frame: root.bounds)
        stageView.addSubview(panel)

        let body = PixelPanelView.bodyRect
        let headerHeight = PixelPanelView.headerHeight

        if PixelStyle.isChrome {
            lcdStrip = nil
            let strip = LCDStripView(frame: NSRect(x: body.minX + 218, y: body.maxY - headerHeight + 15, width: 290, height: 38))
            strip.showsEQ = true
            strip.text = "▶ \(tabs[0].title)"
            lcdStrip = strip
            panel.addSubview(strip)

            let closeButton = PixelButton(title: "✕", frame: NSRect(x: body.maxX - 62, y: body.maxY - headerHeight / 2 - 16, width: 32, height: 32))
            closeButton.faceColor = PixelStyle.blush
            closeButton.titleColor = PixelStyle.ink
            closeButton.target = self
            closeButton.action = #selector(closeWindow)
            panel.addSubview(closeButton)
        } else {
            lcdStrip = nil
            let title = NSTextField(labelWithString: "")
            title.attributedStringValue = NSAttributedString(
                string: "♥ MAXWELL SETTINGS",
                attributes: [
                    .font: PixelStyle.font(13),
                    .foregroundColor: PixelStyle.ink,
                    .kern: 2.5
                ])
            title.sizeToFit()
            title.setFrameOrigin(NSPoint(x: body.minX + 22, y: body.maxY - headerHeight / 2 - title.frame.height / 2))
            panel.addSubview(title)

            let closeButton = PixelButton(title: "✕", frame: NSRect(x: body.maxX - 46, y: body.maxY - headerHeight / 2 - 14, width: 30, height: 28))
            closeButton.faceColor = PixelStyle.blush
            closeButton.titleColor = PixelStyle.ink
            closeButton.target = self
            closeButton.action = #selector(closeWindow)
            panel.addSubview(closeButton)
        }

        let tabItems: [(icon: String, title: String)] = PixelStyle.isChrome
            ? [("⇄", "SSH"), ("♪", "EXTRAS"), ("◈", "THEME")]
            : tabs
        for (index, item) in tabItems.enumerated() {
            let y = body.maxY - headerHeight - 46 - CGFloat(index) * 38
            let tab = PixelTabButton(icon: item.icon, title: item.title, frame: NSRect(x: body.minX + 16, y: y, width: 120, height: 30))
            tab.tag = index
            tab.target = self
            tab.action = #selector(tabClicked(_:))
            panel.addSubview(tab)
            tabButtons.append(tab)
        }

        contentContainerView = NSView(frame: NSRect(x: body.minX + 152, y: body.minY + 62, width: body.width - 152 - 16, height: body.height - headerHeight - 62 - 12))
        panel.addSubview(contentContainerView)

        setupSSHContent()
        setupOthersContent()
        setupThemeContent()

        let saveMargin: CGFloat = PixelStyle.isChrome ? 34 : 16
        saveButton = PixelButton(title: "SAVE ♥", frame: NSRect(x: body.maxX - saveMargin - 122, y: body.minY + 14, width: 122, height: 36))
        saveButton.fontSize = 12
        saveButton.target = self
        saveButton.action = #selector(saveConfig)
        panel.addSubview(saveButton)

        let sparkles = SparkleField(frame: root.bounds)
        stageView.addSubview(sparkles)

        w.contentView = root

        selectTab(0, animated: false)
    }

    private func setupSSHContent() {
        sshContentView = NSView(frame: contentContainerView.bounds)
        contentContainerView.addSubview(sshContentView)
        let size = sshContentView.bounds.size

        let caption = PixelStyle.caption("✦ REMOTE SSH SERVERS")
        caption.setFrameOrigin(NSPoint(x: 0, y: size.height - caption.frame.height - 2))
        sshContentView.addSubview(caption)

        let columns: [(id: String, title: String, width: CGFloat)] = [
            ("name", "NAME", 56),
            ("host", "HOST", 104),
            ("user", "USER", 76),
            ("keyPath", "KEY", 102),
            ("enabled", "ON", 26)
        ]

        var headerX: CGFloat = 10
        for column in columns {
            let header = PixelStyle.label(column.title, size: 9, color: PixelStyle.raspberry.withAlphaComponent(0.75))
            header.sizeToFit()
            header.setFrameOrigin(NSPoint(x: headerX, y: size.height - 42))
            sshContentView.addSubview(header)
            headerX += column.width + 4
        }

        let box = PixelBox(frame: NSRect(x: 0, y: 52, width: size.width, height: size.height - 100))
        sshContentView.addSubview(box)

        let scrollView = NSScrollView(frame: box.bounds.insetBy(dx: 6, dy: 6))
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 26
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 4, height: 4)

        for column in columns {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.id))
            col.width = column.width
            tableView.addTableColumn(col)
        }

        scrollView.documentView = tableView
        box.addSubview(scrollView)

        let buttons: [(String, Selector)] = [
            ("ADD", #selector(addRemote)),
            ("REMOVE", #selector(removeRemote)),
            ("TEST", #selector(testSSH))
        ]
        var buttonX: CGFloat = 0
        for (buttonTitle, action) in buttons {
            let button = PixelButton(title: buttonTitle, frame: NSRect(x: buttonX, y: 8, width: 92, height: 30))
            button.faceColor = PixelStyle.blush
            button.titleColor = PixelStyle.ink
            button.target = self
            button.action = action
            sshContentView.addSubview(button)
            buttonX += 100
        }
    }

    private func setupOthersContent() {
        othersContentView = NSView(frame: contentContainerView.bounds)
        contentContainerView.addSubview(othersContentView)
        let size = othersContentView.bounds.size

        let animCaption = PixelStyle.caption("★ ANIMATION")
        animCaption.setFrameOrigin(NSPoint(x: 0, y: size.height - animCaption.frame.height - 2))
        othersContentView.addSubview(animCaption)

        let speedTitle = PixelStyle.label("SPEED", size: 11, color: PixelStyle.ink)
        speedTitle.sizeToFit()
        speedTitle.setFrameOrigin(NSPoint(x: 0, y: size.height - 56))
        othersContentView.addSubview(speedTitle)

        speedSlider = PixelSlider(frame: NSRect(x: 64, y: size.height - 62, width: 210, height: 26))
        speedSlider.minValue = 0.25
        speedSlider.maxValue = 3.0
        speedSlider.doubleValue = config.gifSpeed
        speedSlider.target = self
        speedSlider.action = #selector(speedSliderChanged(_:))
        othersContentView.addSubview(speedSlider)

        if PixelStyle.isChrome {
            speedLabel = nil
            let lcd = SevenSegmentView(frame: NSRect(x: 286, y: size.height - 66, width: 88, height: 32))
            lcd.text = formatSpeed(config.gifSpeed)
            speedLCD = lcd
            othersContentView.addSubview(lcd)
        } else {
            speedLCD = nil
            speedLabel = NSTextField(labelWithString: formatSpeed(config.gifSpeed))
            speedLabel.font = PixelStyle.font(12)
            speedLabel.textColor = PixelStyle.raspberry
            speedLabel.frame = NSRect(x: 286, y: size.height - 58, width: 70, height: 18)
            othersContentView.addSubview(speedLabel)
        }

        let slowLabel = PixelStyle.label("SLOW", size: 9, color: PixelStyle.raspberry.withAlphaComponent(0.75))
        slowLabel.sizeToFit()
        slowLabel.setFrameOrigin(NSPoint(x: 64, y: size.height - 80))
        othersContentView.addSubview(slowLabel)

        let fastLabel = PixelStyle.label("FAST", size: 9, color: PixelStyle.raspberry.withAlphaComponent(0.75))
        fastLabel.sizeToFit()
        fastLabel.setFrameOrigin(NSPoint(x: 246, y: size.height - 80))
        othersContentView.addSubview(fastLabel)

        let resetButton = PixelButton(title: "RESET 1×", frame: NSRect(x: 0, y: size.height - 124, width: 112, height: 30))
        resetButton.faceColor = PixelStyle.blush
        resetButton.titleColor = PixelStyle.ink
        resetButton.target = self
        resetButton.action = #selector(resetSpeed)
        othersContentView.addSubview(resetButton)

        let notifCaption = PixelStyle.caption("★ NOTIFICATIONS")
        notifCaption.setFrameOrigin(NSPoint(x: 0, y: size.height - 158 - notifCaption.frame.height))
        othersContentView.addSubview(notifCaption)

        showDoneBubblesCheckbox = PixelCheckbox(title: "SHOW DONE BUBBLES", frame: NSRect(x: 0, y: size.height - 210, width: 320, height: 22))
        showDoneBubblesCheckbox.isChecked = config.showDoneBubbles
        showDoneBubblesCheckbox.target = self
        showDoneBubblesCheckbox.action = #selector(doneBubblesChanged(_:))
        othersContentView.addSubview(showDoneBubblesCheckbox)
    }

    private func setupThemeContent() {
        themeContentView = NSView(frame: contentContainerView.bounds)
        contentContainerView.addSubview(themeContentView)
        let size = themeContentView.bounds.size

        let msgLabel = PixelStyle.label("MESSAGE ON CLICK", size: 11, color: PixelStyle.ink)
        msgLabel.sizeToFit()
        msgLabel.setFrameOrigin(NSPoint(x: 0, y: size.height - 20))
        themeContentView.addSubview(msgLabel)

        messageField = NSTextField(frame: NSRect(x: 158, y: size.height - 26, width: size.width - 158, height: 26))
        messageField.stringValue = config.clickMessage
        messageField.placeholderString = MaxwellConfig.defaultClickMessage
        messageField.identifier = NSUserInterfaceItemIdentifier("clickMessage")
        messageField.delegate = self
        PixelStyle.styleField(messageField)
        themeContentView.addSubview(messageField)

        let styleLabel = PixelStyle.label("WINDOW STYLE", size: 11, color: PixelStyle.ink)
        styleLabel.sizeToFit()
        styleLabel.setFrameOrigin(NSPoint(x: 0, y: size.height - 58))
        themeContentView.addSubview(styleLabel)

        for (index, style) in PixelStyle.styles.enumerated() {
            let chip = PixelTabButton(icon: style.icon, title: style.title, frame: NSRect(x: 158 + CGFloat(index) * 94, y: size.height - 64, width: 90, height: 26))
            chip.tag = index
            chip.fontSize = 10
            chip.centersTitle = true
            chip.isSelected = style.id == config.settingsStyle
            chip.target = self
            chip.action = #selector(styleClicked(_:))
            themeContentView.addSubview(chip)
            styleChips.append(chip)
        }

        let hint = PixelStyle.label("Drop .gif files into ~/.maxwell/gifs to add more", size: 9, color: PixelStyle.raspberry.withAlphaComponent(0.75), weight: .medium)
        hint.sizeToFit()
        hint.setFrameOrigin(NSPoint(x: 0, y: size.height - 86))
        themeContentView.addSubview(hint)

        let box = PixelBox(frame: NSRect(x: 0, y: 0, width: size.width, height: size.height - 98))
        themeContentView.addSubview(box)

        let scrollView = NSScrollView(frame: box.bounds.insetBy(dx: 6, dy: 6))
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        themeGridDocView = FlippedView(frame: NSRect(x: 0, y: 0, width: scrollView.frame.width - 16, height: scrollView.frame.height))
        scrollView.documentView = themeGridDocView
        box.addSubview(scrollView)

        populateThemeGrid()
    }

    private func populateThemeGrid() {
        guard themeGridDocView != nil else { return }
        themeTiles.forEach { $0.removeFromSuperview() }
        themeTiles.removeAll()

        let themes = ThemeManager.availableThemes()
        let columns = 3
        let tileW: CGFloat = 124
        let tileH: CGFloat = 96
        let hGap: CGFloat = 8
        let vGap: CGFloat = 8
        let rows = (themes.count + columns - 1) / columns
        let docWidth = themeGridDocView.frame.width
        let minHeight = themeGridDocView.superview?.frame.height ?? 0
        let docHeight = max(minHeight, CGFloat(rows) * (tileH + vGap) + vGap)
        themeGridDocView.frame = NSRect(x: 0, y: 0, width: docWidth, height: docHeight)

        for (index, url) in themes.enumerated() {
            let col = index % columns
            let row = index / columns
            let x = hGap + CGFloat(col) * (tileW + hGap)
            let y = vGap + CGFloat(row) * (tileH + vGap)
            let tile = ThemeTileView(
                frame: NSRect(x: x, y: y, width: tileW, height: tileH),
                url: url,
                isSelected: url.lastPathComponent == config.theme)
            tile.onSelect = { [weak self] in self?.selectTheme(tile.themeFileName) }
            themeGridDocView.addSubview(tile)
            themeTiles.append(tile)
        }
    }

    private func selectTheme(_ fileName: String) {
        config.theme = fileName
        for tile in themeTiles {
            tile.isSelected = tile.themeFileName == fileName
        }
        persist { $0.theme = fileName }
        onConfigChanged?()
    }

    private func persist(_ mutate: (inout MaxwellConfig) -> Void) {
        var stored = MaxwellConfig.load()
        mutate(&stored)
        stored.save()
    }

    private func formatSpeed(_ speed: Double) -> String {
        return String(format: "%.2fx", speed)
    }

    private func updateSpeedUI() {
        speedSlider?.doubleValue = config.gifSpeed
        speedLabel?.stringValue = formatSpeed(config.gifSpeed)
        speedLCD?.text = formatSpeed(config.gifSpeed)
    }

    @objc private func speedSliderChanged(_ sender: NSSlider) {
        config.gifSpeed = sender.doubleValue
        speedLabel?.stringValue = formatSpeed(config.gifSpeed)
        speedLCD?.text = formatSpeed(config.gifSpeed)
    }

    @objc private func resetSpeed() {
        config.gifSpeed = 1.0
        updateSpeedUI()
    }

    private func updateDoneBubblesUI() {
        showDoneBubblesCheckbox?.isChecked = config.showDoneBubbles
    }

    @objc private func doneBubblesChanged(_ sender: PixelCheckbox) {
        config.showDoneBubbles = sender.isChecked
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return config.remotes.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return PixelTableRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < config.remotes.count else { return nil }
        let remote = config.remotes[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""

        if identifier == "enabled" {
            let checkbox = PixelCheckbox(title: "", frame: NSRect(x: 0, y: 0, width: 24, height: 24))
            checkbox.isChecked = remote.enabled
            checkbox.tag = row
            checkbox.target = self
            checkbox.action = #selector(toggleEnabled(_:))
            return checkbox
        }

        let textField = NSTextField()
        PixelStyle.styleField(textField, size: 10)
        textField.delegate = self
        textField.tag = row

        switch identifier {
        case "name": textField.stringValue = remote.name
        case "host": textField.stringValue = remote.host
        case "user": textField.stringValue = remote.user
        case "keyPath": textField.stringValue = remote.keyPath
        default: break
        }

        textField.identifier = tableColumn?.identifier
        return textField
    }

    @objc private func toggleEnabled(_ sender: PixelCheckbox) {
        let row = sender.tag
        if row < config.remotes.count {
            config.remotes[row].enabled = sender.isChecked
        }
    }

    @objc private func addRemote() {
        config.remotes.append(RemoteConfig(name: "new", host: "", user: "", keyPath: "~/.ssh/id_rsa", enabled: true))
        tableView.reloadData()
    }

    @objc private func removeRemote() {
        let row = tableView.selectedRow
        if row >= 0 && row < config.remotes.count {
            config.remotes.remove(at: row)
            tableView.reloadData()
        }
    }

    @objc private func testSSH() {
        let row = tableView.selectedRow
        guard row >= 0 && row < config.remotes.count else {
            showAlert(title: "No Selection", message: "Please select a remote to test.")
            return
        }

        let remote = config.remotes[row]
        let keyPath = NSString(string: remote.keyPath).expandingTildeInPath

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            task.launchPath = "/usr/bin/ssh"
            task.arguments = [
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=5",
                "-o", "StrictHostKeyChecking=no",
                "-i", keyPath,
                "\(remote.user)@\(remote.host)",
                "echo ok"
            ]

            let pipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = pipe
            task.standardError = errorPipe

            do {
                try task.run()
                task.waitUntilExit()

                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    if task.terminationStatus == 0 && output.contains("ok") {
                        self?.showAlert(title: "Success", message: "SSH connection to \(remote.name) works!")
                    } else {
                        let msg = errorOutput.isEmpty ? "Connection failed" : errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                        self?.showAlert(title: "Failed", message: msg)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title == "Success" ? .informational : .warning
        alert.addButton(withTitle: "OK")
        if let window = self.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    @objc private func saveConfig() {
        if let field = messageField {
            config.clickMessage = field.stringValue
        }
        config.save()
        onConfigChanged?()
        saveButton?.title = "SAVED ♥"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.saveButton?.title = "SAVE ♥"
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              let identifier = textField.identifier?.rawValue else { return }
        if identifier == "clickMessage" {
            config.clickMessage = textField.stringValue
            return
        }
        let row = textField.tag
        guard row < config.remotes.count else { return }

        switch identifier {
        case "name": config.remotes[row].name = textField.stringValue
        case "host": config.remotes[row].host = textField.stringValue
        case "user": config.remotes[row].user = textField.stringValue
        case "keyPath": config.remotes[row].keyPath = textField.stringValue
        default: break
        }
    }
}

class HoverView: NSView {
    var clickMessage: String = MaxwellConfig.defaultClickMessage
    var closeButton: NSButton!
    var increaseButton: NSButton!
    var decreaseButton: NSButton!
    var settingsButton: NSButton!
    var trackingArea: NSTrackingArea?
    var aspectRatio: CGFloat = 1.0
    var bubbleWindows: [NSWindow] = []
    var finishedBubbleWindows: [NSWindow] = []
    var bubbleSessions: [SessionInfo] = []
    var onSettingsClick: (() -> Void)?
    var onResize: (() -> Void)?
    var onFinishedBubbleClick: (() -> Void)?
    var onBubbleClick: ((SessionInfo) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        aspectRatio = frame.width / frame.height
        setupButtons()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButtons()
    }

    private func createButton(symbolName: String, x: CGFloat) -> NSButton {
        let button = NSButton(frame: NSRect(x: x, y: frame.height - 24, width: 20, height: 20))
        button.bezelStyle = .circular
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        button.imageScaling = .scaleProportionallyUpOrDown
        button.isBordered = false
        button.contentTintColor = .white
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        button.layer?.cornerRadius = 10
        button.isHidden = true
        button.autoresizingMask = [.minXMargin, .minYMargin]
        return button
    }

    private func setupButtons() {
        closeButton = createButton(symbolName: "xmark.circle.fill", x: frame.width - 24)
        closeButton.target = NSApplication.shared
        closeButton.action = #selector(NSApplication.terminate(_:))
        addSubview(closeButton)

        increaseButton = createButton(symbolName: "plus.circle.fill", x: frame.width - 48)
        increaseButton.target = self
        increaseButton.action = #selector(increaseSize)
        addSubview(increaseButton)

        decreaseButton = createButton(symbolName: "minus.circle.fill", x: frame.width - 72)
        decreaseButton.target = self
        decreaseButton.action = #selector(decreaseSize)
        addSubview(decreaseButton)

        settingsButton = createButton(symbolName: "gearshape.fill", x: frame.width - 96)
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        addSubview(settingsButton)
    }

    @objc private func openSettings() {
        onSettingsClick?()
    }

    @objc private func increaseSize() {
        resizeWindow(scale: 1.2)
    }

    @objc private func decreaseSize() {
        resizeWindow(scale: 0.8)
    }

    private func resizeWindow(scale: CGFloat) {
        guard let window = self.window else { return }
        let currentFrame = window.frame
        let newWidth = currentFrame.width * scale
        let newHeight = newWidth / aspectRatio
        let newX = currentFrame.origin.x - (newWidth - currentFrame.width) / 2
        let newY = currentFrame.origin.y - (newHeight - currentFrame.height) / 2
        let newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)
        window.setFrame(newFrame, display: true, animate: true)
        onResize?()
    }

    func showBubbles(sessions: [SessionInfo]) {
        hideBubbles()

        guard let mainWindow = self.window else { return }

        bubbleSessions = sessions
        let maxBubbleWidth = mainWindow.frame.width
        let minBubbleWidth: CGFloat = 120
        let bubbleHeight: CGFloat = 55
        let spacing: CGFloat = 5
        let padding: CGFloat = 24

        for (index, session) in sessions.enumerated() {
            let font = NSFont.systemFont(ofSize: 10, weight: .medium)
            let lines = session.message.components(separatedBy: "\n")
            var maxLineWidth: CGFloat = 0
            for line in lines {
                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                let size = (line as NSString).size(withAttributes: attrs)
                maxLineWidth = max(maxLineWidth, size.width)
            }
            let bubbleWidth = min(max(maxLineWidth + padding, minBubbleWidth), maxBubbleWidth)

            let yOffset = CGFloat(index) * (bubbleHeight + spacing)
            let bubbleX = mainWindow.frame.midX - bubbleWidth / 2
            let bubbleY = mainWindow.frame.maxY + 5 + yOffset

            let bubbleWindow = NSWindow(
                contentRect: NSRect(x: bubbleX, y: bubbleY, width: bubbleWidth, height: bubbleHeight),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            bubbleWindow.isOpaque = false
            bubbleWindow.backgroundColor = .clear
            bubbleWindow.hasShadow = false
            bubbleWindow.level = .floating
            bubbleWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

            let bubble = SpeechBubble(frame: NSRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight))
            bubble.message = session.message
            bubble.isClickable = !session.isRemote

            let capturedSession = session
            bubble.onTap = { [weak self] in
                self?.onBubbleClick?(capturedSession)
            }

            bubbleWindow.contentView = bubble
            bubbleWindow.orderFront(nil)

            bubbleWindows.append(bubbleWindow)
        }
    }

    func hideBubbles() {
        for bubbleWindow in bubbleWindows {
            bubbleWindow.orderOut(nil)
        }
        bubbleWindows.removeAll()
        bubbleSessions.removeAll()
    }

    func showFinishedBubbles(messages: [String]) {
        hideFinishedBubbles()

        guard let mainWindow = self.window else { return }

        let maxBubbleWidth = mainWindow.frame.width
        let minBubbleWidth: CGFloat = 120
        let bubbleHeight: CGFloat = 55
        let spacing: CGFloat = 5
        let padding: CGFloat = 24

        let baseYOffset = CGFloat(bubbleWindows.count) * (bubbleHeight + spacing)

        for (index, message) in messages.enumerated() {
            let font = NSFont.systemFont(ofSize: 10, weight: .medium)
            let lines = message.components(separatedBy: "\n")
            var maxLineWidth: CGFloat = 0
            for line in lines {
                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                let size = (line as NSString).size(withAttributes: attrs)
                maxLineWidth = max(maxLineWidth, size.width)
            }
            let bubbleWidth = min(max(maxLineWidth + padding, minBubbleWidth), maxBubbleWidth)

            let yOffset = baseYOffset + CGFloat(index) * (bubbleHeight + spacing)
            let bubbleX = mainWindow.frame.midX - bubbleWidth / 2
            let bubbleY = mainWindow.frame.maxY + 5 + yOffset

            let bubbleWindow = NSWindow(
                contentRect: NSRect(x: bubbleX, y: bubbleY, width: bubbleWidth, height: bubbleHeight),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            bubbleWindow.isOpaque = false
            bubbleWindow.backgroundColor = .clear
            bubbleWindow.hasShadow = false
            bubbleWindow.level = .floating
            bubbleWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

            let bubble = SpeechBubble(frame: NSRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight))
            bubble.message = message
            bubbleWindow.contentView = bubble
            bubbleWindow.orderFront(nil)

            finishedBubbleWindows.append(bubbleWindow)
        }
    }

    func hideFinishedBubbles() {
        for bubbleWindow in finishedBubbleWindows {
            bubbleWindow.orderOut(nil)
        }
        finishedBubbleWindows.removeAll()
    }

    func updateBubblePositions() {
        guard let mainWindow = self.window else { return }

        let bubbleHeight: CGFloat = 55
        let spacing: CGFloat = 5

        for (index, bubbleWindow) in bubbleWindows.enumerated() {
            let bubbleWidth = bubbleWindow.frame.width
            let yOffset = CGFloat(index) * (bubbleHeight + spacing)
            let bubbleX = mainWindow.frame.midX - bubbleWidth / 2
            let bubbleY = mainWindow.frame.maxY + 5 + yOffset
            bubbleWindow.setFrameOrigin(NSPoint(x: bubbleX, y: bubbleY))
        }

        let baseYOffset = CGFloat(bubbleWindows.count) * (bubbleHeight + spacing)
        for (index, bubbleWindow) in finishedBubbleWindows.enumerated() {
            let bubbleWidth = bubbleWindow.frame.width
            let yOffset = baseYOffset + CGFloat(index) * (bubbleHeight + spacing)
            let bubbleX = mainWindow.frame.midX - bubbleWidth / 2
            let bubbleY = mainWindow.frame.maxY + 5 + yOffset
            bubbleWindow.setFrameOrigin(NSPoint(x: bubbleX, y: bubbleY))
        }
    }

    func showMeow() {
        let text = clickMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let meowLabel = NSTextField(labelWithString: text)
        meowLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        meowLabel.textColor = NSColor.labelColor
        meowLabel.backgroundColor = .clear
        meowLabel.isBezeled = false
        meowLabel.isEditable = false
        meowLabel.sizeToFit()

        let padding: CGFloat = 30
        let maxX = bounds.width - meowLabel.frame.width - padding
        let maxY = bounds.height - meowLabel.frame.height - padding
        let randomX = CGFloat.random(in: padding...max(padding, maxX))
        let randomY = CGFloat.random(in: padding...max(padding, maxY))
        meowLabel.frame.origin = NSPoint(x: randomX, y: randomY)
        meowLabel.alphaValue = 1.0
        addSubview(meowLabel)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 1.0
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            meowLabel.animator().frame.origin.y += 40
            meowLabel.animator().alphaValue = 0
        }, completionHandler: {
            meowLabel.removeFromSuperview()
        })
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        closeButton.isHidden = false
        increaseButton.isHidden = false
        decreaseButton.isHidden = false
        settingsButton.isHidden = false
    }

    override func mouseExited(with event: NSEvent) {
        closeButton.isHidden = true
        increaseButton.isHidden = true
        decreaseButton.isHidden = true
        settingsButton.isHidden = true
    }
}

class ClaudeMonitor {
    var onClaudeWaiting: (([SessionInfo]) -> Void)?
    var onClaudeNotWaiting: (() -> Void)?
    var onClaudeFinished: (([String]) -> Void)?
    var onClaudeFinishedCleared: (() -> Void)?
    private var timer: Timer?
    private var lastState: Bool = false
    private var config: MaxwellConfig = MaxwellConfig.load()

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkClaude()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reloadConfig() {
        config = MaxwellConfig.load()
    }

    func dismissFinishedSessions() {
        let doneDir = "/tmp/maxwell_claude_done"
        for session in lastFinishedSessions {
            try? FileManager.default.removeItem(atPath: "\(doneDir)/\(session).json")
        }
        lastFinishedMessages = []
        lastFinishedSessions = []
        onClaudeFinishedCleared?()
    }

    private var lastMessages: [SessionInfo] = []
    private var lastFinishedMessages: [String] = []
    private var lastFinishedSessions: Set<String> = []

    private func checkClaude() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            var sessions = self?.checkAllSessions() ?? []
            let remoteSessions = self?.checkRemoteSessions() ?? []
            sessions.append(contentsOf: remoteSessions)

            let (finishedMessages, finishedSessions) = self?.checkFinishedSessions() ?? ([], [])

            DispatchQueue.main.async {
                if !sessions.isEmpty {
                    let currentMessages = sessions.map { $0.message }
                    let lastMessages = self?.lastMessages.map { $0.message } ?? []
                    if currentMessages != lastMessages {
                        self?.lastMessages = sessions
                        self?.onClaudeWaiting?(sessions)
                    }
                } else {
                    if self?.lastState != false {
                        self?.lastState = false
                        self?.lastMessages = []
                        self?.onClaudeNotWaiting?()
                    }
                }
                self?.lastState = !sessions.isEmpty

                if !finishedMessages.isEmpty {
                    if finishedMessages != self?.lastFinishedMessages {
                        self?.lastFinishedMessages = finishedMessages
                        self?.lastFinishedSessions = finishedSessions
                        self?.onClaudeFinished?(finishedMessages)
                    }
                } else if !(self?.lastFinishedMessages.isEmpty ?? true) {
                    self?.lastFinishedMessages = []
                    self?.lastFinishedSessions = []
                    self?.onClaudeFinishedCleared?()
                }
            }
        }
    }

    private func checkRemoteSessions() -> [SessionInfo] {
        var sessions: [SessionInfo] = []
        let enabledRemotes = config.remotes.filter { $0.enabled }

        for remote in enabledRemotes {
            let keyPath = NSString(string: remote.keyPath).expandingTildeInPath
            let sshCmd = "ssh -o BatchMode=yes -o ConnectTimeout=2 -o StrictHostKeyChecking=no -i \"\(keyPath)\" \(remote.user)@\(remote.host) 'cat /tmp/maxwell_claude/*.json 2>/dev/null'"

            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", sshCmd]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                let now = Int(Date().timeIntervalSince1970)
                for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                    guard let jsonData = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                          let cwd = json["cwd"] as? String,
                          let time = json["time"] as? Int else {
                        continue
                    }
                    if now - time >= 120 { continue }
                    let message = buildBubbleMessage(json: json, cwd: cwd, serverLabel: "[\(remote.name)] ")
                    sessions.append(SessionInfo(
                        message: message,
                        cwd: cwd,
                        sessionId: json["session"] as? String ?? "",
                        isRemote: true,
                        remoteName: remote.name
                    ))
                }
            } catch {
            }
        }
        return sessions
    }

    private func buildBubbleMessage(json: [String: Any], cwd: String, serverLabel: String) -> String {
        let folder = cwd.components(separatedBy: "/").suffix(2).joined(separator: "/")
        let tool = json["tool"] as? String
        let cmd = (json["cmd"] as? String) ?? ""
        let toolIcon: String
        switch tool {
        case "Bash": toolIcon = "🖥️"
        case "Edit": toolIcon = "✏️"
        case "Write": toolIcon = "📝"
        case "Read": toolIcon = "📖"
        default: toolIcon = "⚠️"
        }
        let head: String
        if !cmd.isEmpty {
            let shortCmd = cmd.count > 20 ? String(cmd.prefix(20)) + "…" : cmd
            head = "\(toolIcon) \(shortCmd)"
        } else if let tool = tool, !tool.isEmpty {
            head = "\(toolIcon) \(tool)"
        } else if let msg = json["message"] as? String, !msg.isEmpty {
            let shortMsg = msg.count > 26 ? String(msg.prefix(26)) + "…" : msg
            head = "⚠️ \(shortMsg)"
        } else {
            head = "⚠️ Approve?"
        }
        return folder.isEmpty ? "\(serverLabel)\(head)" : "\(serverLabel)\(head)\n📁 \(folder)"
    }

    private func checkAllSessions() -> [SessionInfo] {
        let statusDir = "/tmp/maxwell_claude"
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(atPath: statusDir) else {
            return []
        }

        let now = Int(Date().timeIntervalSince1970)
        var found: [(time: Int, info: SessionInfo)] = []

        for file in files where file.hasSuffix(".json") {
            let filePath = "\(statusDir)/\(file)"

            guard let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                  let markerMtime = attrs[.modificationDate] as? Date,
                  let data = fileManager.contents(atPath: filePath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cwd = json["cwd"] as? String,
                  let time = json["time"] as? Int,
                  let session = json["session"] as? String else {
                continue
            }

            // Clear as soon as the session moves past the prompt (approved OR
            // rejected): once the transcript advances beyond when the prompt
            // appeared, the decision has been made. This covers rejects and
            // interrupts, which fire no clearing hook. While the prompt is still
            // open the loop is blocked and the transcript does not advance, so a
            // genuinely-pending bubble is never cleared early.
            if transcriptAdvanced(past: markerMtime, session: session) {
                try? fileManager.removeItem(atPath: filePath)
                continue
            }

            // Safety net for sessions that died without firing any hook.
            if now - time >= 120 {
                try? fileManager.removeItem(atPath: filePath)
                continue
            }

            let message = buildBubbleMessage(json: json, cwd: cwd, serverLabel: "")
            found.append((time, SessionInfo(
                message: message,
                cwd: cwd,
                sessionId: session,
                isRemote: false,
                remoteName: nil
            )))
        }

        return found.sorted { $0.time < $1.time }.map { $0.info }
    }

    private func transcriptAdvanced(past markerMtime: Date, session: String) -> Bool {
        let fileManager = FileManager.default
        let projectsPath = NSString(string: "~/.claude/projects").expandingTildeInPath
        guard let dirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) else {
            return false
        }
        for dir in dirs {
            let transcriptPath = "\(projectsPath)/\(dir)/\(session).jsonl"
            if let attrs = try? fileManager.attributesOfItem(atPath: transcriptPath),
               let mtime = attrs[.modificationDate] as? Date {
                return mtime.timeIntervalSince1970 > markerMtime.timeIntervalSince1970 + 2
            }
        }
        return false
    }

    private func checkFinishedSessions() -> ([String], Set<String>) {
        let fileManager = FileManager.default
        let doneDir = "/tmp/maxwell_claude_done"
        let statusDir = "/tmp/maxwell_claude"
        let now = Int(Date().timeIntervalSince1970)
        let maxAge = 300

        guard let files = try? fileManager.contentsOfDirectory(atPath: doneDir) else {
            return ([], [])
        }

        var found: [(time: Int, message: String, session: String)] = []

        for file in files where file.hasSuffix(".json") {
            let filePath = "\(doneDir)/\(file)"
            guard let data = fileManager.contents(atPath: filePath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let time = json["time"] as? Int,
                  let session = json["session"] as? String else {
                continue
            }

            if now - time >= maxAge {
                try? fileManager.removeItem(atPath: filePath)
                continue
            }

            // A live "waiting for approval" state takes priority over "done".
            if fileManager.fileExists(atPath: "\(statusDir)/\(session).json") {
                continue
            }

            let cwd = json["cwd"] as? String ?? ""
            let folder = cwd.components(separatedBy: "/").suffix(2).joined(separator: "/")
            let prompt = json["prompt"] as? String ?? ""
            let shortPrompt = prompt.count > 30 ? String(prompt.prefix(30)) + "…" : prompt
            let head = shortPrompt.isEmpty ? "✅ done" : "✅ \(shortPrompt)"
            let message = folder.isEmpty ? head : "\(head)\n📁 \(folder)"
            found.append((time, message, session))
        }

        found.sort { $0.time < $1.time }
        return (found.map { $0.message }, Set(found.map { $0.session }))
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var containerView: HoverView!
    var claudeMonitor: ClaudeMonitor!
    var settingsController: SettingsWindowController!
    var gifView: AnimatedGIFView!
    var originalY: CGFloat = 0
    var jumpTimer: Timer?
    var hasBubbles: Bool = false
    var hasFinishedBubbles: Bool = false
    var currentTheme: String = MaxwellConfig.defaultTheme

    func applicationDidFinishLaunching(_ notification: Notification) {
        ThemeManager.seedIfNeeded()
        let config = MaxwellConfig.load()
        currentTheme = config.theme

        settingsController = SettingsWindowController()
        settingsController.onConfigChanged = { [weak self] in
            self?.claudeMonitor.reloadConfig()
            self?.applyConfig()
        }

        guard let gifURL = ThemeManager.gifURL(for: config.theme),
              let gifData = try? Data(contentsOf: gifURL),
              let image = NSImage(data: gifData) else {
            print("Failed to load gif for theme \(config.theme)")
            NSApplication.shared.terminate(nil)
            return
        }

        let imageSize = image.size

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = true

        containerView = HoverView(frame: NSRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        containerView.aspectRatio = imageSize.width / imageSize.height
        containerView.clickMessage = config.clickMessage
        containerView.onSettingsClick = { [weak self] in
            self?.settingsController.show()
        }
        containerView.onResize = { [weak self] in
            self?.saveWindowFrame()
        }

        gifView = AnimatedGIFView(frame: NSRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        gifView.autoresizingMask = [.width, .height]
        gifView.speed = config.gifSpeed
        gifView.loadGIF(from: gifURL)
        gifView.onDrag = { [weak self] newY in
            self?.originalY = newY
            self?.containerView.updateBubblePositions()
            self?.saveWindowFrame()
        }
        gifView.onClick = { [weak self] in
            if self?.hasFinishedBubbles == true {
                self?.dismissFinishedNotifications()
            } else {
                self?.doClickJump()
                self?.containerView.showMeow()
            }
        }

        containerView.addSubview(gifView, positioned: .below, relativeTo: containerView.closeButton)
        window.contentView = containerView
        restoreWindowFrame()
        window.makeKeyAndOrderFront(nil)
        settingsController.anchorWindow = window

        claudeMonitor = ClaudeMonitor()
        claudeMonitor.onClaudeWaiting = { [weak self] sessions in
            self?.showNotifications(sessions: sessions)
        }
        claudeMonitor.onClaudeNotWaiting = { [weak self] in
            self?.hideNotifications()
        }
        claudeMonitor.onClaudeFinished = { [weak self] messages in
            self?.showFinishedNotifications(messages: messages)
        }
        claudeMonitor.onClaudeFinishedCleared = { [weak self] in
            self?.hideFinishedNotifications()
        }
        claudeMonitor.start()

        containerView.onBubbleClick = { [weak self] session in
            self?.switchToApp(for: session)
        }

        if CommandLine.arguments.contains("--settings") {
            settingsController.show()
        }
    }

    func showNotifications(sessions: [SessionInfo]) {
        containerView.showBubbles(sessions: sessions)
        startJumping()
    }

    func switchToApp(for session: SessionInfo) {
        if session.isRemote {
            return
        }

        let cwd = session.cwd

        DispatchQueue.global(qos: .userInitiated).async {
            let codeProcess = Process()
            codeProcess.launchPath = "/usr/bin/env"
            codeProcess.arguments = ["code", "-r", "-g", "\(cwd)/."]
            codeProcess.standardOutput = FileHandle.nullDevice
            codeProcess.standardError = FileHandle.nullDevice

            do {
                try codeProcess.run()
                codeProcess.waitUntilExit()

                if codeProcess.terminationStatus != 0 {
                    let openProcess = Process()
                    openProcess.launchPath = "/usr/bin/open"
                    openProcess.arguments = ["-a", "Visual Studio Code", cwd]
                    openProcess.standardOutput = FileHandle.nullDevice
                    openProcess.standardError = FileHandle.nullDevice
                    try? openProcess.run()
                    openProcess.waitUntilExit()
                }
            } catch {
                let openProcess = Process()
                openProcess.launchPath = "/usr/bin/open"
                openProcess.arguments = ["-a", "Visual Studio Code", cwd]
                openProcess.standardOutput = FileHandle.nullDevice
                openProcess.standardError = FileHandle.nullDevice
                try? openProcess.run()
            }
        }
    }

    func hideNotifications() {
        containerView.hideBubbles()
        stopJumping()
    }

    func showFinishedNotifications(messages: [String]) {
        let config = MaxwellConfig.load()
        guard config.showDoneBubbles else { return }
        containerView.showFinishedBubbles(messages: messages)
        hasFinishedBubbles = true
    }

    func hideFinishedNotifications() {
        containerView.hideFinishedBubbles()
        hasFinishedBubbles = false
    }

    func dismissFinishedNotifications() {
        claudeMonitor.dismissFinishedSessions()
        hideFinishedNotifications()
    }

    func startJumping() {
        guard !hasBubbles else { return }
        hasBubbles = true
        originalY = window.frame.origin.y
        doOneJump()
    }

    func stopJumping() {
        hasBubbles = false
        jumpTimer?.invalidate()
        jumpTimer = nil
        if originalY > 0 {
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x, y: originalY))
        }
    }

    func doOneJump() {
        guard hasBubbles else { return }

        let jumpHeight: CGFloat = 35
        let steps = 20
        let totalDuration = 0.4
        let stepDuration = totalDuration / Double(steps)
        var currentStep = 0

        jumpTimer?.invalidate()
        jumpTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self, self.hasBubbles else {
                timer.invalidate()
                return
            }

            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let bounceProgress = sin(progress * .pi)
            let newY = self.originalY + jumpHeight * CGFloat(bounceProgress)
            self.window.setFrameOrigin(NSPoint(x: self.window.frame.origin.x, y: newY))

            if currentStep >= steps {
                timer.invalidate()
                self.window.setFrameOrigin(NSPoint(x: self.window.frame.origin.x, y: self.originalY))
                self.doOneJump()
            }
        }
    }

    func doClickJump() {
        guard !hasBubbles else { return }

        let startY = window.frame.origin.y
        let jumpHeight: CGFloat = 20
        let steps = 16
        let totalDuration = 0.25
        let stepDuration = totalDuration / Double(steps)
        var currentStep = 0

        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let bounceProgress = sin(progress * .pi)
            let newY = startY + jumpHeight * CGFloat(bounceProgress)
            self.window.setFrameOrigin(NSPoint(x: self.window.frame.origin.x, y: newY))

            if currentStep >= steps {
                timer.invalidate()
                self.window.setFrameOrigin(NSPoint(x: self.window.frame.origin.x, y: startY))
            }
        }
    }

    private func applyConfig() {
        let config = MaxwellConfig.load()
        gifView.speed = config.gifSpeed
        containerView.clickMessage = config.clickMessage
        if !config.showDoneBubbles {
            hideFinishedNotifications()
        }
        if config.theme != currentTheme {
            reloadGif(theme: config.theme)
        }
    }

    private func reloadGif(theme: String) {
        guard let url = ThemeManager.gifURL(for: theme),
              let data = try? Data(contentsOf: url),
              let image = NSImage(data: data), image.size.height > 0 else { return }
        currentTheme = theme

        let aspect = image.size.width / image.size.height
        containerView.aspectRatio = aspect
        gifView.loadGIF(from: url)

        var frame = window.frame
        let newHeight = frame.width / aspect
        frame.origin.y += frame.height - newHeight
        frame.size.height = newHeight
        window.setFrame(frame, display: true)
        saveWindowFrame()
    }

    private func saveWindowFrame() {
        let frame = window.frame
        UserDefaults.standard.set(frame.origin.x, forKey: "maxwell_x")
        UserDefaults.standard.set(frame.origin.y, forKey: "maxwell_y")
        UserDefaults.standard.set(frame.width, forKey: "maxwell_width")
        UserDefaults.standard.set(frame.height, forKey: "maxwell_height")
        UserDefaults.standard.synchronize()
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWindowFrame()
    }

    private func restoreWindowFrame() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "maxwell_x") != nil {
            let x = defaults.double(forKey: "maxwell_x")
            let y = defaults.double(forKey: "maxwell_y")
            let width = defaults.double(forKey: "maxwell_width")
            let height = defaults.double(forKey: "maxwell_height")
            if width > 0 && height > 0 {
                window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
                return
            }
        }
        window.center()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

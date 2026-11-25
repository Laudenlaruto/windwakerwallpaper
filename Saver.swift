// TimeWall.saver — screen saver that shows the same time-of-day image as the wallpaper.
// The images live inside the bundle (Contents/Resources/imgs) because macOS runs
// screen savers in a sandbox that may not be able to read Application Support.

import ScreenSaver
import os

private let log = Logger(subsystem: "local.timechangingwallpaper", category: "saver")

@objc(TimeWallView)
final class TimeWallView: ScreenSaverView {
    private var currentNum = 0
    private var image: NSImage?
    private var previous: NSImage?
    private var fadeStart: Date?
    private let fadeDuration: TimeInterval = 2
    private var lastCheck = Date.distantPast

    private lazy var imagesDir: URL? =
        Bundle(for: TimeWallView.self).resourceURL?.appendingPathComponent("imgs", isDirectory: true)

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 30.0
        wantsLayer = true
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }

    override func startAnimation() {
        super.startAnimation()
        lastCheck = .distantPast
        refreshIfNeeded(animated: false)
    }

    override func stopAnimation() {
        super.stopAnimation()
        previous = nil
        fadeStart = nil
    }

    private func refreshIfNeeded(animated: Bool) {
        lastCheck = Date()
        let num = Schedule.imageNumber(forMinuteOfDay: Schedule.currentMinuteOfDay())
        guard num != currentNum, let dir = imagesDir else { return }
        let url = dir.appendingPathComponent("\(num).jpg")
        guard let img = NSImage(contentsOf: url) else {
            log.error("could not load \(url.path, privacy: .public)")
            return
        }
        log.notice("loaded \(url.lastPathComponent, privacy: .public) preview=\(self.isPreview)")
        if animated, image != nil {
            previous = image
            fadeStart = Date()
        }
        image = img
        currentNum = num
        needsDisplay = true
    }

    override func animateOneFrame() {
        if Date().timeIntervalSince(lastCheck) >= 30 { refreshIfNeeded(animated: true) }
        if fadeStart != nil { needsDisplay = true }
    }

    /// Aspect-fill: scale to cover the view and crop the overflow, centred.
    private func draw(_ img: NSImage, alpha: CGFloat) {
        let b = bounds
        let s = img.size
        guard s.width > 0, s.height > 0 else { return }
        let scale = max(b.width / s.width, b.height / s.height)
        let w = s.width * scale, h = s.height * scale
        let r = NSRect(x: b.midX - w / 2, y: b.midY - h / 2, width: w, height: h)
        img.draw(in: r, from: .zero, operation: .sourceOver, fraction: alpha)
    }

    override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()
        var t: CGFloat = 1
        if let start = fadeStart {
            t = CGFloat(min(1, Date().timeIntervalSince(start) / fadeDuration))
            if t >= 1 { fadeStart = nil; previous = nil }
        }
        if let p = previous { draw(p, alpha: 1) }
        if let img = image { draw(img, alpha: t) }
    }
}

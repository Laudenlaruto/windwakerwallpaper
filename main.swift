// timewall — macOS port of JayexDesigns/time-changing-wallpaper.
// Sets the desktop picture on every screen to the image that matches the
// current local time, using the same schedule as the original script.js.
//
// Usage:
//   timewall [--images DIR] [--at HH:MM] [--print] [--get] [--watch]
//     --images DIR  folder containing 1.jpg … 200.jpg
//                   (default: ~/Library/Application Support/TimeChangingWallpaper/imgs)
//     --at HH:MM    pretend it is this time (for testing)
//     --print       only print which image would be shown, don't set it
//     --get         print the current desktop picture of every screen and exit
//     --watch       keep running: re-apply every minute and whenever you switch
//                   Space, plug in or remove a display, or wake the Mac

import AppKit

var imagesDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/TimeChangingWallpaper/imgs")
var forcedMinute: Int? = nil
var printOnly = false
var getOnly = false
var watch = false

func fail(_ msg: String, code: Int32 = 2) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(code)
}

var args = Array(CommandLine.arguments.dropFirst())
while !args.isEmpty {
    let a = args.removeFirst()
    switch a {
    case "--images":
        guard let v = args.first else { fail("--images needs a folder") }
        args.removeFirst()
        imagesDir = URL(fileURLWithPath: (v as NSString).expandingTildeInPath, isDirectory: true)
    case "--at":
        guard let v = args.first else { fail("--at needs HH:MM") }
        args.removeFirst()
        let p = v.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2, (0..<24).contains(p[0]), (0..<60).contains(p[1]) else {
            fail("--at needs HH:MM, got \(v)")
        }
        forcedMinute = p[0] * 60 + p[1]
    case "--print": printOnly = true
    case "--get": getOnly = true
    case "--watch": watch = true
    default: fail("unknown argument: \(a)")
    }
}

let ws = NSWorkspace.shared

if getOnly {
    for (i, s) in NSScreen.screens.enumerated() {
        print("screen \(i) (\(s.localizedName)): \(ws.desktopImageURL(for: s)?.path ?? "none")")
    }
    exit(0)
}

func currentURL() -> (Int, Int, URL) {
    let minute = forcedMinute ?? Schedule.currentMinuteOfDay()
    let num = Schedule.imageNumber(forMinuteOfDay: minute)
    return (minute, num, imagesDir.appendingPathComponent("\(num).jpg"))
}

// "Fill screen": scale proportionally and crop, like the CSS cover logic in script.js.
let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
    .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
    .allowClipping: true,
]

/// Sets the image on every screen (for the current Space). With `force`,
/// skips the "already set" check, which can lag behind a recent change.
@discardableResult
func apply(force: Bool, reason: String) -> Bool {
    let (_, num, url) = currentURL()
    guard FileManager.default.fileExists(atPath: url.path) else {
        FileHandle.standardError.write("missing image: \(url.path)\n".data(using: .utf8)!)
        return false
    }
    var ok = true
    var changed = 0
    for screen in NSScreen.screens {
        if !force, ws.desktopImageURL(for: screen)?.standardizedFileURL == url.standardizedFileURL { continue }
        do {
            try ws.setDesktopImageURL(url, for: screen, options: options)
            changed += 1
        } catch {
            FileHandle.standardError.write("\(screen.localizedName): \(error)\n".data(using: .utf8)!)
            ok = false
        }
    }
    if watch && (force || changed > 0) {
        let stamp = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withInternetDateTime])
        print("\(stamp) \(reason): \(num).jpg on \(changed)/\(NSScreen.screens.count) screens")
        fflush(stdout)
    }
    return ok
}

if printOnly {
    let (minute, num, _) = currentURL()
    print(String(format: "%02d:%02d -> %d.jpg", minute / 60, minute % 60, num))
    exit(0)
}

if !watch {
    exit(apply(force: false, reason: "once") ? 0 : 1)
}

// MARK: - Watch mode

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

// Space switches, display changes and wake can each leave a desktop on a stale
// image, so re-apply right away (and once more shortly after, when macOS has
// finished rearranging things).
func applySoon(_ reason: String) {
    apply(force: true, reason: reason)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { apply(force: true, reason: reason + "+2s") }
}

let wnc = ws.notificationCenter
wnc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in applySoon("space") }
wnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in applySoon("wake") }
wnc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in applySoon("screens-wake") }
NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in applySoon("displays") }

// Minute tick: cheap when nothing changed (the readback check skips the set).
let timer = Timer(timeInterval: 60, repeats: true) { _ in apply(force: false, reason: "tick") }
timer.tolerance = 5
RunLoop.main.add(timer, forMode: .common)

apply(force: true, reason: "start")
app.run()

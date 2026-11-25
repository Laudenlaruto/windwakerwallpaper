// Shared by the wallpaper tool and the screen saver.
// Straight port of the schedule in JayexDesigns/time-changing-wallpaper script.js.

import Foundation

enum Schedule {
    static let totalImg = 199             // script.js: totalImg
    static let sunriseImg = 40            // image shown at sunrise
    static let sunriseMinute = 5 * 60 + 1 // "0501"
    static let minutesPerImg = 1440.0 / Double(totalImg)
    static let offset = Int(floor(Double(sunriseMinute) / minutesPerImg)) - sunriseImg + 1

    /// Image number (1…200) for a minute of the day (0…1439).
    static func imageNumber(forMinuteOfDay t: Int) -> Int {
        var num = Int(floor(Double(t) / minutesPerImg)) - offset + 1
        if num > totalImg + 1 { num = num - totalImg + 1 }
        else if num < 1 { num = totalImg + 1 + num }
        return num
    }

    static func currentMinuteOfDay(_ date: Date = Date()) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return c.hour! * 60 + c.minute!
    }
}

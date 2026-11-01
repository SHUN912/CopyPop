import Foundation

final class CopyCounter {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private var day: String = ""
    private var counts: [String: Int] = [:]
    private(set) var total = 0
    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: Date = Date()) {
        self.defaults = defaults; self.calendar = calendar
        day = defaults.string(forKey: "day") ?? ""
        total = defaults.integer(forKey: "total")
        refresh(now)
    }
    func refresh(_ now: Date = Date()) {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        let key = "\(c.year!)-\(c.month!)-\(c.day!)"
        if key != day { day = key; total = 0; counts.removeAll(); persist() }
    }
    func record(_ fingerprint: String?, now: Date = Date()) -> Int {
        refresh(now)
        total += 1
        var n = 1
        if let fingerprint {
            // Bound memory without storing clipboard data on disk.
            if counts.count >= 10000 && counts[fingerprint] == nil { counts.removeAll() }
            n = (counts[fingerprint] ?? 0) + 1; counts[fingerprint] = n
        }
        persist(); return n
    }
    private func persist() { defaults.set(day, forKey: "day"); defaults.set(total, forKey: "total") }
}

import XCTest
@testable import CopyPop
final class CounterTests: XCTestCase {
    func testInterleavedAndRestartPrivacy() {
        let name = "CopyPopTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let now = Date()
        let c = CopyCounter(defaults: defaults, now: now)
        XCTAssertEqual(c.record("A", now: now), 1)
        XCTAssertEqual(c.record("B", now: now), 1)
        XCTAssertEqual(c.record("A", now: now), 2)
        XCTAssertEqual(c.total, 3)
        let restored = CopyCounter(defaults: defaults, now: now)
        XCTAssertEqual(restored.total, 3)
        XCTAssertEqual(restored.record("A", now: now), 1)
        XCTAssertEqual(Set(defaults.persistentDomain(forName: name)!.keys), Set(["day", "total"]))
    }
    func testMidnightAndSensitive() {
        let name = "CopyPopTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8*3600)!
        let before = ISO8601DateFormatter().date(from: "2026-11-01T15:59:59Z")!
        let c = CopyCounter(defaults: defaults, calendar: calendar, now: before)
        XCTAssertEqual(c.record("A", now: before), 1)
        XCTAssertEqual(c.record(nil, now: before), 1)
        XCTAssertEqual(c.record(nil, now: before), 1)
        XCTAssertEqual(c.total, 3)
        c.refresh(before.addingTimeInterval(2))
        XCTAssertEqual(c.total, 0)
        XCTAssertEqual(c.record("A", now: before.addingTimeInterval(2)), 1)
    }
}

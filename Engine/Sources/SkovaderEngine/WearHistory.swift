import Foundation

/// En registrering av "Jag tar dessa".
public struct WearEntry: Hashable, Sendable {
    public var shoeID: UUID
    public var date: Date

    public init(shoeID: UUID, date: Date) {
        self.shoeID = shoeID
        self.date = date
    }
}

/// Vilka dagar (räknat bakåt från idag) varje sko har använts.
/// Bygger på kalenderdagar, så en registrering 23:30 igår räknas som igår.
public struct WearHistory: Sendable {
    private var daysAgoByShoe: [UUID: Set<Int>]

    public static let empty = WearHistory(daysAgoByShoe: [:])

    public init(entries: [WearEntry], today: Date, calendar: Calendar = .current) {
        let todayStart = calendar.startOfDay(for: today)
        var result: [UUID: Set<Int>] = [:]
        for entry in entries {
            let entryStart = calendar.startOfDay(for: entry.date)
            guard let days = calendar.dateComponents([.day], from: entryStart, to: todayStart).day,
                  days >= 0 else { continue }
            result[entry.shoeID, default: []].insert(days)
        }
        self.daysAgoByShoe = result
    }

    /// För tester och förhandsvisningar: ange direkt hur många dagar sedan.
    public init(daysAgo: [UUID: Set<Int>]) {
        self.daysAgoByShoe = daysAgo
    }

    private init(daysAgoByShoe: [UUID: Set<Int>]) {
        self.daysAgoByShoe = daysAgoByShoe
    }

    public func wasWorn(_ shoeID: UUID, daysAgo: Int) -> Bool {
        daysAgoByShoe[shoeID]?.contains(daysAgo) ?? false
    }

    /// Antal dagar sedan skon senast användes före idag, eller nil.
    public func daysSinceLastWorn(_ shoeID: UUID) -> Int? {
        daysAgoByShoe[shoeID]?.filter { $0 > 0 }.min()
    }
}

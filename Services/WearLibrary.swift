import Foundation
import SwiftData

/// "Jag tar dessa" (F8): ett val per dag. Väljer man om samma dag ersätts
/// det tidigare valet.
@MainActor
enum WearLibrary {
    static func choose(_ shoe: Shoe, on date: Date = Date(), in context: ModelContext, calendar: Calendar = .current) throws {
        let todays = try logs(on: date, in: context, calendar: calendar)
        if todays.count == 1, todays[0].shoe?.id == shoe.id { return }
        for log in todays {
            context.delete(log)
        }
        context.insert(WearLog(shoe: shoe, date: date))
        try context.save()
    }

    static func logs(on date: Date, in context: ModelContext, calendar: Calendar = .current) throws -> [WearLog] {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
        let descriptor = FetchDescriptor<WearLog>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return try context.fetch(descriptor)
    }

    /// Id för skon som valts `date`, bland redan hämtade loggar.
    static func chosenShoeID(on date: Date, among logs: [WearLog], calendar: Calendar = .current) -> UUID? {
        logs
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .max { $0.date < $1.date }?
            .shoe?.id
    }
}

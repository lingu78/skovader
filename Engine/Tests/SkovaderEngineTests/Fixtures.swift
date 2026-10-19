import Foundation
import XCTest
@testable import SkovaderEngine

/// En sko av varje typ med typens standardvärden.
enum Wardrobe {
    static let sandals = ShoeProfile(name: "Sandaler", type: .sandals)
    static let sneakers = ShoeProfile(name: "Rosa Converse", type: .sneakers)
    static let leather = ShoeProfile(name: "Lädersneakers", type: .leatherSneakers)
    static let runners = ShoeProfile(name: "Vattentäta löparskor", type: .waterproofSneakers)
    static let boots = ShoeProfile(name: "Kängor", type: .boots)
    static let winterBoots = ShoeProfile(name: "Vinterkängor", type: .winterBoots)
    static let rubberBoots = ShoeProfile(name: "Gummistövlar", type: .rubberBoots)

    static let all = [sandals, sneakers, leather, runners, boots, winterBoots, rubberBoots]
}

enum Weather {
    static let warmSun = DayWeather(feelsLikeMin: 22, feelsLikeMax: 30, maxWindSpeed: 3)
    static let coolSummer = DayWeather(feelsLikeMin: 12, feelsLikeMax: 22, maxWindSpeed: 4)
    static let chillyHeavyRain = DayWeather(feelsLikeMin: 3, feelsLikeMax: 7, precipitationMM: 6, precipitationType: .rain, maxWindSpeed: 5)
    static let mildLightRain = DayWeather(feelsLikeMin: 9, feelsLikeMax: 13, precipitationMM: 2, precipitationType: .rain)
    static let snow = DayWeather(feelsLikeMin: -8, feelsLikeMax: -3, precipitationMM: 3, precipitationType: .snow)
    static let coldDry = DayWeather(feelsLikeMin: -12, feelsLikeMax: -6)
    static let windy = DayWeather(feelsLikeMin: -2, feelsLikeMax: 3, maxWindSpeed: 14)
    static let windyRain = DayWeather(feelsLikeMin: 4, feelsLikeMax: 6, precipitationMM: 3, precipitationType: .rain, maxWindSpeed: 12)
    static let sleet = DayWeather(feelsLikeMin: 0, feelsLikeMax: 2, precipitationMM: 4, precipitationType: .sleet)
}

struct NoSuggestion: Error {}

extension XCTestCase {
    func suggestion(
        _ recommendation: Recommendation,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Suggestion {
        guard case .suggestion(let suggestion) = recommendation else {
            XCTFail("Väntade ett förslag, fick \(recommendation)", file: file, line: line)
            throw NoSuggestion()
        }
        return suggestion
    }

    func names(_ shoes: [ScoredShoe]) -> [String] {
        shoes.map(\.shoe.name)
    }
}

extension Calendar {
    static let stockholm: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

import Foundation

/// Nycklar i UserDefaults (används med @AppStorage).
enum SettingsKey {
    static let hasOnboarded = "hasOnboarded"
    static let useManualPlace = "useManualPlace"
    static let manualPlace = "manualPlace"
    static let morningNotificationEnabled = "morningNotificationEnabled"
    static let morningNotificationMinutes = "morningNotificationMinutes"
    static let autoCutout = "autoCutout"
}

/// En ort som användaren sökt fram (F9). Koordinaterna sparas avrundade.
struct Place: Codable, Hashable, Identifiable, Sendable {
    var name: String
    /// T.ex. län och land, för att skilja orter med samma namn åt.
    var detail: String?
    var coordinate: Coordinate

    var id: String { "\(name)|\(coordinate.latitude)|\(coordinate.longitude)" }

    init(name: String, detail: String? = nil, coordinate: Coordinate) {
        self.name = name
        self.detail = detail
        self.coordinate = coordinate
    }

    /// Läser en ort sparad med `encoded`, eller nil.
    init?(data: Data) {
        guard let place = try? JSONDecoder().decode(Place.self, from: data) else { return nil }
        self = place
    }

    var encoded: Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}

/// Var vädret ska hämtas för.
enum LocationPreference: Equatable, Sendable {
    /// Telefonens position.
    case automatic
    /// En sökt ort, eller nil om användaren valt ort men inte sökt fram någon än.
    case manual(Place?)

    init(useManualPlace: Bool, placeData: Data) {
        self = useManualPlace ? .manual(Place(data: placeData)) : .automatic
    }
}

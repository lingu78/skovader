import Foundation

/// Uppslag i paketets Localizable.strings. Svenska är grundspråk; lägg till
/// t.ex. `nb.lproj` eller `en.lproj` bredvid `sv.lproj` för fler språk.
enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .module, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }
}

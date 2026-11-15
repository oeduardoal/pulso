import Foundation

/// Looks up `key` in the String Catalog and fills in `args` with the current locale.
/// Plural rules from the catalog apply when an integer argument selects a variant.
func L(_ key: String, _ args: any CVarArg...) -> String {
    let format = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    guard !args.isEmpty else { return format }
    return String(format: format, locale: Locale.current, arguments: args)
}

/// In-app language override. Applied through the app's own `AppleLanguages` and `AppleLocale`
/// defaults, which take effect on the next launch, so changing it relaunches the app.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case portuguese = "pt-BR"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L("settings.language.system")
        case .english: L("settings.language.english")
        case .portuguese: L("settings.language.portuguese")
        }
    }

    private var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .english: "en_US"
        case .portuguese: "pt_BR"
        }
    }

    static var current: AppLanguage {
        let stored = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?["AppleLanguages"] as? [String]
        return stored?.first.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    func apply() {
        let defaults = UserDefaults.standard
        if let localeIdentifier {
            defaults.set([rawValue], forKey: "AppleLanguages")
            defaults.set(localeIdentifier, forKey: "AppleLocale")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
            defaults.removeObject(forKey: "AppleLocale")
        }
    }
}

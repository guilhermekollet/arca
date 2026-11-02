import Foundation

/// The interface's language: Portuguese, English or Spanish, following the Mac, and English on a Mac
/// in any other language. The translations are in Resources/*.lproj, keyed by the Portuguese text.
enum Interface {
    /// The app carries the translations in Contents/Resources (build.sh copies them there); run
    /// straight from .build, they are in SwiftPM's resource bundle. Inside the app `Bundle.module`
    /// can't be used: it looks for that bundle at the root of the .app, where code signing doesn't
    /// allow it.
    static let resources: Bundle = Bundle.main.bundleURL.pathExtension == "app" ? .main : .module

    static let language = pickLanguage(from: resources.localizations, preferring: Locale.preferredLanguages)
    static let locale = Locale(identifier: language)

    /// The first of `available` that matches the Mac's `preferred` languages, in order: any
    /// Portuguese gets "pt-BR", any Spanish "es", and a language the app doesn't speak, English.
    static func pickLanguage(from available: [String], preferring preferred: [String]) -> String {
        Bundle.preferredLocalizations(from: available, forPreferences: preferred).first ?? "en"
    }

    /// The table for `language`, picked by hand: macOS localizes every bundle like the main one,
    /// which, run from .build, is a bare executable with no translations of its own.
    static let bundle = table(for: language) ?? resources

    /// The .lproj for `language`. SwiftPM writes "pt-br.lproj" in lowercase in its resource
    /// bundle, while the app (build.sh) keeps "pt-BR.lproj", so both spellings are tried.
    static func table(for language: String) -> Bundle? {
        (resources.path(forResource: language, ofType: "lproj") ?? resources.path(forResource: language.lowercased(), ofType: "lproj"))
            .flatMap(Bundle.init(path:))
    }
}

/// `text` in the interface's language. A missing translation shows the Portuguese original.
func localized(_ text: String.LocalizationValue) -> String {
    String(localized: text, bundle: Interface.bundle)
}

/// The app's name as the person reads it: "Chaves" on a Mac in Portuguese, where it means both the
/// keys and the { } of the icon, and "Keys" in every other language. Finder, the Dock and the app
/// menu get the same name from InfoPlist.strings.
var appName: String { localized("Chaves") }

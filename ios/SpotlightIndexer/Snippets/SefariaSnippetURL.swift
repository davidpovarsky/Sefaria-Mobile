import Foundation

@available(iOS 16.0, *)
enum SefariaSnippetURL {
  static func appURL(for rawValue: String, fallbackRef: String = "") -> URL? {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let fallback = fallbackRef.trimmingCharacters(in: .whitespacesAndNewlines)

    if value.hasPrefix("sefariareader://") {
      return URL(string: value)
    }

    if value.hasPrefix("https://www.sefaria.org/") || value.hasPrefix("http://www.sefaria.org/") {
      guard let webURL = URL(string: value) else {
        return fallbackURL(fallback)
      }

      let path = webURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let query = webURL.query.map { "?\($0)" } ?? ""

      if path.isEmpty {
        return fallbackURL(fallback)
      }

      return URL(string: "sefariareader://www.sefaria.org/\(path)\(query)")
    }

    if !value.isEmpty {
      return URL(string: SefariaIntentStore.url(forRef: value))
    }

    return fallbackURL(fallback)
  }

  static func searchURL(query: String) -> URL? {
    URL(string: SefariaIntentStore.searchURL(query: query))
  }

  private static func fallbackURL(_ fallbackRef: String) -> URL? {
    let fallback = fallbackRef.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !fallback.isEmpty else { return nil }
    return URL(string: SefariaIntentStore.url(forRef: fallback))
  }
}

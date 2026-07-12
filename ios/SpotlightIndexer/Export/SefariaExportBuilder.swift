import Foundation

@available(iOS 16.0, *)
enum SefariaExportBuilder {
  static func jsonData(searchResults: [SefariaSearchResult]) -> Data {
    let rows = searchResults.map { result in
      [
        "id": result.id,
        "ref": result.ref,
        "title": result.title,
        "snippet": SefariaSnippetFormatter.clean(result.snippet, maxLength: 1000),
        "url": normalizedAppURLString(rawValue: result.url, fallbackRef: result.ref)
      ]
    }

    return jsonData(rows)
  }

  static func jsonData(sources: [SefariaIntentSource]) -> Data {
    let rows = sources.map { source in
      [
        "id": source.id,
        "title": source.title,
        "path": source.path,
        "author": source.author,
        "url": normalizedAppURLString(rawValue: source.url, fallbackRef: source.title),
        "keywords": source.keywords
      ] as [String: Any]
    }

    return jsonData(rows)
  }

  static func vcfData(searchResults: [SefariaSearchResult]) -> Data {
    let cards = searchResults.map { result in
      vcard(
        fullName: SefariaSnippetFormatter.fallback(result.ref, result.title),
        organization: "Sefaria",
        note: [
          result.title,
          SefariaSnippetFormatter.clean(result.snippet, maxLength: 700)
        ].filter { !$0.isEmpty }.joined(separator: "\n"),
        url: normalizedAppURLString(rawValue: result.url, fallbackRef: result.ref)
      )
    }

    return cards.joined(separator: "\n").data(using: .utf8) ?? Data()
  }

  static func vcfData(sources: [SefariaIntentSource]) -> Data {
    let cards = sources.map { source in
      vcard(
        fullName: source.title,
        organization: "Sefaria",
        note: [
          source.path,
          source.author
        ].filter { !$0.isEmpty }.joined(separator: "\n"),
        url: normalizedAppURLString(rawValue: source.url, fallbackRef: source.title)
      )
    }

    return cards.joined(separator: "\n").data(using: .utf8) ?? Data()
  }

  private static func jsonData(_ object: Any) -> Data {
    (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])) ?? Data()
  }

  private static func normalizedAppURLString(rawValue: String, fallbackRef: String) -> String {
    SefariaSnippetURL.appURL(for: rawValue, fallbackRef: fallbackRef)?.absoluteString ?? ""
  }

  private static func vcard(fullName: String, organization: String, note: String, url: String) -> String {
    [
      "BEGIN:VCARD",
      "VERSION:3.0",
      "FN:\(escapeVCard(fullName))",
      "ORG:\(escapeVCard(organization))",
      note.isEmpty ? "" : "NOTE:\(escapeVCard(note))",
      url.isEmpty ? "" : "URL:\(escapeVCard(url))",
      "END:VCARD"
    ]
    .filter { !$0.isEmpty }
    .joined(separator: "\n")
  }

  private static func escapeVCard(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "")
      .replacingOccurrences(of: ";", with: "\\;")
      .replacingOccurrences(of: ",", with: "\\,")
  }
}

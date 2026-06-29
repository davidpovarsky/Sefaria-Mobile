import Foundation
import AppIntents
import UIKit

@available(iOS 16.0, *)
struct SefariaIntentSource: Identifiable, Hashable, Codable, AppEntity {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sefaria Source")
  static var defaultQuery = SefariaSourceQuery()

  let id: String
  let title: String
  let path: String
  let author: String
  let url: String
  let keywords: [String]

  var displayRepresentation: DisplayRepresentation {
    let subtitleParts = [path, author].filter { !$0.isEmpty }
    return DisplayRepresentation(
      title: LocalizedStringResource(stringLiteral: title),
      subtitle: LocalizedStringResource(stringLiteral: subtitleParts.joined(separator: " | "))
    )
  }
}

@available(iOS 16.0, *)
struct SefariaSearchResult: Identifiable, Hashable, Codable, AppEntity {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sefaria Search Result")
  static var defaultQuery = SefariaSearchResultQuery()

  let id: String
  let ref: String
  let title: String
  let snippet: String
  let url: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: LocalizedStringResource(stringLiteral: ref.isEmpty ? title : ref),
      subtitle: LocalizedStringResource(stringLiteral: snippet)
    )
  }
}

@available(iOS 16.0, *)
struct SefariaSourceQuery: EntityStringQuery {
  func entities(for identifiers: [SefariaIntentSource.ID]) async throws -> [SefariaIntentSource] {
    SefariaIntentStore.sources().filter { identifiers.contains($0.id) }
  }

  func entities(matching string: String) async throws -> [SefariaIntentSource] {
    SefariaIntentStore.findSources(query: string, limit: 50)
  }

  func suggestedEntities() async throws -> [SefariaIntentSource] {
    Array(SefariaIntentStore.sources().prefix(20))
  }
}

@available(iOS 16.0, *)
struct SefariaSearchResultQuery: EntityQuery {
  func entities(for identifiers: [SefariaSearchResult.ID]) async throws -> [SefariaSearchResult] {
    []
  }

  func suggestedEntities() async throws -> [SefariaSearchResult] {
    []
  }
}

struct SefariaIntentStore {
  static let sourcesKey = "SefariaIntentSourcesV1"
  static let stateKey = "SefariaIntentCurrentStateV1"
  static let baseURL = "https://www.sefaria.org/"

  static func readJSONArray(key: String) -> [[String: Any]] {
    guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
    do {
      return try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] ?? []
    } catch {
      return []
    }
  }

  static func readJSONDictionary(key: String) -> [String: Any] {
    guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
    do {
      return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
    } catch {
      return [:]
    }
  }

  @available(iOS 16.0, *)
  static func sources() -> [SefariaIntentSource] {
    readJSONArray(key: sourcesKey).compactMap { dict in
      let title = dict["title"] as? String ?? ""
      let url = dict["url"] as? String ?? ""
      if title.isEmpty || url.isEmpty { return nil }
      let keywords = dict["keywords"] as? [String] ?? []
      return SefariaIntentSource(
        id: dict["id"] as? String ?? url,
        title: title,
        path: dict["path"] as? String ?? "",
        author: dict["author"] as? String ?? "",
        url: url,
        keywords: keywords
      )
    }
  }

  @available(iOS 16.0, *)
  static func findSources(query: String, limit: Int = 20) -> [SefariaIntentSource] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let all = sources()
    if q.isEmpty { return Array(all.prefix(limit)) }
    let scored = all.map { source -> (SefariaIntentSource, Int) in
      let title = source.title.lowercased()
      let path = source.path.lowercased()
      let author = source.author.lowercased()
      let keywordText = source.keywords.joined(separator: " ").lowercased()
      var score = 0
      if title == q { score += 1000 }
      if title.hasPrefix(q) { score += 300 }
      if title.contains(q) { score += 150 }
      if author.contains(q) { score += 100 }
      if path.contains(q) { score += 60 }
      if keywordText.contains(q) { score += 40 }
      return (source, score)
    }.filter { $0.1 > 0 }.sorted { lhs, rhs in
      if lhs.1 == rhs.1 { return lhs.0.title < rhs.0.title }
      return lhs.1 > rhs.1
    }
    return Array(scored.prefix(limit).map { $0.0 })
  }

  static func currentState() -> [String: Any] {
    readJSONDictionary(key: stateKey)
  }

  static func stateString() -> String {
    let state = currentState()
    if state.isEmpty { return "No Sefaria state has been saved yet. Open the app once, then try again." }
    let keys = ["footerTab", "menuOpen", "textTitle", "textReference", "segmentRef", "currentRef", "searchType", "searchQuery", "isSearchOpen", "isHistoryOpen", "isSavedOpen", "textLanguage", "interfaceLanguage", "updatedAt"]
    return keys.compactMap { key in
      guard let value = state[key] else { return nil }
      return "\(key): \(value)"
    }.joined(separator: "\n")
  }

  static func currentRef() -> String {
    let state = currentState()
    return state["currentRef"] as? String ?? state["segmentRef"] as? String ?? state["textReference"] as? String ?? ""
  }

  static func currentURL() -> String {
    let state = currentState()
    if let url = state["currentUrl"] as? String, !url.isEmpty { return url }
    let ref = currentRef()
    return ref.isEmpty ? "" : url(forRef: ref)
  }

  static func url(forRef ref: String) -> String {
    let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") { return trimmed }
    let encoded = trimmed.replacingOccurrences(of: ":", with: ".").replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
    return baseURL + encoded
  }

  static func searchURL(query: String) -> String {
    let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    return baseURL + "search?q=" + encoded
  }

  @available(iOS 16.0, *)
  static func open(urlString: String) async {
    guard let url = URL(string: urlString) else { return }
    await MainActor.run {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }

  @available(iOS 16.0, *)
  static func searchTexts(query: String, limit: Int) async -> [SefariaSearchResult] {
    let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let candidateURLs = [
      "https://www.sefaria.org/api/search-wrapper?query=\(encoded)&type=text&size=\(limit)",
      "https://www.sefaria.org/api/search/text?query=\(encoded)&size=\(limit)",
      "https://www.sefaria.org/api/name/\(encoded)?limit=\(limit)"
    ]

    for urlString in candidateURLs {
      guard let url = URL(string: urlString) else { continue }
      do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 400 else { continue }
        let parsed = try JSONSerialization.jsonObject(with: data, options: [])
        let results = parseSearchResults(parsed, fallbackQuery: query, limit: limit)
        if !results.isEmpty { return results }
      } catch {
        continue
      }
    }
    return []
  }

  @available(iOS 16.0, *)
  static func parseSearchResults(_ object: Any, fallbackQuery: String, limit: Int) -> [SefariaSearchResult] {
    var rows: [[String: Any]] = []
    if let dict = object as? [String: Any] {
      for key in ["hits", "results", "text", "completion_objects"] {
        if let arr = dict[key] as? [[String: Any]] { rows = arr; break }
      }
      if rows.isEmpty, let nested = dict["hits"] as? [String: Any], let arr = nested["hits"] as? [[String: Any]] {
        rows = arr
      }
    } else if let arr = object as? [[String: Any]] {
      rows = arr
    }

    return Array(rows.prefix(limit).enumerated().map { idx, row in
      let source = row["_source"] as? [String: Any] ?? row
      let ref = source["ref"] as? String ?? source["title"] as? String ?? source["key"] as? String ?? source["text"] as? String ?? fallbackQuery
      let title = source["title"] as? String ?? source["book"] as? String ?? ref
      let snippet = source["highlight"] as? String ?? source["snippet"] as? String ?? source["he"] as? String ?? source["text"] as? String ?? ""
      let url = source["url"] as? String ?? url(forRef: ref)
      return SefariaSearchResult(id: "search:\(idx):\(ref)", ref: ref, title: title, snippet: snippet, url: url)
    })
  }
}

@available(iOS 16.0, *)
struct GetCurrentSefariaStateIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Current Sefaria State"
  static var description = IntentDescription("Returns the current visible state saved by the Sefaria app: tab, book, ref, search, history/saved state, and language.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    .result(value: SefariaIntentStore.stateString())
  }
}

@available(iOS 16.0, *)
struct GetCurrentSefariaRefIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Current Sefaria Ref"
  static var description = IntentDescription("Returns the current ref open in the Sefaria app.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    .result(value: SefariaIntentStore.currentRef())
  }
}

@available(iOS 16.0, *)
struct GetCurrentSefariaRefURLIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Current Sefaria Ref URL"
  static var description = IntentDescription("Returns the Sefaria URL for the current ref.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    .result(value: SefariaIntentStore.currentURL())
  }
}

@available(iOS 16.0, *)
struct OpenSefariaRefIntent: AppIntent {
  static var title: LocalizedStringResource = "Open Sefaria Ref"
  static var description = IntentDescription("Opens a full Sefaria ref in the app, including chapter, page, segment, or range when supplied.")
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Ref") var ref: String

  func perform() async throws -> some IntentResult {
    await SefariaIntentStore.open(urlString: SefariaIntentStore.url(forRef: ref))
    return .result()
  }
}

@available(iOS 16.0, *)
struct OpenSefariaSearchIntent: AppIntent {
  static var title: LocalizedStringResource = "Open Sefaria Search"
  static var description = IntentDescription("Opens the Sefaria app search screen with a query.")
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Query") var query: String

  func perform() async throws -> some IntentResult {
    await SefariaIntentStore.open(urlString: SefariaIntentStore.searchURL(query: query))
    return .result()
  }
}

@available(iOS 16.0, *)
struct FindSefariaSourcesIntent: AppIntent {
  static var title: LocalizedStringResource = "Find Sefaria Sources"
  static var description = IntentDescription("Searches the local Sefaria source index cache and returns matching sources without opening the app.")

  @Parameter(title: "Query") var query: String
  @Parameter(title: "Limit", default: 10) var limit: Int

  func perform() async throws -> some IntentResult & ReturnsValue<[SefariaIntentSource]> {
    .result(value: Array(SefariaIntentStore.findSources(query: query, limit: limit)))
  }
}

@available(iOS 16.0, *)
struct FindSefariaSourcesByAuthorIntent: AppIntent {
  static var title: LocalizedStringResource = "Find Sefaria Sources by Author"
  static var description = IntentDescription("Returns sources whose author field matches the query.")

  @Parameter(title: "Author") var author: String
  @Parameter(title: "Limit", default: 10) var limit: Int

  func perform() async throws -> some IntentResult & ReturnsValue<[SefariaIntentSource]> {
    let q = author.lowercased()
    let results = SefariaIntentStore.sources().filter { $0.author.lowercased().contains(q) }
    return .result(value: Array(results.prefix(limit)))
  }
}

@available(iOS 16.0, *)
struct FindSefariaSourcesInCategoryIntent: AppIntent {
  static var title: LocalizedStringResource = "Find Sefaria Sources in Category"
  static var description = IntentDescription("Returns sources whose path/category matches the query.")

  @Parameter(title: "Category") var category: String
  @Parameter(title: "Limit", default: 10) var limit: Int

  func perform() async throws -> some IntentResult & ReturnsValue<[SefariaIntentSource]> {
    let q = category.lowercased()
    let results = SefariaIntentStore.sources().filter { $0.path.lowercased().contains(q) }
    return .result(value: Array(results.prefix(limit)))
  }
}

@available(iOS 16.0, *)
struct SearchSefariaTextsIntent: AppIntent {
  static var title: LocalizedStringResource = "Search Sefaria Texts"
  static var description = IntentDescription("Runs an online Sefaria text search in the background and returns results to Shortcuts.")

  @Parameter(title: "Query") var query: String
  @Parameter(title: "Limit", default: 10) var limit: Int

  func perform() async throws -> some IntentResult & ReturnsValue<[SefariaSearchResult]> {
    let results = await SefariaIntentStore.searchTexts(query: query, limit: limit)
    return .result(value: results)
  }
}

@available(iOS 16.0, *)
struct RebuildSefariaSourceCacheIntent: AppIntent {
  static var title: LocalizedStringResource = "Rebuild Sefaria Source Cache"
  static var description = IntentDescription("Opens the app so the Spotlight/source cache can be rebuilt from the current Sefaria index.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult & ProvidesDialog {
    await SefariaIntentStore.open(urlString: SefariaIntentStore.baseURL)
    return .result(dialog: "Open Settings > Spotlight Search, then tap Update / Rebuild Spotlight Index.")
  }
}

@available(iOS 16.0, *)
struct SefariaShortcutsProvider: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(intent: GetCurrentSefariaStateIntent(), phrases: ["Get current state in \(.applicationName)"])
    AppShortcut(intent: GetCurrentSefariaRefIntent(), phrases: ["Get current ref in \(.applicationName)"])
    AppShortcut(intent: GetCurrentSefariaRefURLIntent(), phrases: ["Get current ref URL in \(.applicationName)"])
    AppShortcut(intent: OpenSefariaRefIntent(), phrases: ["Open ref in \(.applicationName)"])
    AppShortcut(intent: OpenSefariaSearchIntent(), phrases: ["Open search in \(.applicationName)"])
    AppShortcut(intent: FindSefariaSourcesIntent(), phrases: ["Find sources in \(.applicationName)"])
    AppShortcut(intent: FindSefariaSourcesByAuthorIntent(), phrases: ["Find sources by author in \(.applicationName)"])
    AppShortcut(intent: FindSefariaSourcesInCategoryIntent(), phrases: ["Find sources in category in \(.applicationName)"])
    AppShortcut(intent: SearchSefariaTextsIntent(), phrases: ["Search texts in \(.applicationName)"])
    AppShortcut(intent: RebuildSefariaSourceCacheIntent(), phrases: ["Rebuild source cache in \(.applicationName)"])
  }
}

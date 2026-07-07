import Foundation
import AppIntents

@available(iOS 16.0, *)
struct SearchSefariaTextsIntent: AppIntent {
  static var title: LocalizedStringResource = LocalizedStringResource("intent.search_texts.title", table: "AppShortcuts")
  static var description = IntentDescription(LocalizedStringResource("intent.search_texts.description", table: "AppShortcuts"))

  @Parameter(title: LocalizedStringResource("param.query", table: "AppShortcuts")) var query: String

  @Parameter(title: LocalizedStringResource("param.search_type", table: "AppShortcuts"), default: .text)
  var type: SefariaSearchTypeOption

  @Parameter(title: LocalizedStringResource("param.search_field", table: "AppShortcuts"), default: .smart)
  var field: SefariaSearchFieldOption

  @Parameter(title: LocalizedStringResource("param.size", table: "AppShortcuts"), default: 10)
  var size: Int

  @Parameter(title: LocalizedStringResource("param.slop", table: "AppShortcuts"), default: 10)
  var slop: Int

  @Parameter(title: LocalizedStringResource("param.advanced_filters", table: "AppShortcuts"), default: "")
  var filters: String

  @Parameter(title: LocalizedStringResource("param.advanced_filter_fields", table: "AppShortcuts"), default: "")
  var filterFields: String

  @Parameter(title: LocalizedStringResource("param.search_aggregation", table: "AppShortcuts"), default: .path)
  var aggregations: SefariaSearchAggregationOption

  @Parameter(title: LocalizedStringResource("param.source_projection", table: "AppShortcuts"), default: true)
  var sourceProjection: Bool

  func perform() async throws -> some IntentResult & ReturnsValue<[SefariaSearchResult]> & ProvidesDialog & ShowsSnippetView {
    let results = await SefariaSearchWrapperClient.search(
      query: query,
      type: type.rawValue,
      field: field.rawValue,
      size: size,
      slop: slop,
      filters: filters,
      filterFields: filterFields,
      sortMethod: "score",
      sortFields: "pagesheetrank",
      sortReverse: false,
      sortScoreMissing: 0.04,
      sourceProjection: sourceProjection,
      aggregations: aggregations.rawValue
    )

    return .result(
      value: results,
      dialog: SefariaIntentDialogs.textSearch(query: query, count: results.count)
    ) {
      SefariaSearchResultsSnippetView(query: query, results: results)
    }
  }
}

struct SefariaSearchWrapperClient {
  static func splitCSV(_ value: String) -> [String] {
    value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
  }

  @available(iOS 16.0, *)
  static func search(query: String, type: String, field: String, size: Int, slop: Int, filters: String, filterFields: String, sortMethod: String, sortFields: String, sortReverse: Bool, sortScoreMissing: Double, sourceProjection: Bool, aggregations: String) async -> [SefariaSearchResult] {
    guard let url = URL(string: "https://www.sefaria.org/api/search-wrapper") else { return [] }
    let searchField = field.isEmpty ? "naive_lemmatizer" : field
    var body: [String: Any] = [
      "query": query,
      "type": type.isEmpty ? "text" : type,
      "field": searchField,
      "size": max(1, size),
      "slop": max(0, slop),
      "sort_method": sortMethod.isEmpty ? "score" : sortMethod,
      "sort_reverse": sortReverse,
      "sort_score_missing": sortScoreMissing,
      "source_proj": sourceProjection
    ]
    let sortList = splitCSV(sortFields)
    body["sort_fields"] = sortList.isEmpty ? ["pagesheetrank"] : sortList
    let filterList = splitCSV(filters)
    if !filterList.isEmpty { body["filters"] = filterList }
    let filterFieldList = splitCSV(filterFields)
    if !filterFieldList.isEmpty { body["filter_fields"] = filterFieldList }
    let aggList = splitCSV(aggregations)
    if !aggList.isEmpty { body["aggs"] = aggList }

    do {
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("application/json", forHTTPHeaderField: "Accept")
      request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 400 else { return [] }
      let parsed = try JSONSerialization.jsonObject(with: data, options: [])
      return parse(parsed, fallbackQuery: query, limit: max(1, size), highlightField: searchField)
    } catch {
      return []
    }
  }

  @available(iOS 16.0, *)
  static func parse(_ object: Any, fallbackQuery: String, limit: Int, highlightField: String) -> [SefariaSearchResult] {
    var rows: [[String: Any]] = []
    if let dict = object as? [String: Any], let hits = dict["hits"] as? [String: Any], let arr = hits["hits"] as? [[String: Any]] {
      rows = arr
    } else if let dict = object as? [String: Any], let arr = dict["results"] as? [[String: Any]] {
      rows = arr
    } else if let arr = object as? [[String: Any]] {
      rows = arr
    }
    return Array(rows.prefix(limit).enumerated().map { idx, row in
      let source = row["_source"] as? [String: Any] ?? row
      let highlight = row["highlight"] as? [String: Any] ?? [:]
      let highlightValues = (highlight[highlightField] as? [String]) ?? highlight.values.compactMap { $0 as? [String] }.flatMap { $0 }
      let ref = source["ref"] as? String ?? source["title"] as? String ?? source["key"] as? String ?? fallbackQuery
      let exact = source["exact"] as? String ?? ""
      let naive = source["naive_lemmatizer"] as? String ?? ""
      let snippet = highlightValues.first ?? (exact.isEmpty ? String(naive.prefix(450)) : String(exact.prefix(450)))
      let title = source["book"] as? String ?? source["index"] as? String ?? source["title"] as? String ?? ref
      let path = source["path"] as? String ?? (source["categories"] as? [String] ?? []).joined(separator: "/")
      let details = [source["heRef"] as? String ?? "", path, snippet].filter { !$0.isEmpty }.joined(separator: " | ")
      let url = "https://www.sefaria.org/" + ref.replacingOccurrences(of: ":", with: ".").replacingOccurrences(of: " ", with: "_")
      return SefariaSearchResult(id: "post-search:\(idx):\(ref)", ref: ref, title: title, snippet: details, url: url)
    })
  }
}

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct SefariaNameResult: Identifiable, Hashable, Codable, AppEntity {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sefaria Name Result")
  static var defaultQuery = SefariaNameResultQuery()

  let id: String
  let title: String
  let key: String
  let resultType: String
  let ref: String
  let url: String
  let isPrimary: Bool
  let order: Int

  var displayRepresentation: DisplayRepresentation {
    let subtitle = [resultType, key.isEmpty ? ref : key].filter { !$0.isEmpty }.joined(separator: " | ")
    return DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title), subtitle: LocalizedStringResource(stringLiteral: subtitle))
  }
}

@available(iOS 16.0, *)
struct SefariaNameResultQuery: EntityQuery {
  func entities(for identifiers: [SefariaNameResult.ID]) async throws -> [SefariaNameResult] { [] }
  func suggestedEntities() async throws -> [SefariaNameResult] { [] }
}

@available(iOS 16.0, *)
struct LookupSefariaNameIntent: AppIntent {
  static var title: LocalizedStringResource = "Lookup Sefaria Name"
  static var description = IntentDescription("Autocompletes refs, book titles, authors, topics, collections, categories, terms, and people using Sefaria's Name API.")

  @Parameter(title: "Name") var name: String
  @Parameter(title: "Limit", default: 10) var limit: Int
  @Parameter(title: "Type Filter", default: "") var type: String

  func perform() async throws -> some IntentResult & ReturnsValue<[SefariaNameResult]> {
    let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
    var components = URLComponents(string: "https://www.sefaria.org/api/name/\(encodedName)")
    var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
    let trimmedType = type.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedType.isEmpty { queryItems.append(URLQueryItem(name: "type", value: trimmedType)) }
    components?.queryItems = queryItems
    guard let url = components?.url else { return .result(value: []) }

    do {
      let (data, response) = try await URLSession.shared.data(from: url)
      guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 400 else { return .result(value: []) }
      let parsed = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
      let responseRef = parsed["ref"] as? String ?? ""
      let responseURL = parsed["url"] as? String ?? ""
      let objects = parsed["completion_objects"] as? [[String: Any]] ?? []
      let baseWebURL = "https://www.sefaria.org/"
      let results = Array(objects.prefix(max(1, limit)).enumerated().map { idx, obj in
        let title = obj["title"] as? String ?? ""
        let key = obj["key"] as? String ?? title
        let resultType = obj["type"] as? String ?? parsed["type"] as? String ?? ""
        let objectURL = obj["url"] as? String ?? responseURL
        let ref = resultType == "ref" ? key : responseRef
        let urlString = objectURL.isEmpty ? (ref.isEmpty ? "" : baseWebURL + ref.replacingOccurrences(of: " ", with: "_")) : baseWebURL + objectURL
        return SefariaNameResult(id: "name:\(idx):\(resultType):\(key)", title: title, key: key, resultType: resultType, ref: ref, url: urlString, isPrimary: obj["is_primary"] as? Bool ?? false, order: obj["order"] as? Int ?? 0)
      })
      return .result(value: results)
    } catch {
      return .result(value: [])
    }
  }
}

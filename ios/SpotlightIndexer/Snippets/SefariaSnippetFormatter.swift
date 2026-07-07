import Foundation

@available(iOS 16.0, *)
enum SefariaSnippetFormatter {
  static func clean(_ value: String, maxLength: Int = 280) -> String {
    let withoutHTML = stripHTML(value)
    let normalized = withoutHTML
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\t", with: " ")
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if normalized.count <= maxLength {
      return normalized
    }

    let index = normalized.index(normalized.startIndex, offsetBy: maxLength)
    return String(normalized[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
  }

  static func stripHTML(_ value: String) -> String {
    guard let data = value.data(using: .utf8) else {
      return value
    }

    if let attributed = try? NSAttributedString(
      data: data,
      options: [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue
      ],
      documentAttributes: nil
    ) {
      return attributed.string
    }

    return value.replacingOccurrences(
      of: "<[^>]+>",
      with: "",
      options: .regularExpression
    )
  }

  static func countText(_ count: Int, singular: String, plural: String) -> String {
    count == 1 ? singular : plural
  }

  static func fallback(_ value: String, _ fallback: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? fallback : trimmed
  }
}

import Foundation
import AppIntents

@available(iOS 16.0, *)
enum SefariaIntentFileBuilder {
  static func file(data: Data, baseName: String, format: SefariaExportFormat) -> IntentFile {
    let safeBaseName = sanitizeFileName(baseName)
    let fileName = "\(safeBaseName).\(format.fileExtension)"

    return IntentFile(
      data: data,
      filename: fileName,
      type: format.contentTypeIdentifier
    )
  }

  private static func sanitizeFileName(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

    let base = trimmed.isEmpty ? "sefaria-results" : trimmed

    let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
    let cleaned = base
      .components(separatedBy: invalid)
      .joined(separator: "-")
      .replacingOccurrences(of: " ", with: "-")
      .lowercased()

    return cleaned.isEmpty ? "sefaria-results" : String(cleaned.prefix(80))
  }
}

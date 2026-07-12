import Foundation
import AppIntents

@available(iOS 16.0, *)
struct ExportSefariaSourcesByAuthorIntent: AppIntent {
  static var title: LocalizedStringResource = LocalizedStringResource("intent.export_sources_author.title", table: "AppShortcuts")
  static var description = IntentDescription(LocalizedStringResource("intent.export_sources_author.description", table: "AppShortcuts"))

  @Parameter(title: LocalizedStringResource("param.author", table: "AppShortcuts"))
  var author: String

  @Parameter(title: LocalizedStringResource("param.limit", table: "AppShortcuts"), default: 10)
  var limit: Int

  @Parameter(title: LocalizedStringResource("param.output_format", table: "AppShortcuts"), default: .json)
  var outputFormat: SefariaExportFormat

  func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
    let q = author.lowercased()
    let results = Array(SefariaIntentStore.sources().filter { $0.author.lowercased().contains(q) }.prefix(limit))

    let data: Data
    switch outputFormat {
    case .json:
      data = SefariaExportBuilder.jsonData(sources: results)
    case .vcf:
      data = SefariaExportBuilder.vcfData(sources: results)
    }

    let file = SefariaIntentFileBuilder.file(
      data: data,
      baseName: "sefaria-sources-by-author-\(author)",
      format: outputFormat
    )

    return .result(value: file)
  }
}

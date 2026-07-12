import Foundation
import AppIntents

@available(iOS 16.0, *)
struct ExportSefariaSourcesIntent: AppIntent {
  static var title: LocalizedStringResource = LocalizedStringResource("intent.export_sources.title", table: "AppShortcuts")
  static var description = IntentDescription(LocalizedStringResource("intent.export_sources.description", table: "AppShortcuts"))

  @Parameter(title: LocalizedStringResource("param.query", table: "AppShortcuts"))
  var query: String

  @Parameter(title: LocalizedStringResource("param.limit", table: "AppShortcuts"), default: 10)
  var limit: Int

  @Parameter(title: LocalizedStringResource("param.output_format", table: "AppShortcuts"), default: .json)
  var outputFormat: SefariaExportFormat

  func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
    let results = Array(SefariaIntentStore.findSources(query: query, limit: limit))

    let data: Data
    switch outputFormat {
    case .json:
      data = SefariaExportBuilder.jsonData(sources: results)
    case .vcf:
      data = SefariaExportBuilder.vcfData(sources: results)
    }

    let file = SefariaIntentFileBuilder.file(
      data: data,
      baseName: "sefaria-sources-\(query)",
      format: outputFormat
    )

    return .result(value: file)
  }
}

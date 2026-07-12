import Foundation
import AppIntents

@available(iOS 16.0, *)
struct ExportSefariaTextSearchIntent: AppIntent {
  static var title: LocalizedStringResource = LocalizedStringResource("intent.export_text_search.title", table: "AppShortcuts")
  static var description = IntentDescription(LocalizedStringResource("intent.export_text_search.description", table: "AppShortcuts"))

  @Parameter(title: LocalizedStringResource("param.query", table: "AppShortcuts"))
  var query: String

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

  @Parameter(title: LocalizedStringResource("param.output_format", table: "AppShortcuts"), default: .json)
  var outputFormat: SefariaExportFormat

  func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
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

    let data: Data
    switch outputFormat {
    case .json:
      data = SefariaExportBuilder.jsonData(searchResults: results)
    case .vcf:
      data = SefariaExportBuilder.vcfData(searchResults: results)
    }

    let file = SefariaIntentFileBuilder.file(
      data: data,
      baseName: "sefaria-text-search-\(query)",
      format: outputFormat
    )

    return .result(value: file)
  }
}

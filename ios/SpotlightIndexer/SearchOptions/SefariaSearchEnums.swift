import Foundation
import AppIntents

@available(iOS 16.0, *)
enum SefariaSearchTypeOption: String, AppEnum {
  case text = "text"

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: LocalizedStringResource("enum.search_type.name", table: "AppShortcuts")
  )

  static var caseDisplayRepresentations: [SefariaSearchTypeOption: DisplayRepresentation] = [
    .text: DisplayRepresentation(
      title: LocalizedStringResource("enum.search_type.text.title", table: "AppShortcuts"),
      subtitle: LocalizedStringResource("enum.search_type.text.subtitle", table: "AppShortcuts")
    )
  ]
}

@available(iOS 16.0, *)
enum SefariaSearchFieldOption: String, AppEnum {
  case smart = "naive_lemmatizer"
  case exact = "exact"

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: LocalizedStringResource("enum.search_field.name", table: "AppShortcuts")
  )

  static var caseDisplayRepresentations: [SefariaSearchFieldOption: DisplayRepresentation] = [
    .smart: DisplayRepresentation(
      title: LocalizedStringResource("enum.search_field.smart.title", table: "AppShortcuts"),
      subtitle: LocalizedStringResource("enum.search_field.smart.subtitle", table: "AppShortcuts")
    ),
    .exact: DisplayRepresentation(
      title: LocalizedStringResource("enum.search_field.exact.title", table: "AppShortcuts"),
      subtitle: LocalizedStringResource("enum.search_field.exact.subtitle", table: "AppShortcuts")
    )
  ]
}

@available(iOS 16.0, *)
enum SefariaSearchAggregationOption: String, AppEnum {
  case path = "path"
  case none = ""

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: LocalizedStringResource("enum.search_aggregation.name", table: "AppShortcuts")
  )

  static var caseDisplayRepresentations: [SefariaSearchAggregationOption: DisplayRepresentation] = [
    .path: DisplayRepresentation(
      title: LocalizedStringResource("enum.search_aggregation.path.title", table: "AppShortcuts"),
      subtitle: LocalizedStringResource("enum.search_aggregation.path.subtitle", table: "AppShortcuts")
    ),
    .none: DisplayRepresentation(
      title: LocalizedStringResource("enum.search_aggregation.none.title", table: "AppShortcuts"),
      subtitle: LocalizedStringResource("enum.search_aggregation.none.subtitle", table: "AppShortcuts")
    )
  ]
}

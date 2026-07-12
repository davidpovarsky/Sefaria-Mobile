import Foundation
import AppIntents
import UniformTypeIdentifiers

@available(iOS 16.0, *)
enum SefariaExportFormat: String, AppEnum {
  case json = "json"
  case vcf = "vcf"

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: LocalizedStringResource("enum.export_format.name", table: "AppShortcuts")
  )

  static var caseDisplayRepresentations: [SefariaExportFormat: DisplayRepresentation] = [
    .json: DisplayRepresentation(
      title: LocalizedStringResource("enum.export_format.json.title", table: "AppShortcuts"),
      subtitle: LocalizedStringResource("enum.export_format.json.subtitle", table: "AppShortcuts")
    ),
    .vcf: DisplayRepresentation(
      title: LocalizedStringResource("enum.export_format.vcf.title", table: "AppShortcuts"),
      subtitle: LocalizedStringResource("enum.export_format.vcf.subtitle", table: "AppShortcuts")
    )
  ]

  var fileExtension: String {
    switch self {
    case .json:
      return "json"
    case .vcf:
      return "vcf"
    }
  }

  var contentType: UTType {
    switch self {
    case .json:
      return UTType(filenameExtension: "json") ?? .data
    case .vcf:
      return UTType(filenameExtension: "vcf") ?? UTType(importedAs: "public.vcard")
    }
  }
}

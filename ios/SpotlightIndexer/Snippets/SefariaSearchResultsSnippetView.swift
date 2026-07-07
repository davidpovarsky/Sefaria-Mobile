import SwiftUI

@available(iOS 16.0, *)
struct SefariaSearchResultsSnippetView: View {
  let query: String
  let results: [SefariaSearchResult]

  private let maxVisibleResults = 5

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SefariaSnippetHeaderView(
        systemImage: "magnifyingglass",
        title: "Sefaria Text Search",
        subtitle: query,
        count: results.count
      )

      if results.isEmpty {
        Text("No text results found.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(Array(results.prefix(maxVisibleResults).enumerated()), id: \.element.id) { index, result in
            SefariaSearchResultRowView(result: result, index: index)

            if index < min(results.count, maxVisibleResults) - 1 {
              Divider()
            }
          }
        }

        if results.count > maxVisibleResults {
          Text("+ \(results.count - maxVisibleResults) more")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding()
  }
}

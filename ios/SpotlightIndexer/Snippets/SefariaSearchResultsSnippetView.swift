import SwiftUI

@available(iOS 16.0, *)
struct SefariaSearchResultsSnippetView: View {
  let query: String
  let results: [SefariaSearchResult]

  @State private var isExpanded = false

  private let maxVisibleResults = 5

  private var visibleResults: [SefariaSearchResult] {
    if isExpanded {
      return results
    }

    return Array(results.prefix(maxVisibleResults))
  }

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
          ForEach(Array(visibleResults.enumerated()), id: \.element.id) { index, result in
            SefariaSearchResultRowView(result: result, index: index)

            if index < visibleResults.count - 1 {
              Divider()
            }
          }
        }

        if results.count > maxVisibleResults {
          Button {
            isExpanded.toggle()
          } label: {
            Text(isExpanded ? "Show fewer" : "Show \(results.count - maxVisibleResults) more")
              .font(.caption)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding()
  }
}

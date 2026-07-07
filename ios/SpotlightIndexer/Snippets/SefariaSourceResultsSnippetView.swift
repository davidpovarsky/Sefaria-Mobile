import SwiftUI

@available(iOS 16.0, *)
struct SefariaSourceResultsSnippetView: View {
  let query: String
  let title: String
  let sources: [SefariaIntentSource]

  private let maxVisibleResults = 6

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SefariaSnippetHeaderView(
        systemImage: "books.vertical",
        title: title,
        subtitle: query,
        count: sources.count
      )

      if sources.isEmpty {
        Text("No sources found.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(Array(sources.prefix(maxVisibleResults).enumerated()), id: \.element.id) { index, source in
            SefariaSourceResultRowView(source: source, index: index)

            if index < min(sources.count, maxVisibleResults) - 1 {
              Divider()
            }
          }
        }

        if sources.count > maxVisibleResults {
          Text("+ \(sources.count - maxVisibleResults) more")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding()
  }
}

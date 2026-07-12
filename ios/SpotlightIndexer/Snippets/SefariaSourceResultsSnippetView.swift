import SwiftUI

@available(iOS 16.0, *)
struct SefariaSourceResultsSnippetView: View {
  let query: String
  let title: String
  let sources: [SefariaIntentSource]

  @State private var isExpanded = false

  private let maxVisibleResults = 6

  private var visibleSources: [SefariaIntentSource] {
    if isExpanded {
      return sources
    }

    return Array(sources.prefix(maxVisibleResults))
  }

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
          ForEach(Array(visibleSources.enumerated()), id: \.element.id) { index, source in
            SefariaSourceResultRowView(source: source, index: index)

            if index < visibleSources.count - 1 {
              Divider()
            }
          }
        }

        if sources.count > maxVisibleResults {
          Button {
            isExpanded.toggle()
          } label: {
            Text(isExpanded ? "Show fewer" : "Show \(sources.count - maxVisibleResults) more")
              .font(.caption)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding()
  }
}

import SwiftUI

@available(iOS 16.0, *)
struct SefariaSearchResultRowView: View {
  let result: SefariaSearchResult
  let index: Int

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text("\(index + 1)")
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: 22, alignment: .trailing)

      VStack(alignment: .leading, spacing: 4) {
        Text(SefariaSnippetFormatter.fallback(result.ref, result.title))
          .font(.subheadline.weight(.semibold))
          .lineLimit(2)

        if !result.title.isEmpty && result.title != result.ref {
          Text(result.title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        let snippet = SefariaSnippetFormatter.clean(result.snippet)
        if !snippet.isEmpty {
          Text(snippet)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
      }

      Spacer(minLength: 0)
    }
  }
}

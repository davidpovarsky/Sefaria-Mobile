import SwiftUI

@available(iOS 16.0, *)
struct SefariaSnippetHeaderView: View {
  let systemImage: String
  let title: String
  let subtitle: String
  let count: Int

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: systemImage)
        .font(.title2)
        .symbolRenderingMode(.hierarchical)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
          .lineLimit(2)

        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Text("\(count) result\(count == 1 ? "" : "s")")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)
    }
  }
}

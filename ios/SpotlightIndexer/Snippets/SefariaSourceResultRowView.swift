import SwiftUI

@available(iOS 16.0, *)
struct SefariaSourceResultRowView: View {
  let source: SefariaIntentSource
  let index: Int

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text("\(index + 1)")
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: 22, alignment: .trailing)

      VStack(alignment: .leading, spacing: 4) {
        Text(source.title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(2)

        if !source.path.isEmpty {
          Text(source.path)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        if !source.author.isEmpty {
          Text(source.author)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 0)
    }
  }
}

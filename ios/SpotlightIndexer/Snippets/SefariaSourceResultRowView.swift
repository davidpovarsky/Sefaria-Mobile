import SwiftUI

@available(iOS 16.0, *)
struct SefariaSourceResultRowView: View {
  let source: SefariaIntentSource
  let index: Int

  var body: some View {
    if let destination = SefariaSnippetURL.appURL(for: source.url, fallbackRef: source.title) {
      Link(destination: destination) {
        SefariaSourceResultRowContentView(source: source, index: index)
      }
      .buttonStyle(.plain)
    } else {
      SefariaSourceResultRowContentView(source: source, index: index)
    }
  }
}

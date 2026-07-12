import SwiftUI

@available(iOS 16.0, *)
struct SefariaSearchResultRowView: View {
  let result: SefariaSearchResult
  let index: Int

  var body: some View {
    if let destination = SefariaSnippetURL.appURL(for: result.url, fallbackRef: result.ref) {
      Link(destination: destination) {
        SefariaSearchResultRowContentView(result: result, index: index)
      }
      .buttonStyle(.plain)
    } else {
      SefariaSearchResultRowContentView(result: result, index: index)
    }
  }
}

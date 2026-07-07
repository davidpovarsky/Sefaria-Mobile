import Foundation
import AppIntents

@available(iOS 16.0, *)
enum SefariaIntentDialogs {
  static func textSearch(query: String, count: Int) -> IntentDialog {
    if count == 0 {
      return IntentDialog("No text results found for \(query).")
    }

    if count == 1 {
      return IntentDialog("Found 1 text result for \(query).")
    }

    return IntentDialog("Found \(count) text results for \(query).")
  }

  static func sourceSearch(query: String, count: Int) -> IntentDialog {
    if count == 0 {
      return IntentDialog("No sources found for \(query).")
    }

    if count == 1 {
      return IntentDialog("Found 1 source for \(query).")
    }

    return IntentDialog("Found \(count) sources for \(query).")
  }

  static func sourceAuthorSearch(author: String, count: Int) -> IntentDialog {
    if count == 0 {
      return IntentDialog("No sources found for author \(author).")
    }

    if count == 1 {
      return IntentDialog("Found 1 source for author \(author).")
    }

    return IntentDialog("Found \(count) sources for author \(author).")
  }

  static func sourceCategorySearch(category: String, count: Int) -> IntentDialog {
    if count == 0 {
      return IntentDialog("No sources found in category \(category).")
    }

    if count == 1 {
      return IntentDialog("Found 1 source in category \(category).")
    }

    return IntentDialog("Found \(count) sources in category \(category).")
  }
}

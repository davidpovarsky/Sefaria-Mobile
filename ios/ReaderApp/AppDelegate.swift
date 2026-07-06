import UIKit
import Expo
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider
import CoreSpotlight

import TSBackgroundFetch
import RNBootSplash

@main
class AppDelegate: ExpoAppDelegate {
  private let sefariaMenuCommandsKey = "SefariaMenuCommandsV1"
  var window: UIWindow?

  var reactNativeDelegate: ReactNativeDelegate?
  var reactNativeFactory: RCTReactNativeFactory?

  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return super.application(app, open: url, options: options)
      || RCTLinkingManager.application(app, open: url, options: options)
  }

  override func application(
  _ application: UIApplication,
  continue userActivity: NSUserActivity,
  restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    if userActivity.activityType == CSSearchableItemActionType,
       let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
       let url = URL(string: identifier) {
      NSLog("[SpotlightIndexer] Opening Spotlight item: \(identifier)")
      return self.application(application, open: url, options: [:])
    }

    let result = RCTLinkingManager.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
      || result
  }

  override func application(_ application: UIApplication,
                            performActionFor shortcutItem: UIApplicationShortcutItem,
                            completionHandler: @escaping (Bool) -> Void) {
    let urlString = shortcutItem.userInfo?["url"] as? String
    if let urlString = urlString, let url = URL(string: urlString) {
      NSLog("[SefariaQuickActions] Opening quick action \(shortcutItem.type): \(urlString)")
      let handled = self.application(application, open: url, options: [:])
      completionHandler(handled)
      return
    }
    NSLog("[SefariaQuickActions] Quick action had no URL: \(shortcutItem.type)")
    completionHandler(false)
  }

  override func buildMenu(with builder: UIMenuBuilder) {
    super.buildMenu(with: builder)
    guard builder.system == .main else { return }

    let menus = sefariaMenuSections().compactMap { buildSefariaMenu(from: $0) }
    guard !menus.isEmpty else { return }

    var previousIdentifier = UIMenu.Identifier.application
    for menu in menus {
      builder.insertSibling(menu, afterMenu: previousIdentifier)
      previousIdentifier = menu.identifier
    }
  }

  private func sefariaMenuSections() -> [[String: Any]] {
    guard let data = UserDefaults.standard.data(forKey: sefariaMenuCommandsKey) else { return [] }
    do {
      return try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] ?? []
    } catch {
      NSLog("[SefariaMenuCommands] Failed to decode menu JSON: \(error.localizedDescription)")
      return []
    }
  }

  private func buildSefariaMenu(from dictionary: [String: Any]) -> UIMenu? {
    guard let title = dictionary["title"] as? String, !title.isEmpty else { return nil }
    let id = dictionary["id"] as? String ?? title
    let children = (dictionary["children"] as? [[String: Any]] ?? []).compactMap { buildSefariaMenuElement(from: $0) }
    guard !children.isEmpty else { return nil }
    return UIMenu(
      title: title,
      image: nil,
      identifier: UIMenu.Identifier("org.sefaria.menu.\(id)"),
      options: [],
      children: children
    )
  }

  private func buildSefariaMenuElement(from dictionary: [String: Any]) -> UIMenuElement? {
    guard let title = dictionary["title"] as? String, !title.isEmpty else { return nil }
    let id = dictionary["id"] as? String ?? title
    if let childDictionaries = dictionary["children"] as? [[String: Any]], !childDictionaries.isEmpty {
      let children = childDictionaries.compactMap { buildSefariaMenuElement(from: $0) }
      guard !children.isEmpty else { return nil }
      return UIMenu(
        title: title,
        image: nil,
        identifier: UIMenu.Identifier("org.sefaria.menu.\(id)"),
        options: [],
        children: children
      )
    }

    return UIAction(
      title: title,
      image: nil,
      identifier: UIAction.Identifier("org.sefaria.menu.action.\(id)"),
      discoverabilityTitle: nil,
      attributes: [],
      state: .off
    ) { [weak self] _ in
      self?.performSefariaMenuCommand(dictionary)
    }
  }

  private func performSefariaMenuCommand(_ command: [String: Any]) {
    let action = command["action"] as? String
    let urlString = command["url"] as? String ?? ""

    if action == "copy" {
      let text = command["text"] as? String ?? urlString
      if !text.isEmpty {
        UIPasteboard.general.string = text
      }
      return
    }

    guard let url = URL(string: urlString) else { return }
    if action == "openExternal" {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
      return
    }

    if url.scheme == "sefariareader" {
      _ = self.application(UIApplication.shared, open: url, options: [:])
    } else {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let delegate = ReactNativeDelegate()
    let factory = ExpoReactNativeFactory(delegate: delegate)
    delegate.dependencyProvider = RCTAppDependencyProvider()

    reactNativeDelegate = delegate
    reactNativeFactory = factory
    bindReactNativeFactory(factory)

    window = UIWindow(frame: UIScreen.main.bounds)

    factory.startReactNative(
      withModuleName: "ReaderApp",
      in: window,
      launchOptions: launchOptions
    )

    TSBackgroundFetch.sharedInstance().didFinishLaunching()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class ReactNativeDelegate: ExpoReactNativeFactoryDelegate {
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    // needed to return the correct URL for expo-dev-client.
    bridge.bundleURL ?? bundleURL()
  }

  override func bundleURL() -> URL? {
#if DEBUG
    RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: ".expo/.virtual-metro-entry")
#else
    Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }

  override func customize(_ rootView: RCTRootView!) {
    super.customize(rootView)
    RNBootSplash.initWithStoryboard("Launch Screen", rootView: rootView) // ⬅️ initialize the splash screen
  }
}

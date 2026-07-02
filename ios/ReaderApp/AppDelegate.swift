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
  var window: UIWindow?

  var reactNativeDelegate: ReactNativeDelegate?
  var reactNativeFactory: RCTReactNativeFactory?

  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if url.isFileURL && (url.pathExtension == "sefref" || url.pathExtension == "sefsearch") {
      return routeSefariaRecentDocument(app, fileURL: url, options: options)
    }
    return super.application(app, open: url, options: options)
      || RCTLinkingManager.application(app, open: url, options: options)
  }

  private func routeSefariaRecentDocument(_ app: UIApplication, fileURL url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
    NSLog("[SefariaDocumentRecents] Opening recent document: \(url.path)")
    do {
      let data = try Data(contentsOf: url)
      guard
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
        let urlString = json["url"] as? String,
        let deepLinkURL = URL(string: urlString),
        !deepLinkURL.isFileURL
      else {
        NSLog("[SefariaDocumentRecents] Could not route recent document: missing or invalid url")
        return false
      }
      NSLog("[SefariaDocumentRecents] Routing document to: \(deepLinkURL.absoluteString)")
      return RCTLinkingManager.application(app, open: deepLinkURL, options: options)
    } catch {
      NSLog("[SefariaDocumentRecents] Failed to read recent document: \(error.localizedDescription)")
      return false
    }
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

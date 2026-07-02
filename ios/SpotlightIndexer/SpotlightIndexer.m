#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreSpotlight/CoreSpotlight.h>
#import <React/RCTBridgeModule.h>

static NSString * const SefariaSpotlightDomain = @"org.sefaria.reader.sources";
static NSString * const SefariaIntentSourcesKey = @"SefariaIntentSourcesV1";
static NSString * const SefariaIntentStateKey = @"SefariaIntentCurrentStateV1";

@interface SpotlightIndexer : NSObject <RCTBridgeModule>
@end

@implementation SpotlightIndexer

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

+ (void)saveJSONArray:(NSArray *)array key:(NSString *)key
{
  if (!array) { return; }
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:array options:0 error:&error];
  if (error || !data) {
    NSLog(@"[SefariaIntentsStore] Failed to serialize array for %@: %@", key, error);
    return;
  }
  [[NSUserDefaults standardUserDefaults] setObject:data forKey:key];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)saveJSONDictionary:(NSDictionary *)dict key:(NSString *)key
{
  if (!dict) { return; }
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
  if (error || !data) {
    NSLog(@"[SefariaIntentsStore] Failed to serialize dictionary for %@: %@", key, error);
    return;
  }
  [[NSUserDefaults standardUserDefaults] setObject:data forKey:key];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (UIApplicationShortcutIcon *)shortcutIconForName:(NSString *)name
{
  if ([name isEqualToString:@"search"]) { return [UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeSearch]; }
  if ([name isEqualToString:@"play"]) { return [UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypePlay]; }
  if ([name isEqualToString:@"bookmark"]) { return [UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeBookmark]; }
  if ([name isEqualToString:@"history"]) { return [UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeTime]; }
  if ([name isEqualToString:@"settings"]) { return [UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeCompose]; }
  if ([name isEqualToString:@"shuffle"]) { return [UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeShuffle]; }
  return [UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeBookmark];
}

+ (NSURL *)documentRecentsDirectoryURLWithError:(NSError **)error
{
  NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
  NSURL *recentsURL = [documentsURL URLByAppendingPathComponent:@"SefariaRecents" isDirectory:YES];
  [[NSFileManager defaultManager] createDirectoryAtURL:recentsURL withIntermediateDirectories:YES attributes:nil error:error];
  return recentsURL;
}

+ (NSString *)stringFromItem:(NSDictionary *)item key:(NSString *)key fallback:(NSString *)fallback
{
  id value = item[key];
  if ([value isKindOfClass:[NSString class]]) { return value; }
  if ([value respondsToSelector:@selector(stringValue)]) { return [value stringValue]; }
  return fallback ?: @"";
}

+ (NSNumber *)timestampFromItem:(NSDictionary *)item
{
  id value = item[@"timestamp"];
  if ([value isKindOfClass:[NSNumber class]]) { return value; }
  if ([value isKindOfClass:[NSString class]]) {
    double parsed = [(NSString *)value doubleValue];
    if (parsed > 0) { return @(parsed); }
  }
  return @([[NSDate date] timeIntervalSince1970] * 1000);
}

+ (NSString *)sanitizedDocumentFileNameFromCandidate:(NSString *)candidate timestamp:(NSNumber *)timestamp
{
  NSString *safeCandidate = candidate ?: @"";
  NSString *trimmed = [safeCandidate stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSMutableString *sanitized = [NSMutableString string];
  NSCharacterSet *controlCharacters = [NSCharacterSet controlCharacterSet];
  NSCharacterSet *forbidden = [NSCharacterSet characterSetWithCharactersInString:@"/:?#%"];
  for (NSUInteger index = 0; index < trimmed.length; index++) {
    unichar character = [trimmed characterAtIndex:index];
    if ([controlCharacters characterIsMember:character] || [forbidden characterIsMember:character]) { continue; }
    [sanitized appendFormat:@"%C", character];
  }
  NSString *result = [sanitized stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (result.length > 80) {
    result = [result substringToIndex:80];
    result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  }
  if (result.length == 0) { result = [timestamp stringValue]; }
  return result;
}

+ (void)limitStoredRecentDocumentsInDirectory:(NSURL *)directoryURL
{
  NSArray<NSURL *> *fileURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directoryURL includingPropertiesForKeys:@[NSURLContentModificationDateKey] options:0 error:nil];
  NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSURL *fileURL, NSDictionary *bindings) {
    NSString *extension = fileURL.pathExtension.lowercaseString;
    return [extension isEqualToString:@"sefref"] || [extension isEqualToString:@"sefsearch"];
  }];
  NSArray<NSURL *> *recentDocumentURLs = [fileURLs filteredArrayUsingPredicate:predicate];
  NSArray<NSURL *> *sortedURLs = [recentDocumentURLs sortedArrayUsingComparator:^NSComparisonResult(NSURL *firstURL, NSURL *secondURL) {
    NSDate *firstDate = nil;
    NSDate *secondDate = nil;
    [firstURL getResourceValue:&firstDate forKey:NSURLContentModificationDateKey error:nil];
    [secondURL getResourceValue:&secondDate forKey:NSURLContentModificationDateKey error:nil];
    if (!firstDate && !secondDate) { return NSOrderedSame; }
    if (!firstDate) { return NSOrderedDescending; }
    if (!secondDate) { return NSOrderedAscending; }
    return [secondDate compare:firstDate];
  }];
  for (NSUInteger index = 20; index < sortedURLs.count; index++) {
    [[NSFileManager defaultManager] removeItemAtURL:sortedURLs[index] error:nil];
  }
}

+ (void)openRecentDocumentURLForRegistration:(NSURL *)fileURL
{
  dispatch_async(dispatch_get_main_queue(), ^{
    // EXPERIMENT: iPadOS may only surface app-icon recent documents for documents that have been opened through the document system. This is intentionally experimental and safe to remove.
    [[UIApplication sharedApplication] openURL:fileURL options:@{} completionHandler:^(BOOL success) {
      NSLog(@"[SefariaDocumentRecents] Opened recent document URL for registration: %@", success ? @"YES" : @"NO");
    }];
  });
}

+ (void)writeRecentDocumentWithItem:(NSDictionary *)item
                               kind:(NSString *)kind
                          extension:(NSString *)extension
                            resolver:(RCTPromiseResolveBlock)resolve
                            rejecter:(RCTPromiseRejectBlock)reject
{
  if (![item isKindOfClass:[NSDictionary class]]) {
    resolve(@{@"written": @NO});
    return;
  }

  NSNumber *timestamp = [SpotlightIndexer timestampFromItem:item];
  NSString *displayTitle = [SpotlightIndexer stringFromItem:item key:@"displayTitle" fallback:@""];
  NSString *candidate = displayTitle.length > 0 ? displayTitle : [SpotlightIndexer stringFromItem:item key:[kind isEqualToString:@"ref"] ? @"ref" : @"query" fallback:@""];
  NSString *fileName = [[SpotlightIndexer sanitizedDocumentFileNameFromCandidate:candidate timestamp:timestamp] stringByAppendingPathExtension:extension];

  NSError *directoryError = nil;
  NSURL *directoryURL = [SpotlightIndexer documentRecentsDirectoryURLWithError:&directoryError];
  if (directoryError || !directoryURL) {
    reject(@"document_recents_directory_error", directoryError.localizedDescription, directoryError);
    return;
  }

  NSMutableDictionary *payload = [@{
    @"kind": kind,
    @"displayTitle": displayTitle,
    @"url": [SpotlightIndexer stringFromItem:item key:@"url" fallback:@""],
    @"interfaceLanguage": [SpotlightIndexer stringFromItem:item key:@"interfaceLanguage" fallback:@""],
    @"createdAt": timestamp
  } mutableCopy];
  if ([kind isEqualToString:@"ref"]) {
    payload[@"ref"] = [SpotlightIndexer stringFromItem:item key:@"ref" fallback:@""];
  } else {
    payload[@"query"] = [SpotlightIndexer stringFromItem:item key:@"query" fallback:@""];
  }

  NSError *jsonError = nil;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&jsonError];
  if (jsonError || !jsonData || jsonData.length == 0) {
    reject(@"document_recents_json_error", jsonError.localizedDescription, jsonError);
    return;
  }

  NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
  NSError *writeError = nil;
  BOOL wrote = [jsonData writeToURL:fileURL options:NSDataWritingAtomic error:&writeError];
  if (!wrote || writeError) {
    reject(@"document_recents_write_error", writeError.localizedDescription, writeError);
    return;
  }

  [SpotlightIndexer limitStoredRecentDocumentsInDirectory:directoryURL];
  NSString *logKind = [kind isEqualToString:@"ref"] ? @"ref" : @"search";
  NSLog(@"[SefariaDocumentRecents] Wrote recent %@ document: %@", logKind, fileURL.path);
  [SpotlightIndexer openRecentDocumentURLForRegistration:fileURL];
  resolve(@{@"written": @YES, @"path": fileURL.path ?: @"", @"url": fileURL.absoluteString ?: @""});
}

RCT_REMAP_METHOD(recordRecentRefDocument,
                 recordRecentRefDocument:(NSDictionary *)item
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  [SpotlightIndexer writeRecentDocumentWithItem:item kind:@"ref" extension:@"sefref" resolver:resolve rejecter:reject];
}

RCT_REMAP_METHOD(recordRecentSearchDocument,
                 recordRecentSearchDocument:(NSDictionary *)item
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  [SpotlightIndexer writeRecentDocumentWithItem:item kind:@"search" extension:@"sefsearch" resolver:resolve rejecter:reject];
}

RCT_REMAP_METHOD(isIndexingAvailable,
                 isIndexingAvailableWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(@([CSSearchableIndex isIndexingAvailable]));
}

RCT_REMAP_METHOD(updateAppState,
                 updateAppState:(NSDictionary *)state
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (![state isKindOfClass:[NSDictionary class]]) {
    resolve(@{@"saved": @NO});
    return;
  }
  NSMutableDictionary *mutableState = [state mutableCopy];
  mutableState[@"nativeSavedAt"] = @([[NSDate date] timeIntervalSince1970] * 1000);
  [SpotlightIndexer saveJSONDictionary:mutableState key:SefariaIntentStateKey];
  NSLog(@"[SefariaIntentsStore] Saved current app state for shortcuts");
  resolve(@{@"saved": @YES});
}

RCT_REMAP_METHOD(updateQuickActions,
                 updateQuickActions:(NSArray *)items
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (![items isKindOfClass:[NSArray class]]) {
    resolve(@{@"updated": @NO, @"count": @0});
    return;
  }

  NSUInteger attemptedCount = items.count;
  NSMutableArray<UIApplicationShortcutItem *> *shortcutItems = [NSMutableArray array];
  for (NSDictionary *item in items) {
    if (![item isKindOfClass:[NSDictionary class]]) { continue; }
    NSString *type = [item[@"type"] isKindOfClass:[NSString class]] ? item[@"type"] : @"org.sefaria.quick.action";
    NSString *title = [item[@"title"] isKindOfClass:[NSString class]] ? item[@"title"] : @"Sefaria";
    NSString *subtitle = [item[@"subtitle"] isKindOfClass:[NSString class]] ? item[@"subtitle"] : nil;
    NSString *url = [item[@"url"] isKindOfClass:[NSString class]] ? item[@"url"] : @"";
    NSString *iconName = [item[@"icon"] isKindOfClass:[NSString class]] ? item[@"icon"] : @"bookmark";
    NSDictionary *userInfo = url.length > 0 ? @{@"url": url} : @{};

    UIApplicationShortcutItem *shortcut = [[UIApplicationShortcutItem alloc]
      initWithType:type
      localizedTitle:title
      localizedSubtitle:subtitle
      icon:[SpotlightIndexer shortcutIconForName:iconName]
      userInfo:userInfo];
    [shortcutItems addObject:shortcut];
    if (shortcutItems.count >= 8) { break; }
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    [UIApplication sharedApplication].shortcutItems = shortcutItems;
    NSLog(@"[SefariaQuickActions] Attempted %lu, updated %lu dynamic Home Screen quick actions", (unsigned long)attemptedCount, (unsigned long)shortcutItems.count);
    resolve(@{@"updated": @YES, @"attempted": @(attemptedCount), @"count": @(shortcutItems.count)});
  });
}

RCT_REMAP_METHOD(getCurrentAppState,
                 getCurrentAppStateWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:SefariaIntentStateKey];
  if (!data) {
    resolve(@{});
    return;
  }
  NSError *error = nil;
  id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  if (error || !object) {
    reject(@"state_decode_error", error.localizedDescription, error);
    return;
  }
  resolve(object);
}

RCT_REMAP_METHOD(indexItems,
                 indexItems:(NSArray *)items
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (![items isKindOfClass:[NSArray class]]) {
    resolve(@{@"available": @([CSSearchableIndex isIndexingAvailable]), @"indexed": @0});
    return;
  }

  [SpotlightIndexer saveJSONArray:items key:SefariaIntentSourcesKey];
  NSLog(@"[SefariaIntentsStore] Saved %lu source items for shortcuts", (unsigned long)items.count);

  if (![CSSearchableIndex isIndexingAvailable]) {
    resolve(@{@"available": @NO, @"indexed": @0, @"cachedForIntents": @(items.count)});
    return;
  }

  NSMutableArray<CSSearchableItem *> *searchableItems = [NSMutableArray array];

  for (NSDictionary *item in items) {
    if (![item isKindOfClass:[NSDictionary class]]) { continue; }

    NSString *url = [item[@"url"] isKindOfClass:[NSString class]] ? item[@"url"] : nil;
    NSString *identifier = url.length > 0 ? url : ([item[@"id"] isKindOfClass:[NSString class]] ? item[@"id"] : nil);
    NSString *title = [item[@"title"] isKindOfClass:[NSString class]] ? item[@"title"] : @"";
    NSString *path = [item[@"path"] isKindOfClass:[NSString class]] ? item[@"path"] : @"";
    NSString *author = [item[@"author"] isKindOfClass:[NSString class]] ? item[@"author"] : @"";
    NSArray *keywords = [item[@"keywords"] isKindOfClass:[NSArray class]] ? item[@"keywords"] : @[];

    if (identifier.length == 0 || title.length == 0) { continue; }

    CSSearchableItemAttributeSet *attributes = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:@"public.text"];
    attributes.title = title;
    attributes.contentDescription = path;
    if (author.length > 0) {
      attributes.authorNames = @[author];
    }
    attributes.keywords = keywords;

    CSSearchableItem *searchableItem = [[CSSearchableItem alloc] initWithUniqueIdentifier:identifier domainIdentifier:SefariaSpotlightDomain attributeSet:attributes];
    [searchableItems addObject:searchableItem];
  }

  NSLog(@"[SpotlightIndexer] Indexing %lu items", (unsigned long)searchableItems.count);

  [[CSSearchableIndex defaultSearchableIndex] indexSearchableItems:searchableItems completionHandler:^(NSError * _Nullable error) {
    if (error) {
      NSLog(@"[SpotlightIndexer] Index error: %@", error);
      reject(@"spotlight_index_error", error.localizedDescription, error);
      return;
    }
    NSLog(@"[SpotlightIndexer] Indexed %lu items", (unsigned long)searchableItems.count);
    resolve(@{@"available": @YES, @"indexed": @(searchableItems.count), @"cachedForIntents": @(items.count)});
  }];
}

RCT_REMAP_METHOD(deleteAll,
                 deleteAllWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:SefariaIntentSourcesKey];
  [[NSUserDefaults standardUserDefaults] synchronize];

  if (![CSSearchableIndex isIndexingAvailable]) {
    resolve(@{@"available": @NO, @"deleted": @0});
    return;
  }

  NSLog(@"[SpotlightIndexer] Deleting domain %@", SefariaSpotlightDomain);

  [[CSSearchableIndex defaultSearchableIndex] deleteSearchableItemsWithDomainIdentifiers:@[SefariaSpotlightDomain] completionHandler:^(NSError * _Nullable error) {
    if (error) {
      NSLog(@"[SpotlightIndexer] Delete error: %@", error);
      reject(@"spotlight_delete_error", error.localizedDescription, error);
      return;
    }
    NSLog(@"[SpotlightIndexer] Deleted domain %@", SefariaSpotlightDomain);
    resolve(@{@"available": @YES, @"deleted": @YES});
  }];
}

@end

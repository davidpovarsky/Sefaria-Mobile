#import <Foundation/Foundation.h>
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

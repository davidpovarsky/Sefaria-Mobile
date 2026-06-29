#import <Foundation/Foundation.h>
#import <CoreSpotlight/CoreSpotlight.h>
#import <React/RCTBridgeModule.h>

static NSString * const SefariaSpotlightDomain = @"org.sefaria.reader.sources";

@interface SpotlightIndexer : NSObject <RCTBridgeModule>
@end

@implementation SpotlightIndexer

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

RCT_REMAP_METHOD(isIndexingAvailable,
                 isIndexingAvailableWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(@([CSSearchableIndex isIndexingAvailable]));
}

RCT_REMAP_METHOD(indexItems,
                 indexItems:(NSArray *)items
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (![CSSearchableIndex isIndexingAvailable]) {
    resolve(@{@"available": @NO, @"indexed": @0});
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
    resolve(@{@"available": @YES, @"indexed": @(searchableItems.count)});
  }];
}

RCT_REMAP_METHOD(deleteAll,
                 deleteAllWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
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

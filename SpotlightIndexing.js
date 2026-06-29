'use strict';

import { NativeModules, Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

const SpotlightNative = NativeModules.SpotlightIndexer;

const CACHE_KEY = 'spotlightIndexedItemsV1';
const META_KEY = 'spotlightIndexMetaV1';
const INDEX_VERSION = 'sources-v1';
const SPOTLIGHT_URL_PREFIX = 'https://www.sefaria.org/';

const isHebrewInterface = interfaceLanguage => interfaceLanguage === 'hebrew';
const textValue = value => {
  if (!value) { return ''; }
  if (typeof value === 'string') { return value; }
  if (Array.isArray(value)) { return value.map(textValue).filter(Boolean).join(', '); }
  if (typeof value === 'object') {
    return value.he || value.heName || value.heTitle || value.en || value.enName || value.enTitle || value.name || value.title || '';
  }
  return String(value);
};

const localizedObjectValue = (value, isHeb) => {
  if (!value) { return ''; }
  if (typeof value === 'string') { return value; }
  if (Array.isArray(value)) { return value.map(v => localizedObjectValue(v, isHeb)).filter(Boolean).join(', '); }
  if (typeof value === 'object') {
    if (isHeb) {
      return value.he || value.heName || value.heTitle || value.hebrew || value.name_he || value.title_he || value.name || value.title || '';
    }
    return value.en || value.enName || value.enTitle || value.english || value.name_en || value.title_en || value.name || value.title || '';
  }
  return String(value);
};

const localizedCategory = (category, isHeb) => {
  if (!isHeb) { return category; }
  return Sefaria.hebrewCategories?.[category] || category;
};

const localizedTitle = (item, isHeb) => {
  if (isHeb) { return item.heTitle || item.title || ''; }
  return item.title || item.heTitle || '';
};

const localizedPath = (item, tocPath, isHeb) => {
  const categories = Array.isArray(item.categories) && item.categories.length > 0 ? item.categories : tocPath;
  return categories.map(cat => localizedCategory(cat, isHeb)).filter(Boolean).join(' > ');
};

const localizedAuthor = (item, isHeb) => {
  const candidates = isHeb ? [
    item.heAuthor,
    item.heAuthors,
    item.he_author,
    item.heAuthorName,
    item.heAuthorNames,
    item.authors,
    item.author,
    item.heCollectiveTitle,
  ] : [
    item.author,
    item.authors,
    item.enAuthor,
    item.enAuthors,
    item.authorName,
    item.authorNames,
    item.collectiveTitle,
  ];
  for (const candidate of candidates) {
    const value = localizedObjectValue(candidate, isHeb);
    if (value) { return value; }
  }
  return '';
};

const makeUrlForTitle = title => {
  try {
    return `${SPOTLIGHT_URL_PREFIX}${Sefaria.refToUrl(title)}`;
  } catch (e) {
    return `${SPOTLIGHT_URL_PREFIX}${encodeURIComponent(title.replace(/ /g, '_'))}`;
  }
};

const flattenTocItems = (toc, path = []) => {
  let items = [];
  for (const node of toc || []) {
    if (node.category && Array.isArray(node.contents)) {
      items = items.concat(flattenTocItems(node.contents, path.concat(node.category)));
    } else if (node.title) {
      items.push({ item: node, path });
    }
  }
  return items;
};

const buildItems = interfaceLanguage => {
  const isHeb = isHebrewInterface(interfaceLanguage);
  const flattened = flattenTocItems(Sefaria.toc || []);
  const items = flattened.map(({ item, path }) => {
    const sourceTitle = localizedTitle(item, isHeb);
    const sourcePath = localizedPath(item, path, isHeb);
    const author = localizedAuthor(item, isHeb);
    const englishTitle = localizedTitle(item, false);
    const hebrewTitle = localizedTitle(item, true);
    const englishPath = localizedPath(item, path, false);
    const hebrewPath = localizedPath(item, path, true);
    const englishAuthor = localizedAuthor(item, false);
    const hebrewAuthor = localizedAuthor(item, true);
    const url = makeUrlForTitle(item.title);
    const keywords = [
      sourceTitle,
      sourcePath,
      author,
      englishTitle,
      hebrewTitle,
      englishPath,
      hebrewPath,
      englishAuthor,
      hebrewAuthor,
      ...(item.categories || []),
    ].map(textValue).filter(Boolean);

    return {
      id: `sefaria-source:${item.title}`,
      url,
      title: sourceTitle,
      path: sourcePath,
      author,
      keywords,
    };
  }).filter(item => item.title && item.url);

  console.log(`[SpotlightIndexing] Built ${items.length} items for ${interfaceLanguage}`);
  return items;
};

const makeSignature = (items, interfaceLanguage) => {
  const first = items[0]?.id || '';
  const last = items[items.length - 1]?.id || '';
  return `${INDEX_VERSION}:${interfaceLanguage}:${items.length}:${first}:${last}`;
};

const loadMeta = async () => {
  try {
    return JSON.parse(await AsyncStorage.getItem(META_KEY)) || null;
  } catch (e) {
    return null;
  }
};

const loadCachedItems = async () => {
  try {
    return JSON.parse(await AsyncStorage.getItem(CACHE_KEY)) || [];
  } catch (e) {
    return [];
  }
};

const saveCache = async (items, meta) => {
  await AsyncStorage.setItem(CACHE_KEY, JSON.stringify(items));
  await AsyncStorage.setItem(META_KEY, JSON.stringify(meta));
};

const ensureNativeAvailable = async () => {
  if (Platform.OS !== 'ios') { return false; }
  if (!SpotlightNative) { return false; }
  if (!SpotlightNative.isIndexingAvailable) { return true; }
  return SpotlightNative.isIndexingAvailable();
};

const sync = async ({ interfaceLanguage, force = false } = {}) => {
  const lang = interfaceLanguage || 'english';
  console.log(`[SpotlightIndexing] Sync requested. force=${force}, lang=${lang}`);
  const items = buildItems(lang);
  const signature = makeSignature(items, lang);
  const oldMeta = await loadMeta();

  if (!force && oldMeta?.signature === signature) {
    console.log('[SpotlightIndexing] Existing index is up to date.');
    return { status: 'up-to-date', indexed: oldMeta.count || items.length, signature };
  }

  const isAvailable = await ensureNativeAvailable();
  if (!isAvailable) {
    console.log('[SpotlightIndexing] Native Spotlight indexing is not available. Saving local cache only.');
    const meta = { signature, language: lang, count: items.length, lastUpdated: Date.now(), nativeAvailable: false };
    await saveCache(items, meta);
    return { status: 'native-unavailable', indexed: 0, localCount: items.length, signature };
  }

  const nativeResult = await SpotlightNative.indexItems(items);
  const meta = { signature, language: lang, count: items.length, lastUpdated: Date.now(), nativeAvailable: true, nativeResult };
  await saveCache(items, meta);
  console.log(`[SpotlightIndexing] Indexed ${items.length} items. Native result: ${JSON.stringify(nativeResult)}`);
  return { status: 'indexed', indexed: items.length, nativeResult, signature };
};

const rebuild = async interfaceLanguage => sync({ interfaceLanguage, force: true });

const deleteIndex = async () => {
  console.log('[SpotlightIndexing] Delete requested.');
  if (Platform.OS === 'ios' && SpotlightNative?.deleteAll) {
    await SpotlightNative.deleteAll();
  }
  await AsyncStorage.removeItem(CACHE_KEY);
  await AsyncStorage.removeItem(META_KEY);
  console.log('[SpotlightIndexing] Deleted native index and local cache.');
  return { status: 'deleted' };
};

const getStatus = async interfaceLanguage => {
  const lang = interfaceLanguage || 'english';
  const meta = await loadMeta();
  const cachedItems = await loadCachedItems();
  let needsRebuild = true;
  let currentCount = 0;
  try {
    const currentItems = buildItems(lang);
    currentCount = currentItems.length;
    needsRebuild = meta?.signature !== makeSignature(currentItems, lang);
  } catch (e) {
    needsRebuild = true;
  }
  return {
    meta,
    cachedItems,
    cachedCount: cachedItems.length,
    currentCount,
    needsRebuild,
  };
};

const searchCachedItems = async (query, limit = 50) => {
  const q = (query || '').trim().toLowerCase();
  const items = await loadCachedItems();
  if (!q) { return items.slice(0, limit); }
  return items.filter(item => [item.title, item.path, item.author].join(' ').toLowerCase().includes(q)).slice(0, limit);
};

export default {
  sync,
  rebuild,
  deleteIndex,
  getStatus,
  searchCachedItems,
  buildItems,
};

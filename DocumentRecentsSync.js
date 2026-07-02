'use strict';

import { NativeModules, Platform } from 'react-native';
import Sefaria from './sefaria';

const SpotlightNative = NativeModules.SpotlightIndexer;

const APP_URL_BASE = 'sefariareader://www.sefaria.org/';

let lastRecordedRef = '';
let lastRecordedSearch = '';
let pendingSearchQuery = '';
let pendingSearchInterfaceLanguage = '';
let searchTimer = null;

const isHebrewInterface = interfaceLanguage => {
  const lang = String(interfaceLanguage || '').toLowerCase();
  return lang.startsWith('he') || lang.startsWith('iw');
};

const refToAppURL = ref => {
  const normalized = String(ref || '').trim().replace(/:/g, '.').replace(/ /g, '_');
  return normalized ? `${APP_URL_BASE}${encodeURIComponent(normalized)}` : APP_URL_BASE;
};

const searchToAppURL = query => {
  const q = encodeURIComponent(String(query || '').trim());
  return q ? `${APP_URL_BASE}search?q=${q}` : `${APP_URL_BASE}search`;
};

const displayTitleForRef = (state, props) => {
  const ref = state.segmentRef || state.textReference || '';
  if (isHebrewInterface(props.interfaceLanguage)) {
    return state.heSegmentRef || state.heRef || ref;
  }
  return ref;
};

const canRecord = methodName => (
  Platform.OS === 'ios' &&
  SpotlightNative &&
  typeof SpotlightNative[methodName] === 'function'
);

const recordRef = async (ref, displayTitle, interfaceLanguage) => {
  if (!canRecord('recordRecentRefDocument')) { return; }
  try {
    await SpotlightNative.recordRecentRefDocument({
      ref,
      displayTitle: displayTitle || ref,
      url: refToAppURL(ref),
      interfaceLanguage,
      timestamp: Date.now(),
    });
  } catch (error) {
    console.log('[SefariaDocumentRecents] JS record error', error);
  }
};

const recordSearch = async (query, interfaceLanguage) => {
  if (!canRecord('recordRecentSearchDocument')) { return; }
  const displayTitle = isHebrewInterface(interfaceLanguage) ? `חיפוש: ${query}` : `Search: ${query}`;
  try {
    await SpotlightNative.recordRecentSearchDocument({
      query,
      displayTitle,
      url: searchToAppURL(query),
      interfaceLanguage,
      timestamp: Date.now(),
    });
  } catch (error) {
    console.log('[SefariaDocumentRecents] JS record error', error);
  }
};

const updateFromReaderApp = (state, props) => {
  if (Platform.OS !== 'ios' || !SpotlightNative) { return; }

  try {
    const currentRef = state.segmentRef || state.textReference || '';
    if (currentRef && currentRef !== lastRecordedRef) {
      lastRecordedRef = currentRef;
      recordRef(currentRef, displayTitleForRef(state, props), props.interfaceLanguage);
    }

    const query = String(state.searchQuery || '').trim();
    if (query && query !== lastRecordedSearch) {
      pendingSearchQuery = query;
      pendingSearchInterfaceLanguage = props.interfaceLanguage;
      if (searchTimer) { clearTimeout(searchTimer); }
      searchTimer = setTimeout(() => {
        searchTimer = null;
        if (pendingSearchQuery && pendingSearchQuery !== lastRecordedSearch) {
          lastRecordedSearch = pendingSearchQuery;
          recordSearch(pendingSearchQuery, pendingSearchInterfaceLanguage);
        }
      }, 800);
    }
  } catch (error) {
    console.log('[SefariaDocumentRecents] JS record error', error);
  }
};

export default { recordRef, recordSearch, updateFromReaderApp };

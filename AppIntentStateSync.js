'use strict';

import { NativeModules, Platform } from 'react-native';

const SpotlightNative = NativeModules.SpotlightIndexer;

let lastSignature = '';
let pending = false;
let queuedSnapshot = null;

const safe = value => {
  if (value === undefined || value === null) { return ''; }
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') { return value; }
  try { return JSON.stringify(value); }
  catch (e) { return String(value); }
};

const makeSnapshot = (state, props) => {
  const isSearchOpen = state.menuOpen === 'search';
  const isHistoryOpen = state.menuOpen === 'menu';
  const isSavedOpen = state.menuOpen === 'saved';
  const currentRef = state.segmentRef || state.textReference || '';
  let currentUrl = '';
  try {
    currentUrl = currentRef ? Sefaria.refToFullUrl(currentRef) : '';
  } catch (e) {
    currentUrl = currentRef ? `https://www.sefaria.org/${encodeURIComponent(currentRef.replace(/ /g, '_'))}` : '';
  }
  return {
    footerTab: safe(state.footerTab),
    menuOpen: safe(state.menuOpen),
    textTitle: safe(state.textTitle),
    textReference: safe(state.textReference),
    segmentRef: safe(state.segmentRef),
    currentRef: safe(currentRef),
    currentUrl: safe(currentUrl),
    sectionIndexRef: safe(state.sectionIndexRef),
    segmentIndexRef: safe(state.segmentIndexRef),
    searchType: safe(state.searchType),
    searchQuery: safe(state.searchQuery),
    isSearchOpen,
    isHistoryOpen,
    isSavedOpen,
    sheetTitle: safe(state.sheet?.title),
    sheetId: safe(state.sheet?.id),
    textLanguage: safe(props.textLanguage),
    interfaceLanguage: safe(props.interfaceLanguage),
    updatedAt: Date.now(),
  };
};

const sendSnapshot = async snapshot => {
  if (Platform.OS !== 'ios' || !SpotlightNative?.updateAppState) { return; }
  const signature = JSON.stringify(snapshot);
  if (signature === lastSignature) { return; }
  lastSignature = signature;
  await SpotlightNative.updateAppState(snapshot);
};

const flush = async () => {
  if (pending) { return; }
  pending = true;
  try {
    while (queuedSnapshot) {
      const snapshot = queuedSnapshot;
      queuedSnapshot = null;
      await sendSnapshot(snapshot);
    }
  } catch (error) {
    console.log('[AppIntentStateSync] update error', error);
  } finally {
    pending = false;
  }
};

const updateFromReaderApp = (state, props) => {
  try {
    queuedSnapshot = makeSnapshot(state, props);
    setTimeout(flush, 50);
  } catch (error) {
    console.log('[AppIntentStateSync] snapshot error', error);
  }
};

export default { updateFromReaderApp };

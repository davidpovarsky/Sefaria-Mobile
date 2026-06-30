'use strict';

import { NativeModules, Platform } from 'react-native';
import Sefaria from './sefaria';

const SpotlightNative = NativeModules.SpotlightIndexer;

let lastSignature = '';
let pending = false;
let queuedSnapshot = null;

const MAX_QUICK_ACTIONS = 4;
const APP_URL_BASE = 'sefariareader://www.sefaria.org/';

const safe = value => {
  if (value === undefined || value === null) { return ''; }
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') { return value; }
  try { return JSON.stringify(value); }
  catch (e) { return String(value); }
};

const refToAppURL = ref => {
  const normalized = String(ref || '').trim().replace(/:/g, '.').replace(/ /g, '_');
  return normalized ? `${APP_URL_BASE}${encodeURIComponent(normalized)}` : APP_URL_BASE;
};

const searchToAppURL = query => {
  const q = encodeURIComponent(String(query || '').trim());
  return q ? `${APP_URL_BASE}search?q=${q}` : `${APP_URL_BASE}search`;
};

const quickURL = action => `${APP_URL_BASE}__quick/${action}`;

const makeSnapshot = (state, props) => {
  const isSearchOpen = state.menuOpen === 'search';
  const isHistoryOpen = state.menuOpen === 'menu' || state.menuOpen === 'history';
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

const historyItems = () => {
  try {
    return (Sefaria.history?.lastPlace || [])
      .filter(item => item && item.ref)
      .slice(0, 6);
  } catch (e) {
    return [];
  }
};

const addUnique = (items, item) => {
  if (!item || !item.url || items.find(existing => existing.url === item.url || existing.title === item.title)) { return; }
  items.push(item);
};

const buildQuickActions = snapshot => {
  const actions = [];
  const lastSearch = String(snapshot.searchQuery || '').trim();

  if (lastSearch) {
    addUnique(actions, {
      type: 'org.sefaria.quick.last-search',
      title: 'Last Search',
      subtitle: lastSearch,
      url: searchToAppURL(lastSearch),
      icon: 'search',
    });
  }

  historyItems().slice(0, 3).forEach((item, index) => {
    addUnique(actions, {
      type: `org.sefaria.quick.recent-${index + 1}`,
      title: item.ref,
      subtitle: index === 0 ? 'Continue Reading' : 'Recent Source',
      url: refToAppURL(item.ref),
      icon: index === 0 ? 'play' : 'history',
    });
  });

  if (actions.length < MAX_QUICK_ACTIONS && snapshot.currentRef) {
    addUnique(actions, {
      type: 'org.sefaria.quick.current-ref',
      title: 'Continue Reading',
      subtitle: snapshot.currentRef,
      url: refToAppURL(snapshot.currentRef),
      icon: 'play',
    });
  }

  if (actions.length < MAX_QUICK_ACTIONS && !lastSearch) {
    addUnique(actions, {
      type: 'org.sefaria.quick.search',
      title: 'Search',
      subtitle: 'Search Sefaria texts',
      url: searchToAppURL(''),
      icon: 'search',
    });
  }

  if (actions.length < MAX_QUICK_ACTIONS) {
    addUnique(actions, {
      type: 'org.sefaria.quick.open-ref',
      title: 'Open Ref',
      subtitle: 'Lookup a source',
      url: quickURL('open-ref'),
      icon: 'bookmark',
    });
  }

  if (actions.length < MAX_QUICK_ACTIONS) {
    addUnique(actions, {
      type: 'org.sefaria.quick.random',
      title: 'Random Source',
      subtitle: 'Open a random book',
      url: quickURL('random'),
      icon: 'shuffle',
    });
  }

  if (actions.length < MAX_QUICK_ACTIONS) {
    addUnique(actions, {
      type: 'org.sefaria.quick.settings',
      title: 'Settings',
      subtitle: 'Open app settings',
      url: quickURL('settings'),
      icon: 'settings',
    });
  }

  return actions.slice(0, MAX_QUICK_ACTIONS);
};

const sendSnapshot = async snapshot => {
  if (Platform.OS !== 'ios' || !SpotlightNative?.updateAppState) { return; }
  const quickActions = buildQuickActions(snapshot);
  const signature = JSON.stringify({ snapshot, quickActions });
  if (signature === lastSignature) { return; }
  lastSignature = signature;
  await SpotlightNative.updateAppState(snapshot);
  if (SpotlightNative.updateQuickActions) {
    await SpotlightNative.updateQuickActions(quickActions);
  }
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

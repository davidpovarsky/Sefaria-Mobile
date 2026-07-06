'use strict';

import { NativeModules, Platform } from 'react-native';
import Sefaria from './sefaria';

const SpotlightNative = NativeModules.SpotlightIndexer;

let lastSignature = '';
let pending = false;
let queuedSnapshot = null;

const MAX_QUICK_ACTIONS = 8;
const APP_URL_BASE = 'sefariareader://www.sefaria.org/';
const RECENT_QUICK_ACTION_TYPES = [
  'org.sefaria.quick.recent-1',
  'org.sefaria.quick.recent-2',
  'org.sefaria.quick.recent-3',
];

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

const isHebrewInterface = interfaceLanguage => {
  const lang = String(interfaceLanguage || '').toLowerCase();
  return lang.startsWith('he') || lang.startsWith('iw');
};

const labelsFor = interfaceLanguage => {
  const he = isHebrewInterface(interfaceLanguage);
  return he ? {
    continueReading: 'המשך קריאה',
    lastSearch: 'חיפוש אחרון',
    search: 'חיפוש',
    openRef: 'פתיחת מקור',
    recentSource: 'מקור אחרון',
    recentSourceNumbered: index => `מקור אחרון ${index}`,
    settings: 'הגדרות',
    randomSource: 'מקור אקראי',
    searchSubtitle: 'חיפוש בטקסטים',
    openRefSubtitle: 'פתיחת מקור',
    settingsSubtitle: 'הגדרות האפליקציה',
  } : {
    continueReading: 'Continue Reading',
    lastSearch: 'Last Search',
    search: 'Search',
    openRef: 'Open Ref',
    recentSource: 'Recent Source',
    recentSourceNumbered: index => `Recent Source ${index}`,
    settings: 'Settings',
    randomSource: 'Random Source',
    searchSubtitle: 'Search Sefaria texts',
    openRefSubtitle: 'Lookup a source',
    settingsSubtitle: 'Open app settings',
  };
};

const displayRefForHistoryItem = (item, interfaceLanguage) => {
  if (isHebrewInterface(interfaceLanguage)) {
    return item.he_ref || item.heRef || item.heSegmentRef || item.ref || '';
  }
  return item.ref || '';
};

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
  if (!item || !item.url || items.find(existing => existing.type === item.type)) { return; }
  items.push(item);
};

const buildQuickActions = snapshot => {
  const actions = [];
  const labels = labelsFor(snapshot.interfaceLanguage);
  const lastSearch = String(snapshot.searchQuery || '').trim();
  const recentItems = historyItems();
  const latest = recentItems[0];

  const continueRef = latest?.ref || snapshot.currentRef || '';
  const continueTitle = latest
    ? displayRefForHistoryItem(latest, snapshot.interfaceLanguage)
    : snapshot.currentRef;

  if (continueRef) {
    addUnique(actions, {
      type: 'org.sefaria.quick.continue',
      title: labels.continueReading,
      subtitle: continueTitle,
      url: refToAppURL(continueRef),
      icon: 'play',
    });
  }

  if (lastSearch) {
    addUnique(actions, {
      type: 'org.sefaria.quick.last-search',
      title: labels.lastSearch,
      subtitle: lastSearch,
      url: searchToAppURL(lastSearch),
      icon: 'search',
    });
  }

  addUnique(actions, {
    type: 'org.sefaria.quick.search',
    title: labels.search,
    subtitle: labels.searchSubtitle,
    url: searchToAppURL(''),
    icon: 'search',
  });

  addUnique(actions, {
    type: 'org.sefaria.quick.open-ref',
    title: labels.openRef,
    subtitle: labels.openRefSubtitle,
    url: quickURL('open-ref'),
    icon: 'bookmark',
  });

  recentItems
    .filter(item => item?.ref && item.ref !== continueRef)
    .slice(0, 3)
    .forEach((item, index) => {
      addUnique(actions, {
        type: RECENT_QUICK_ACTION_TYPES[index],
        title: labels.recentSourceNumbered(index + 1),
        subtitle: displayRefForHistoryItem(item, snapshot.interfaceLanguage),
        url: refToAppURL(item.ref),
        icon: 'history',
      });
    });

  addUnique(actions, {
    type: 'org.sefaria.quick.settings',
    title: labels.settings,
    subtitle: labels.settingsSubtitle,
    url: quickURL('settings'),
    icon: 'settings',
  });

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

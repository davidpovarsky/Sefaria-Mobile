'use strict';

import { NativeModules, Platform } from 'react-native';
import Sefaria from './sefaria';

const SpotlightNative = NativeModules.SpotlightIndexer;

let lastSignature = '';
let pending = false;
let queuedSnapshot = null;

const MAX_QUICK_ACTIONS = 8;
const MAX_RECENT_MENU_ITEMS = 6;
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

const categoryToAppURL = categories => {
  const path = (categories || [])
    .filter(category => String(category || '').trim())
    .map(category => encodeURIComponent(String(category).trim()))
    .join('/');
  return path ? `${APP_URL_BASE}texts/${path}` : `${APP_URL_BASE}texts`;
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

const menuLabelsFor = interfaceLanguage => {
  const he = isHebrewInterface(interfaceLanguage);
  return he ? {
    sourcesMenu: '\u05de\u05e7\u05d5\u05e8\u05d5\u05ea',
    readingMenu: '\u05e7\u05e8\u05d9\u05d0\u05d4',
    searchMenu: '\u05d7\u05d9\u05e4\u05d5\u05e9',
    historyMenu: '\u05d4\u05d9\u05e1\u05d8\u05d5\u05e8\u05d9\u05d4',
    viewMenu: '\u05ea\u05e6\u05d5\u05d2\u05d4',
    toolsMenu: '\u05db\u05dc\u05d9\u05dd',
    openSource: '\u05e4\u05ea\u05d9\u05d7\u05ea \u05de\u05e7\u05d5\u05e8',
    searchIndex: '\u05d7\u05d9\u05e4\u05d5\u05e9 \u05d1\u05d0\u05d9\u05e0\u05d3\u05e7\u05e1',
    allTexts: '\u05db\u05dc \u05d4\u05d8\u05e7\u05e1\u05d8\u05d9\u05dd',
    randomSource: '\u05de\u05e7\u05d5\u05e8 \u05d0\u05e7\u05e8\u05d0\u05d9',
    continueReading: '\u05d4\u05de\u05e9\u05da \u05e7\u05e8\u05d9\u05d0\u05d4',
    currentSource: '\u05de\u05e7\u05d5\u05e8 \u05e0\u05d5\u05db\u05d7\u05d9',
    copyCurrentSourceLink: '\u05d4\u05e2\u05ea\u05e7 \u05e7\u05d9\u05e9\u05d5\u05e8 \u05dc\u05de\u05e7\u05d5\u05e8',
    openCurrentSourceOnSite: '\u05e4\u05ea\u05d7 \u05d1\u05d0\u05ea\u05e8',
    searchTexts: '\u05d7\u05d9\u05e4\u05d5\u05e9 \u05d1\u05d8\u05e7\u05e1\u05d8\u05d9\u05dd',
    lastSearch: '\u05d7\u05d9\u05e4\u05d5\u05e9 \u05d0\u05d7\u05e8\u05d5\u05df',
    recentSearches: '\u05d7\u05d9\u05e4\u05d5\u05e9\u05d9\u05dd \u05d0\u05d7\u05e8\u05d5\u05e0\u05d9\u05dd',
    history: '\u05d4\u05d9\u05e1\u05d8\u05d5\u05e8\u05d9\u05d4',
    saved: '\u05e9\u05de\u05d5\u05e8\u05d9\u05dd',
    recentSources: '\u05de\u05e7\u05d5\u05e8\u05d5\u05ea \u05d0\u05d7\u05e8\u05d5\u05e0\u05d9\u05dd',
    hebrew: '\u05e2\u05d1\u05e8\u05d9\u05ea',
    english: '\u05d0\u05e0\u05d2\u05dc\u05d9\u05ea',
    bilingual: '\u05d3\u05d5-\u05dc\u05e9\u05d5\u05e0\u05d9',
    increaseTextSize: '\u05d4\u05d2\u05d3\u05dc \u05d8\u05e7\u05e1\u05d8',
    decreaseTextSize: '\u05d4\u05e7\u05d8\u05df \u05d8\u05e7\u05e1\u05d8',
    toggleVocalization: '\u05e0\u05d9\u05e7\u05d5\u05d3',
    settings: '\u05d4\u05d2\u05d3\u05e8\u05d5\u05ea',
    spotlightIndex: '\u05d0\u05d9\u05e0\u05d3\u05e7\u05e1 Spotlight',
    rebuildSpotlightIndex: '\u05d1\u05e0\u05d9\u05d9\u05ea \u05d0\u05d9\u05e0\u05d3\u05e7\u05e1 \u05de\u05d7\u05d3\u05e9',
    currentAppState: '\u05de\u05e6\u05d1 \u05e0\u05d5\u05db\u05d7\u05d9',
  } : {
    sourcesMenu: 'Sources',
    readingMenu: 'Reading',
    searchMenu: 'Search',
    historyMenu: 'History',
    viewMenu: 'View',
    toolsMenu: 'Tools',
    openSource: 'Open Source',
    searchIndex: 'Search Index',
    allTexts: 'All Texts',
    randomSource: 'Random Source',
    continueReading: 'Continue Reading',
    currentSource: 'Current Source',
    copyCurrentSourceLink: 'Copy Current Source Link',
    openCurrentSourceOnSite: 'Open Current Source on Sefaria.org',
    searchTexts: 'Search Texts',
    lastSearch: 'Last Search',
    recentSearches: 'Recent Searches',
    history: 'History',
    saved: 'Saved',
    recentSources: 'Recent Sources',
    hebrew: 'Hebrew',
    english: 'English',
    bilingual: 'Bilingual',
    increaseTextSize: 'Increase Text Size',
    decreaseTextSize: 'Decrease Text Size',
    toggleVocalization: 'Toggle Vocalization',
    settings: 'Settings',
    spotlightIndex: 'Spotlight Index',
    rebuildSpotlightIndex: 'Rebuild Spotlight Index',
    currentAppState: 'Current App State',
  };
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
    recentQueries: recentQueryItems(),
    updatedAt: Date.now(),
  };
};

const historyItems = () => {
  try {
    return (Sefaria.history?.lastPlace || [])
      .filter(item => item && item.ref)
      .slice(0, MAX_RECENT_MENU_ITEMS + 1);
  } catch (e) {
    return [];
  }
};

const recentQueryItems = () => {
  try {
    return (Sefaria.recentQueries || [])
      .filter(item => item && String(item.query || '').trim())
      .slice(0, MAX_RECENT_MENU_ITEMS);
  } catch (e) {
    return [];
  }
};

const addUnique = (items, item) => {
  if (!item || !item.url || items.find(existing => existing.type === item.type)) { return; }
  items.push(item);
};

const addMenuItem = (items, item) => {
  if (!item || !item.title) { return; }
  items.push(item);
};

const menuAction = ({ id, title, url, action, text }) => ({
  type: action === 'copy' ? 'copy' : 'url',
  id,
  title,
  ...(url ? { url } : {}),
  ...(text ? { text } : {}),
  ...(action && action !== 'copy' ? { action } : {}),
});

const displayTocTitle = (item, interfaceLanguage) => {
  if (isHebrewInterface(interfaceLanguage)) {
    return item.heCategory || item.heTitle || item.category || item.title || '';
  }
  return item.category || item.title || '';
};

const stableMenuId = value => String(value || '')
  .trim()
  .replace(/[^a-zA-Z0-9_-]+/g, '-')
  .replace(/^-+|-+$/g, '')
  .toLowerCase();

const buildSourceTreeMenuItems = (items, categories, interfaceLanguage, depth = 0, seen = new Set()) => {
  if (!Array.isArray(items) || depth > 12) { return []; }
  return items
    .filter(item => item && !item.hidden)
    .map(item => {
      if (item.category) {
        const nextCategories = categories.concat(item.category);
        const idPath = nextCategories.join('/');
        if (seen.has(idPath)) { return null; }
        const nextSeen = new Set(seen);
        nextSeen.add(idPath);
        const title = displayTocTitle(item, interfaceLanguage);
        if (!title) { return null; }
        const children = buildSourceTreeMenuItems(item.contents || [], nextCategories, interfaceLanguage, depth + 1, nextSeen);
        return {
          type: 'menu',
          id: `source-category-${stableMenuId(idPath)}`,
          title,
          url: categoryToAppURL(nextCategories),
          children: [
            menuAction({
              id: `open-source-category-${stableMenuId(idPath)}`,
              title,
              url: categoryToAppURL(nextCategories),
            }),
            ...children,
          ],
        };
      }
      const title = displayTocTitle(item, interfaceLanguage);
      const routeTitle = item.title;
      if (!title || !routeTitle) { return null; }
      return menuAction({
        id: `source-book-${stableMenuId(routeTitle)}`,
        title,
        url: refToAppURL(routeTitle),
      });
    })
    .filter(Boolean);
};

const sourceTreeItems = interfaceLanguage => {
  try {
    return buildSourceTreeMenuItems(Sefaria.getRootTocItems ? Sefaria.getRootTocItems() : Sefaria.toc, [], interfaceLanguage);
  } catch (e) {
    return [];
  }
};

const buildMenuSections = snapshot => {
  const labels = menuLabelsFor(snapshot.interfaceLanguage);
  const recentItems = historyItems();
  const latest = recentItems[0];
  const continueRef = latest?.ref || snapshot.currentRef || '';
  const currentRef = snapshot.currentRef || continueRef;
  const currentSourceUrl = currentRef ? refToAppURL(currentRef) : quickURL('open-ref');
  const currentWebUrl = String(snapshot.currentUrl || '').trim();
  const recentSources = recentItems
    .filter(item => item?.ref && item.ref !== continueRef)
    .slice(0, MAX_RECENT_MENU_ITEMS)
    .map((item, index) => menuAction({
      id: `recent-source-${index + 1}`,
      title: displayRefForHistoryItem(item, snapshot.interfaceLanguage),
      url: refToAppURL(item.ref),
    }));
  const recentSearches = (snapshot.recentQueries || recentQueryItems())
    .filter(item => item && String(item.query || '').trim())
    .slice(0, MAX_RECENT_MENU_ITEMS)
    .map((item, index) => menuAction({
      id: `recent-search-${index + 1}`,
      title: String(item.query || '').trim(),
      url: searchToAppURL(item.query),
    }));

  const sourceActions = [];
  addMenuItem(sourceActions, menuAction({ id: 'open-ref', title: labels.openSource, url: quickURL('open-ref') }));
  addMenuItem(sourceActions, menuAction({ id: 'index-search', title: labels.searchIndex, url: quickURL('index-search') }));
  addMenuItem(sourceActions, menuAction({ id: 'all-texts', title: labels.allTexts, url: `${APP_URL_BASE}texts` }));
  addMenuItem(sourceActions, menuAction({ id: 'random', title: labels.randomSource, url: quickURL('random') }));

  const reading = [];
  addMenuItem(reading, menuAction({ id: 'continue-reading', title: labels.continueReading, url: continueRef ? refToAppURL(continueRef) : quickURL('recent') }));
  addMenuItem(reading, menuAction({ id: 'current-source', title: labels.currentSource, url: currentSourceUrl }));
  if (currentWebUrl) {
    addMenuItem(reading, menuAction({ id: 'copy-current-source-link', title: labels.copyCurrentSourceLink, action: 'copy', text: currentWebUrl }));
    addMenuItem(reading, menuAction({ id: 'open-current-source-site', title: labels.openCurrentSourceOnSite, action: 'openExternal', url: currentWebUrl }));
  }

  const search = [];
  addMenuItem(search, menuAction({ id: 'search-texts', title: labels.searchTexts, url: searchToAppURL('') }));
  if (String(snapshot.searchQuery || '').trim()) {
    addMenuItem(search, menuAction({ id: 'last-search', title: labels.lastSearch, url: searchToAppURL(snapshot.searchQuery) }));
  }

  const history = [];
  addMenuItem(history, menuAction({ id: 'history', title: labels.history, url: `${APP_URL_BASE}texts/history` }));
  addMenuItem(history, menuAction({ id: 'saved', title: labels.saved, url: `${APP_URL_BASE}texts/saved` }));

  return [
    { id: 'sources', title: labels.sourcesMenu, groups: [sourceActions, sourceTreeItems(snapshot.interfaceLanguage)] },
    { id: 'reading', title: labels.readingMenu, groups: [reading] },
    { id: 'search', title: labels.searchMenu, groups: [search, recentSearches] },
    { id: 'history', title: labels.historyMenu, groups: [history, recentSources] },
    {
      id: 'view',
      title: labels.viewMenu,
      groups: [[
        menuAction({ id: 'text-language-hebrew', title: labels.hebrew, url: quickURL('text-language-hebrew') }),
        menuAction({ id: 'text-language-english', title: labels.english, url: quickURL('text-language-english') }),
        menuAction({ id: 'text-language-bilingual', title: labels.bilingual, url: quickURL('text-language-bilingual') }),
        menuAction({ id: 'increase-text-size', title: labels.increaseTextSize, url: quickURL('increase-text-size') }),
        menuAction({ id: 'decrease-text-size', title: labels.decreaseTextSize, url: quickURL('decrease-text-size') }),
        menuAction({ id: 'toggle-vocalization', title: labels.toggleVocalization, url: quickURL('toggle-vocalization') }),
      ]],
    },
    {
      id: 'tools',
      title: labels.toolsMenu,
      groups: [[
        menuAction({ id: 'settings', title: labels.settings, url: quickURL('settings') }),
        menuAction({ id: 'spotlight-index', title: labels.spotlightIndex, url: quickURL('spotlight-index') }),
        menuAction({ id: 'rebuild-spotlight-index', title: labels.rebuildSpotlightIndex, url: quickURL('spotlight-index') }),
        menuAction({ id: 'current-app-state', title: labels.currentAppState, url: quickURL('current-app-state') }),
      ]],
    },
  ];
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
  const menuSections = buildMenuSections(snapshot);
  const signature = JSON.stringify({ snapshot, quickActions, menuSections });
  if (signature === lastSignature) { return; }
  lastSignature = signature;
  await SpotlightNative.updateAppState(snapshot);
  if (SpotlightNative.updateQuickActions) {
    await SpotlightNative.updateQuickActions(quickActions);
  }
  if (SpotlightNative.updateMenuCommands) {
    await SpotlightNative.updateMenuCommands(menuSections);
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

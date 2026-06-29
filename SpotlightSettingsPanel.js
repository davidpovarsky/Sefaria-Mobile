'use strict';

import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import SpotlightIndexing from './SpotlightIndexing';
import styles from './Styles';
import { LoadingView, SystemButton } from './Misc.js';

const labelsForLanguage = interfaceLanguage => {
  const he = interfaceLanguage === 'hebrew';
  return he ? {
    title: 'חיפוש Spotlight',
    status: 'סטטוס',
    indexedItems: 'פריטים שאונדקסו',
    availableItems: 'פריטים זמינים',
    language: 'שפה',
    lastUpdated: 'עודכן לאחרונה',
    upToDate: 'מעודכן',
    needsRebuild: 'דורש בנייה מחדש',
    rebuild: 'עדכן / צור מחדש אינדקס Spotlight',
    delete: 'מחק אינדקס Spotlight',
    searchPlaceholder: 'חפש בפריטים שאונדקסו...',
    noItems: 'עדיין אין פריטים שאונדקסו',
    authorEmpty: 'ללא מחבר',
    rebuilding: 'מאנדקס...',
    deleting: 'מוחק...',
    done: 'בוצע',
    rebuiltMessage: 'אינדקס Spotlight נבנה מחדש בהצלחה.',
    deletedMessage: 'אינדקס Spotlight נמחק.',
    deleteTitle: 'מחיקת אינדקס Spotlight',
    deleteConfirm: 'האם למחוק את כל הפריטים שאונדקסו ל־Spotlight?',
    cancel: 'ביטול',
    ok: 'אישור',
    yes: 'כן',
    english: 'אנגלית',
    hebrew: 'עברית',
  } : {
    title: 'Spotlight Search',
    status: 'Status',
    indexedItems: 'Indexed items',
    availableItems: 'Available items',
    language: 'Language',
    lastUpdated: 'Last updated',
    upToDate: 'Up to date',
    needsRebuild: 'Needs rebuild',
    rebuild: 'Update / Rebuild Spotlight Index',
    delete: 'Delete Spotlight Index',
    searchPlaceholder: 'Search indexed items...',
    noItems: 'No indexed items yet',
    authorEmpty: 'No author',
    rebuilding: 'Indexing...',
    deleting: 'Deleting...',
    done: 'Done',
    rebuiltMessage: 'Spotlight index was rebuilt successfully.',
    deletedMessage: 'Spotlight index was deleted.',
    deleteTitle: 'Delete Spotlight Index',
    deleteConfirm: 'Delete all indexed Spotlight items?',
    cancel: 'Cancel',
    ok: 'OK',
    yes: 'Yes',
    english: 'English',
    hebrew: 'Hebrew',
  };
};

const formatDate = timestamp => {
  if (!timestamp) { return '-'; }
  try {
    return new Date(timestamp).toLocaleString();
  } catch (e) {
    return '-';
  }
};

const SpotlightSettingsPanel = ({ interfaceLanguage, langStyle, theme }) => {
  const labels = labelsForLanguage(interfaceLanguage);
  const [status, setStatus] = useState(null);
  const [items, setItems] = useState([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);

  const refresh = useCallback(async (searchQuery = query) => {
    console.log(`[SpotlightSettingsPanel] Refresh. query=${searchQuery}`);
    const newStatus = await SpotlightIndexing.getStatus(interfaceLanguage);
    const searchItems = await SpotlightIndexing.searchCachedItems(searchQuery, 80);
    setStatus(newStatus);
    setItems(searchItems);
  }, [interfaceLanguage, query]);

  useEffect(() => {
    refresh().catch(error => console.log('[SpotlightSettingsPanel] refresh error', error));
  }, [refresh]);

  const rebuild = async () => {
    setLoading(true);
    try {
      console.log('[SpotlightSettingsPanel] Rebuild pressed');
      await SpotlightIndexing.rebuild(interfaceLanguage);
      await refresh('');
      setQuery('');
      Alert.alert(labels.done, labels.rebuiltMessage, [{ text: labels.ok }]);
    } catch (error) {
      console.log('[SpotlightSettingsPanel] rebuild error', error);
      Alert.alert('Spotlight error', String(error?.message || error), [{ text: labels.ok }]);
    } finally {
      setLoading(false);
    }
  };

  const deleteIndex = () => {
    Alert.alert(
      labels.deleteTitle,
      labels.deleteConfirm,
      [
        { text: labels.cancel, style: 'cancel' },
        { text: labels.yes, style: 'destructive', onPress: async () => {
          setLoading(true);
          try {
            console.log('[SpotlightSettingsPanel] Delete pressed');
            await SpotlightIndexing.deleteIndex();
            await refresh('');
            setQuery('');
            Alert.alert(labels.done, labels.deletedMessage, [{ text: labels.ok }]);
          } catch (error) {
            console.log('[SpotlightSettingsPanel] delete error', error);
            Alert.alert('Spotlight error', String(error?.message || error), [{ text: labels.ok }]);
          } finally {
            setLoading(false);
          }
        } },
      ]
    );
  };

  const onSearchChange = async text => {
    setQuery(text);
    try {
      const searchItems = await SpotlightIndexing.searchCachedItems(text, 80);
      setItems(searchItems);
    } catch (error) {
      console.log('[SpotlightSettingsPanel] search error', error);
    }
  };

  const languageLabel = interfaceLanguage === 'hebrew' ? labels.hebrew : labels.english;
  const meta = status?.meta;
  const isHeb = interfaceLanguage === 'hebrew';

  return (
    <View style={localStyles.container}>
      <Text style={[langStyle, styles.settingsSectionHeader, theme.tertiaryText]}>{labels.title}</Text>
      {loading ? <LoadingView /> : null}
      <View style={localStyles.statusBox}>
        <Text style={[langStyle, theme.text, localStyles.statusLine]}>{labels.status}: {status?.needsRebuild ? labels.needsRebuild : labels.upToDate}</Text>
        <Text style={[langStyle, theme.text, localStyles.statusLine]}>{labels.indexedItems}: {status?.cachedCount || 0}</Text>
        <Text style={[langStyle, theme.text, localStyles.statusLine]}>{labels.availableItems}: {status?.currentCount || 0}</Text>
        <Text style={[langStyle, theme.text, localStyles.statusLine]}>{labels.language}: {languageLabel}</Text>
        <Text style={[langStyle, theme.text, localStyles.statusLine]}>{labels.lastUpdated}: {formatDate(meta?.lastUpdated)}</Text>
      </View>

      <SystemButton onPress={rebuild} text={loading ? labels.rebuilding : labels.rebuild} isLoading={loading} isHeb={isHeb} />
      <SystemButton onPress={deleteIndex} text={loading ? labels.deleting : labels.delete} isLoading={loading} isHeb={isHeb} />

      <TextInput
        value={query}
        onChangeText={onSearchChange}
        placeholder={labels.searchPlaceholder}
        placeholderTextColor="#888"
        style={[localStyles.searchInput, theme.text, isHeb ? localStyles.rtl : null]}
      />

      <ScrollView style={localStyles.previewList} nestedScrollEnabled>
        {items.length === 0 ?
          <Text style={[langStyle, theme.text, localStyles.emptyText]}>{labels.noItems}</Text>
          : items.map(item => (
            <View key={item.id || item.url} style={localStyles.itemRow}>
              <Text style={[langStyle, theme.text, localStyles.itemTitle]}>{item.title}</Text>
              <Text style={[langStyle, theme.text, localStyles.itemPath]}>{item.path}</Text>
              <Text style={[langStyle, theme.text, localStyles.itemAuthor]}>{item.author || labels.authorEmpty}</Text>
            </View>
          ))}
      </ScrollView>
    </View>
  );
};

const localStyles = StyleSheet.create({
  container: {
    alignSelf: 'stretch',
    marginTop: 10,
    marginBottom: 10,
  },
  statusBox: {
    alignSelf: 'stretch',
    marginTop: 8,
    marginBottom: 8,
  },
  statusLine: {
    fontSize: 14,
    marginBottom: 4,
  },
  searchInput: {
    alignSelf: 'stretch',
    minHeight: 42,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#999',
    borderRadius: 8,
    paddingHorizontal: 10,
    marginTop: 12,
    marginBottom: 8,
  },
  rtl: {
    textAlign: 'right',
  },
  previewList: {
    alignSelf: 'stretch',
    maxHeight: 280,
  },
  itemRow: {
    paddingVertical: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#999',
  },
  itemTitle: {
    fontSize: 16,
    fontWeight: '600',
  },
  itemPath: {
    fontSize: 13,
    opacity: 0.8,
    marginTop: 2,
  },
  itemAuthor: {
    fontSize: 13,
    opacity: 0.8,
    marginTop: 2,
  },
  emptyText: {
    fontSize: 14,
    opacity: 0.8,
    marginTop: 8,
  },
});

export default SpotlightSettingsPanel;

'use strict';

import PropTypes from 'prop-types';
import URL from 'url-parse';
import React from 'react';
import Sefaria from './sefaria';

class DeepLinkRouter extends React.PureComponent {
  static propTypes = {
    openNav:                 PropTypes.func.isRequired,
    openMenu:                PropTypes.func.isRequired,
    openRef:                 PropTypes.func.isRequired,
    openUri:                 PropTypes.func.isRequired,
    openTextTocDirectly:     PropTypes.func.isRequired,
    openSearch:              PropTypes.func.isRequired,
    openTopic:               PropTypes.func.isRequired,
    setSearchOptions:        PropTypes.func.isRequired,
    setTextLanguage:         PropTypes.func.isRequired,
    setNavigationCategories: PropTypes.func.isRequired,
  };
  constructor(props) {
    super(props);
    const routes = [
      ['^$', props.openNav],
      ['^texts$', props.openNav],
      ['^texts/(saved)$', this.openMenu, ['saved']],
      ['^texts/(history)$', this.openMenu, ['menu']],
      ['^texts/(.+)?$', this.openCats, ['cats']],
      ['^search$', this.openSearch],
      ['^__quick/(settings|open-ref|random)$', this.openQuickAction, ['action']],
      ['^topics/(category)/(.+)$', this.openTopic, ['categoryString','slug']],
      ['^topics/(.+)$', {fromOutside: this.catchAll, fromInside: this.openTopic}, ['slug']],
      ['^([^/]+)$', this.openRef, ['tref']],
      ['^.*$', this.catchAll],
    ];
    this._routes = routes.map(([ regex, funcOrObj, namedCaptureGroups ]) => new Route({regex, funcOrObj, namedCaptureGroups}));
  }
  openMenu = ({ menu }) => {
    this.props.openMenu(menu);
  };
  openTopicFromTag = ({ tag }) => {
    const slug = tag.toLowerCase().replace(/ /g, '-');
    this.openTopic({ slug });
  };
  openCats = ({ cats }) => {
    cats = cats.split('/');
    this.props.openNav();
    this.props.setNavigationCategories(cats);
  };
  openTopic = ({ slug, categoryString }) => {
    const isCategory = !!categoryString;
    this.props.openTopic({slug}, isCategory);
  };
  openQuickAction = ({ action }) => {
    switch (action) {
      case 'settings':
        this.props.openMenu('settings', 'quick-action');
        return;
      case 'open-ref':
        this.props.setSearchOptions('text', 'relevance', false, () => {
          this.props.openSearch('text', '');
        });
        return;
      case 'random': {
        const titles = this._flattenTocTitles(Sefaria.toc || []);
        if (titles.length) {
          const title = titles[Math.floor(Math.random() * titles.length)];
          this.props.openTextTocDirectly(title);
        } else {
          this.props.openNav();
        }
        return;
      }
      default:
        this.props.openNav();
    }
  };
  _flattenTocTitles = (nodes) => {
    const titles = [];
    const walk = items => {
      if (!Array.isArray(items)) { return; }
      items.forEach(item => {
        if (!item) { return; }
        if (item.title && !item.contents) {
          titles.push(item.title);
        }
        if (item.contents) {
          walk(item.contents);
        }
      });
    };
    walk(nodes);
    return titles;
  };
  openRef = ({ tref, ven, vhe, version, aliyot, lang, url }) => {
    let { ref, title } = Sefaria.urlToRef(tref);
    if (!title) {
      Sefaria.api.name(ref, true).then(results => {
          const matches = results.completion_objects.filter(obj => obj.type === 'ref' && ref.includes(obj.title));
          if (matches.length > 0) {
            ref = ref.replace(matches[0].title, matches[0].key);
            this.openStandardRef(ref, aliyot, ven, vhe, lang);
          }
          else {
            this.catchAll({ url });
          }
      }).catch(err => {
        this.catchAll({url});
      });
    }
    else if (ref === title) {
      this.props.openTextTocDirectly(title);
    } else {
      this.openStandardRef(ref, aliyot, ven, vhe, lang);
    }
  };
  openStandardRef = (ref, aliyot, ven, vhe, lang) => {
    const enableAliyot = !!aliyot && aliyot.length > 0 && aliyot !== '0';
    ven = ven?.replace(/^[a-z]+\|/, '');
    vhe = vhe?.replace(/^[a-z]+\|/, '');
    const versions = { en: ven, he: vhe };
    const longLang = Sefaria.util.shortLangToLong(lang);
    if (longLang) {
      this.props.setTextLanguage(longLang, null, true);
    }
    this.props.openRef(ref, 'deep link', versions, true, enableAliyot);
  }
  openSearch = ({ q, tab, tvar, tsort, svar, ssort }) => {
    const isExact = !!tvar && tvar.length > 0 && tvar === '0';
    tsort = tsort || 'relevance';
    tab = tab || 'text';
    this.props.setSearchOptions(tab, tsort, isExact, () => { this.props.openSearch(tab, q || ''); });
  };
  catchAll = ({ url }) => {
    this.props.openUri(url);
  };
  route = (url, fromOutside=false) => {
    const u = new URL(url, Sefaria.api._baseHost, true);
    let { pathname, query, host, hostname } = u;
    if (!hostname.match('(?:www\.)?sefaria\.org')) {
      this.catchAll({ url });
      return;
    }
    pathname = pathname.replace(/[\/\?]$/, '');
    pathname = pathname.replace(/^[\/]/, '');
    pathname = decodeURIComponent(pathname);
    query = Object.entries(query).reduce((obj, [k, v]) => { obj[k] = decodeURIComponent(v); return obj; }, {});
    for (let r of this._routes) {
      if (r.apply({ pathname, query, url }, fromOutside)) { break; }
    }
  };
  render() { return null; }
}

class Route {
  constructor({ regex, funcOrObj, namedCaptureGroups }) {
    this.regex = regex;
    this.funcOrObj = funcOrObj;
    this.namedCaptureGroups = namedCaptureGroups || [];
  }
  getNamedCaptureGroups = match => {
    const groups = {};
    for (let groupNum = 0; groupNum < this.namedCaptureGroups.length; groupNum++) {
      if (!!match[groupNum+1]) {
        const groupName = this.namedCaptureGroups[groupNum];
        groups[groupName] = match[groupNum+1];
      }
    }
    return groups;
  };
  apply = ({ pathname, query, url }, fromOutside) => {
    const m = pathname.match(this.regex);
    if (m) {
      const groups = this.getNamedCaptureGroups(m);
      let func = this.funcOrObj;
      if (typeof func !=='function') {
        const key = fromOutside ? 'fromOutside' : 'fromInside';
        func = func[key];
      }
      func({ ...groups, ...query, url });
      return true;
    }
    return false;
  };
}

export default DeepLinkRouter;

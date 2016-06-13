// Generated by CoffeeScript 1.8.0
(function() {
  var appIsRunningOnGitHub,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  setAppName('Lurch');

  window.menuBarIcon = {
    src: 'icons/apple-touch-icon-76x76.png',
    width: '26px',
    height: '26px',
    padding: '2px'
  };

  window.groupTypes = [
    {
      name: 'me',
      text: 'Meaningful expression',
      imageHTML: '<font color="#996666">[ ]</font>',
      openImageHTML: '<font color="#996666">[</font>',
      closeImageHTML: '<font color="#996666">]</font>',
      tooltip: 'Make text a meaningful expression',
      color: '#996666',
      connectionRequest: function(from, to) {
        var c, existingTags, i, _ref;
        existingTags = (function() {
          var _i, _len, _ref, _results;
          _ref = from.connectionsOut();
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            c = _ref[_i];
            if (c[1] === to.id()) {
              _results.push("" + c[2]);
            }
          }
          return _results;
        })();
        i = 0;
        while (_ref = "" + i, __indexOf.call(existingTags, _ref) >= 0) {
          i++;
        }
        return from.connect(to, "" + i);
      }
    }
  ];

  window.useGroupConnectionsUI = true;

  window.pluginsToLoad = ['mediawiki', 'settings', 'dialogs', 'dropbox'];

  window.groupMenuItems = {
    file_order: 'sharelink wikiimport wikiexport | appsettings docsettings',
    sharelink: {
      text: 'Share document...',
      context: 'file',
      onclick: function() {
        var content, page, request, showURL, url, _ref, _ref1, _ref2;
        page = window.location.href.split('?')[0];
        content = embedMetadata(tinymce.activeEditor.getContent(), tinymce.activeEditor.LoadSave.saveMetaData());
        url = page + '?document=' + encodeURIComponent(content);
        showURL = function(url) {
          var embed;
          embed = ("<iframe src='" + url + "' width=800 height=600></iframe>").replace(/&/g, '&amp;').replace(/'/g, '&apos;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
          console.log(embed);
          return tinymce.activeEditor.Dialogs.alert({
            title: 'Permanent Sharing Links',
            message: "<h3>Sharing URL</h3> <p>Copy this URL to your clipboard, and paste wherever you like, such as email.</p> <input type='text' size=50 id='firstURL' value='" + url + "'/> <h3>Embedding HTML</h3> <p>Copy this HTML to your clipboard, and paste into any webpage or blog to embed a Lurch instance with this document in it.</p> <input type='text' size=50 value='" + embed + "'/> <script> var all = document.getElementsByTagName( 'input' ); for ( var i = 0 ; i < all.length ; i++ ) { all[i].addEventListener( 'focus', function ( event ) { var t = event.target; if ( t.select ) t.select(); else t.setSelectionRange( 0, t.value.length ); } ); } document.getElementById( 'firstURL' ).focus(); </script>"
          });
        };
        request = typeof gapi !== "undefined" && gapi !== null ? (_ref = gapi.client) != null ? (_ref1 = _ref.urlshortener) != null ? (_ref2 = _ref1.url) != null ? typeof _ref2.insert === "function" ? _ref2.insert({
          resource: {
            longUrl: url
          }
        }) : void 0 : void 0 : void 0 : void 0 : void 0;
        if (request == null) {
          return showURL(url);
        }
        return request.execute(function(response) {
          if (response.id != null) {
            return showURL(response.id);
          } else {
            return showURL(url);
          }
        });
      }
    },
    wikiimport: {
      text: 'Import from wiki...',
      context: 'file',
      onclick: function() {
        var pageName;
        if (appIsRunningOnGitHub()) {
          return;
        }
        pageName = prompt('Give the name of the page to import (case sensitive)', 'Main Page');
        if (pageName === null) {
          return;
        }
        return tinymce.activeEditor.MediaWiki.importPage(pageName, function(document, metadata) {
          if (metadata != null) {
            return tinymce.activeEditor.Settings.document.metadata = metadata;
          }
        });
      }
    },
    wikiexport: {
      text: 'Export to wiki',
      context: 'file',
      onclick: function() {
        var loginCallback, pageName, password, postCallback, username;
        if (appIsRunningOnGitHub()) {
          return;
        }
        pageName = tinymce.activeEditor.Settings.document.get('wiki_title');
        if (pageName == null) {
          tinymce.activeEditor.Dialogs.alert({
            title: 'Page Title not set',
            message: '<p>You have not yet set the title under which this document should be published on the wiki.  See the document settings on the File menu.</p>'
          });
          return;
        }
        username = tinymce.activeEditor.Settings.application.get('wiki_username');
        password = tinymce.activeEditor.Settings.application.get('wiki_password');
        if ((username == null) || (password == null)) {
          tinymce.activeEditor.Dialogs.alert({
            title: 'No Wiki Credentials',
            message: '<p>You have not given your wiki username and password to the application settings.  See the application settings on the File menu.</p>'
          });
          return;
        }
        postCallback = function(result, error) {
          var match, url;
          if (error) {
            tinymce.activeEditor.Dialogs.alert({
              title: 'Posting Error',
              message: "<p>Error when posting to the wiki:</p> <p>" + error + "</p>"
            });
            return;
          }
          match = /^[^/]+\/\/[^/]+\//.exec(window.location.href);
          url = window.location.href.slice(0, match[0].length) + 'wiki/index.php?title=' + encodeURIComponent(pageName);
          return tinymce.activeEditor.Dialogs.alert({
            title: 'Document Posted',
            message: "<p>Posting succeeded.</p> <p><a href='" + url + "' target='_blank'>Visit posted page.</a></p>"
          });
        };
        loginCallback = function(result, error) {
          var content;
          if (error) {
            tinymce.activeEditor.Dialogs.alert({
              title: 'Wiki Login Error',
              message: "<p>Error when logging into the wiki:</p> <p>" + error + "</p>"
            });
            return;
          }
          content = tinymce.activeEditor.MediaWiki.embedMetadata(tinymce.activeEditor.getContent(), tinymce.activeEditor.Settings.document.metadata);
          return tinymce.activeEditor.MediaWiki.exportPage(pageName, content, postCallback);
        };
        return tinymce.activeEditor.MediaWiki.login(username, password, loginCallback);
      }
    },
    appsettings: {
      text: 'Application settings...',
      context: 'file',
      onclick: function() {
        return tinymce.activeEditor.Settings.application.showUI();
      }
    },
    docsettings: {
      text: 'Document settings...',
      context: 'file',
      onclick: function() {
        return tinymce.activeEditor.Settings.document.showUI();
      }
    }
  };

  window.addEventListener('load', function() {
    var _ref, _ref1;
    if (typeof gapi !== "undefined" && gapi !== null) {
      if ((_ref = gapi.client) != null) {
        _ref.setApiKey('AIzaSyAf7F0I39DdI2jtD7zrPUa4eQvUXZ-K6W8');
      }
    }
    return typeof gapi !== "undefined" && gapi !== null ? (_ref1 = gapi.client) != null ? _ref1.load('urlshortener', 'v1', function() {}) : void 0 : void 0;
  }, false);

  window.afterEditorReady = function(editor) {
    var A, D, document, html, match, metadata, toAutoLoad, _ref, _ref1;
    A = editor.Settings.addCategory('application');
    if (!A.get('filesystem')) {
      A.set('filesystem', 'dropbox');
    }
    A.setup = function(div) {
      var fs, _ref, _ref1;
      fs = A.get('filesystem');
      return div.innerHTML = [editor.Settings.UI.heading('Wiki Login'), editor.Settings.UI.info('Entering a username and password here does NOT create an account on the wiki.  You must already have one.  If you do not, first visit <a href="/wiki/index.php" target="_blank" style="color: blue;">the wiki</a>, create an account, then return here.'), editor.Settings.UI.text('Username', 'wiki_username', (_ref = A.get('wiki_username')) != null ? _ref : ''), editor.Settings.UI.password('Password', 'wiki_password', (_ref1 = A.get('wiki_password')) != null ? _ref1 : ''), editor.Settings.UI.heading('Open/Save Filesystem'), editor.Settings.UI.radioButton('Dropbox (cloud storage, requires account)', 'filesystem', fs === 'dropbox', 'filesystem_dropbox'), editor.Settings.UI.radioButton('Local Storage (kept permanently, in browser only)', 'filesystem', fs === 'local storage', 'filesystem_local_storage')].join('\n');
    };
    A.teardown = function(div) {
      var elt;
      elt = function(id) {
        return div.ownerDocument.getElementById(id);
      };
      A.set('wiki_username', elt('wiki_username').value);
      A.set('wiki_password', elt('wiki_password').value);
      return A.setFilesystem(elt('filesystem_dropbox').checked ? 'dropbox' : 'local storage');
    };
    A.setFilesystem = function(name) {
      A.set('filesystem', name);
      if (name === 'dropbox') {
        editor.LoadSave.installOpenHandler(editor.Dropbox.openHandler);
        editor.LoadSave.installSaveHandler(editor.Dropbox.saveHandler);
        return editor.LoadSave.installManageFilesHandler(editor.Dropbox.manageFilesHandler);
      } else {
        editor.LoadSave.installOpenHandler();
        editor.LoadSave.installSaveHandler();
        return editor.LoadSave.installManageFilesHandler();
      }
    };
    A.setFilesystem(A.get('filesystem'));
    D = editor.Settings.addCategory('document');
    D.metadata = {};
    D.get = function(key) {
      return D.metadata[key];
    };
    D.set = function(key, value) {
      return D.metadata[key] = value;
    };
    D.setup = function(div) {
      var _ref;
      div.innerHTML = [editor.Settings.UI.heading('Dependencies'), "<div id='dependenciesSection'></div>", editor.Settings.UI.heading('Wiki Publishing'), editor.Settings.UI.text('Publish to wiki under this title', 'wiki_title', (_ref = D.get('wiki_title')) != null ? _ref : '')].join('\n');
      return editor.Dependencies.installUI(div.ownerDocument.getElementById('dependenciesSection'));
    };
    D.teardown = function(div) {
      var elt;
      elt = function(id) {
        return div.ownerDocument.getElementById(id);
      };
      return D.set('wiki_title', elt('wiki_title').value);
    };
    editor.LoadSave.saveMetaData = function() {
      D.metadata.dependencies = editor.Dependencies["export"]();
      return D.metadata;
    };
    editor.LoadSave.loadMetaData = function(object) {
      var _ref;
      D.metadata = object;
      return editor.Dependencies["import"]((_ref = D.metadata.dependencies) != null ? _ref : []);
    };
    editor.MediaWiki.setIndexPage('/wiki/index.php');
    editor.MediaWiki.setAPIPage('/wiki/api.php');
    if (match = /\?wikipage=(.*)/.exec(window.location.search)) {
      editor.MediaWiki.importPage(decodeURIComponent(match[1], function(document, metadata) {
        if (metadata != null) {
          return editor.LoadSave.loadMetaData(metadata);
        }
      }));
    }
    if (toAutoLoad = localStorage.getItem('auto-load')) {
      try {
        _ref = JSON.parse(toAutoLoad), metadata = _ref[0], document = _ref[1];
        setTimeout(function() {
          localStorage.removeItem('auto-load');
          tinymce.activeEditor.setContent(document);
          return editor.LoadSave.loadMetaData(metadata);
        }, 100);
      } catch (_error) {}
    }
    if (match = /\?document=(.*)/.exec(window.location.search)) {
      html = decodeURIComponent(match[1]);
      _ref1 = extractMetadata(html), metadata = _ref1.metadata, document = _ref1.document;
      localStorage.setItem('auto-load', JSON.stringify([metadata, document]));
      return window.location.href = window.location.href.split('?')[0];
    }
  };

  appIsRunningOnGitHub = function() {
    var result;
    result = /nathancarter\.github\.io/.test(window.location.href);
    if (result) {
      tinymce.activeEditor.Dialogs.alert({
        title: 'Not Available Here',
        message: '<p>That functionality requires MediaWiki to be running on the server from which you\'re accessing this web app.</p> <p>On GitHub, we cannot run a MediaWiki server, so the functionality is disabled.</p> <p>The menu items remain for use in developer testing, as we prepare for a dedicated server that will have MediaWiki and the ability to publish documents to that wiki with a single click, or edit them in Lurch with a single click.</p> <p>Try back soon!</p>'
      });
    }
    return result;
  };

}).call(this);

//# sourceMappingURL=main-app-solo.js.map

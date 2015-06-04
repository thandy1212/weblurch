// Generated by CoffeeScript 1.8.0
(function() {
  var isJustArithmetic, mightBeAName;

  setAppName('ComplexApp');

  window.menuBarIcon = {};

  window.groupTypes = [
    {
      name: 'computation',
      text: 'Computation group',
      image: './images/red-bracket-icon.png',
      tooltip: 'Make selection a computation',
      color: '#996666',
      tagContents: function(group) {
        var leftHandSide, _ref, _ref1;
        leftHandSide = (_ref = group.contentAsText()) != null ? (_ref1 = _ref.split('=')) != null ? _ref1[0] : void 0 : void 0;
        if ((leftHandSide != null) && isJustArithmetic(leftHandSide)) {
          return 'arithmetic expression';
        } else {
          return 'unknown';
        }
      },
      contentsChanged: function(group, firstTime) {
        return Background.addTask('do arithmetic', [group], function(result) {
          var before, leftHandSide, origPos, range, text, textNode, _ref, _ref1;
          if (group.deleted || (result == null)) {
            return;
          }
          text = group.contentAsText();
          if (result === text) {
            return;
          }
          leftHandSide = text.split('=')[0];
          before = (_ref = group.plugin) != null ? _ref.editor.selection.getRng() : void 0;
          textNode = group.open.nextSibling;
          if (before.startContainer === textNode) {
            origPos = before.startOffset;
          }
          group.setContentAsText("" + leftHandSide + "=" + result);
          if (!(textNode = group.open.nextSibling)) {
            return;
          }
          range = textNode.ownerDocument.createRange();
          if (origPos == null) {
            origPos = leftHandSide.length;
          }
          if (origPos > textNode.textContent.length) {
            origPos = textNode.textContent.length;
          }
          range.setStart(textNode, origPos);
          range.setEnd(textNode, origPos);
          return (_ref1 = group.plugin) != null ? _ref1.editor.selection.setRng(range) : void 0;
        });
      }
    }, {
      name: 'words',
      text: 'Group of words',
      image: './images/red-bracket-icon.png',
      tooltip: 'Make selection about words',
      color: '#996666',
      tagContents: function(group) {
        return mightBeAName(group.contentAsText());
      },
      tagMenuItems: function(group) {
        return [
          {
            text: 'Why this tag?',
            onclick: function() {
              return alert("This group was classified as '" + (mightBeAName(group.contentAsText())) + "' for the following reason:\nText 'might be a name' if it has one to three words, all capitalized.  Otherwise, it is 'probably not a name.'");
            }
          }, {
            text: 'Change this into a name',
            onclick: function() {
              return group.setContentAsText('Rufus Dimble');
            }
          }, {
            text: 'Change this into a non-name',
            onclick: function() {
              return group.setContentAsText('corn on the cob');
            }
          }
        ];
      },
      contextMenuItems: function(group) {
        return [
          {
            text: 'Count number of letters',
            onclick: function() {
              return alert("Number of letters: " + (group.contentAsText().length) + "\n(includes spaces and punctuation)");
            }
          }, {
            text: 'Count number of words',
            onclick: function() {
              return alert("Number of words: " + (group.contentAsText().split(' ').length) + " \n(counts any sequence of non-spaces as a word)");
            }
          }
        ];
      }
    }
  ];

  isJustArithmetic = function(text) {
    return /^[.0-9+*/ ()-]+$/.test(text);
  };

  Background.registerFunction('do arithmetic', function(group) {
    var e, leftHandSide, result, whenToStop, _ref, _ref1;
    leftHandSide = group != null ? (_ref = group.text) != null ? (_ref1 = _ref.split('=')) != null ? _ref1[0] : void 0 : void 0 : void 0;
    whenToStop = (new Date).getTime() + 1000;
    while ((new Date).getTime() < whenToStop) {
      result = (function() {
        if ((leftHandSide != null) && /^[.0-9+*/ ()-]+$/.test(leftHandSide)) {
          try {
            return eval(leftHandSide);
          } catch (_error) {
            e = _error;
            return '???';
          }
        } else {
          return '???';
        }
      })();
    }
    return result;
  });

  mightBeAName = function(text) {
    var word, words, _i, _len;
    words = text.split(' ');
    if ((words == null) || words.length > 3 || words.length === 0) {
      return 'probably not a name';
    }
    for (_i = 0, _len = words.length; _i < _len; _i++) {
      word = words[_i];
      if ((word[0] == null) || word[0].toUpperCase() !== word[0]) {
        return 'probably not a name';
      }
    }
    return 'might be a name';
  };

}).call(this);

//# sourceMappingURL=complex-example.solo.js.map

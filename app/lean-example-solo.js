// Generated by CoffeeScript 1.8.0
(function() {
  var LeanOutputArray, LeanOutputObject, Module, bodyGroupToCode, bodyIsASection, checkTimer, clearAllValidity, clearValidity, documentToCode, hasValidity, isSubterm, leanCommands, markValid, myTimer, now, pathExists, runLeanOn, sectionGroupToCode, setValidity, startTimer, termGroupToCode, validate, validateButton, validationRunning,
    __hasProp = {}.hasOwnProperty,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
    __slice = [].slice;

  setAppName('LeanApp');

  addHelpMenuSourceCodeLink('app/lean-example-solo.litcoffee');

  window.helpAboutText = 'See the fully documented source code for this demo app at the following URL:\n \nhttps://github.com/nathancarter/weblurch/blob/master/app/lean-example-solo.litcoffee';

  myTimer = null;

  now = function() {
    return (new Date).getTime();
  };

  startTimer = function() {
    return myTimer = now();
  };

  checkTimer = function() {
    return "(took " + (now() - myTimer) + " ms)";
  };

  Module = window.Module = {};

  Module.TOTAL_MEMORY = 64 * 1024 * 1024;

  Module.noExitRuntime = true;

  LeanOutputObject = null;

  LeanOutputArray = null;

  Module.print = function(text) {
    var match;
    match = null;
    if (match = /FLYCHECK_BEGIN (.*)/.exec(text)) {
      return LeanOutputObject = {
        type: match[1],
        text: []
      };
    } else if (!LeanOutputObject) {
      throw new Error('Unexpected output from Lean: ' + text);
    } else if (match = /([^:]+):(\d+):(\d+): (.*)/.exec(text)) {
      LeanOutputObject.file = match[1];
      LeanOutputObject.line = match[2];
      LeanOutputObject.char = match[3];
      return LeanOutputObject.info = match[4];
    } else if (/FLYCHECK_END/.test(text)) {
      LeanOutputArray.push(LeanOutputObject);
      return LeanOutputObject = null;
    } else {
      return LeanOutputObject.text.push(text);
    }
  };

  Module.preRun = [function() {}];

  runLeanOn = window.runLeanOn = function(code) {
    Module.lean_init(false);
    Module.lean_import_module("standard");
    FS.writeFile('test.lean', code, {
      encoding: 'utf8'
    });
    LeanOutputArray = [];
    Module.lean_process_file('test.lean');
    return LeanOutputArray;
  };

  validationRunning = false;

  setValidity = function(group, symbol, hoverText) {
    group.set('closeDecoration', symbol);
    return group.set('closeHoverText', hoverText);
  };

  markValid = function(group, validOrNot, message) {
    var color, symbol;
    color = validOrNot ? 'green' : 'red';
    symbol = validOrNot ? '&#10003;' : '&#10006;';
    return setValidity(group, "<font color='" + color + "'>" + symbol + "</font>", message);
  };

  clearValidity = function(group) {
    group.clear('closeDecoration');
    return group.clear('closeHoverText');
  };

  hasValidity = function(group) {
    return 'undefined' !== typeof group.get('closeDecoration');
  };

  clearAllValidity = function() {
    var groups, id, _i, _len, _ref;
    if (validationRunning) {
      return;
    }
    validationRunning = true;
    groups = tinymce.activeEditor.Groups;
    _ref = groups.ids();
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      id = _ref[_i];
      clearValidity(groups[id]);
    }
    return validationRunning = false;
  };

  validate = window.validate = function() {
    var citation, code, codeline, connection, detail, groups, id, index, isError, lastError, leanCode, line, lineToGroupId, m, message, modifiedTerms, typeName, _i, _j, _k, _l, _len, _len1, _len2, _len3, _len4, _m, _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6;
    groups = tinymce.activeEditor.Groups;
    if (validationRunning) {
      return;
    }
    validationRunning = true;
    _ref = groups.ids();
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      id = _ref[_i];
      if (groups[id].typeName() === 'term' && ((_ref1 = groups[id].parent) != null ? _ref1.typeName() : void 0) === 'term') {
        markValid(groups[id], false, 'A term group cannot be inside another term group.');
      }
    }
    lineToGroupId = {};
    _ref2 = (leanCode = documentToCode()).lines;
    for (index = _j = 0, _len1 = _ref2.length; _j < _len1; index = ++_j) {
      line = _ref2[index];
      if (m = /[ ]--[ ](\d+)$/.exec(line)) {
        lineToGroupId[index + 1] = parseInt(m[1]);
      }
    }
    lastError = -1;
    code = leanCode.lines.join('\n').replace(String.fromCharCode(160), String.fromCharCode(32));
    _ref3 = runLeanOn(code);
    for (_k = 0, _len2 = _ref3.length; _k < _len2; _k++) {
      message = _ref3[_k];
      id = lineToGroupId[message.line];
      if (isError = /error:/.test(message.info)) {
        lastError = id;
      }
      detail = "Lean reported:\n\n" + message.info;
      if (message.text.length) {
        detail += '\n' + message.text.join('\n');
      }
      citation = parseInt(message.char);
      citation = citation > 0 ? (codeline = leanCode.lines[message.line - 1], "\n\ncharacter #" + (citation + 1) + " in this code: \n" + (/^(.*) -- \d+$/.exec(codeline)[1])) : '';
      markValid(groups[id], !isError, detail + citation);
    }
    _ref4 = groups.ids();
    for (_l = 0, _len3 = _ref4.length; _l < _len3; _l++) {
      id = _ref4[_l];
      if (id === lastError) {
        break;
      }
      if (!hasValidity(groups[id])) {
        markValid(groups[id], true, 'No errors reported.');
      }
    }
    _ref5 = groups.ids();
    for (_m = 0, _len4 = _ref5.length; _m < _len4; _m++) {
      id = _ref5[_m];
      if ((typeName = groups[id].typeName()) === 'type') {
        if (isSubterm(groups[id])) {
          continue;
        }
        modifiedTerms = (function() {
          var _len5, _n, _ref6, _results;
          _ref6 = groups[id].connectionsOut();
          _results = [];
          for (_n = 0, _len5 = _ref6.length; _n < _len5; _n++) {
            connection = _ref6[_n];
            if (groups[connection[1]].typeName() === 'term') {
              _results.push(connection[1]);
            }
          }
          return _results;
        })();
        if (modifiedTerms.length === 0) {
          setValidity(groups[id], '<font color="#aaaa00"><b>&#10039;</b></font>', "This " + typeName + " does not modify any terms, and was thus ignored in validation.  Did you mean to connect it to a term?");
        }
      }
    }
    _ref6 = leanCode.errors;
    for (id in _ref6) {
      if (!__hasProp.call(_ref6, id)) continue;
      message = _ref6[id];
      markValid(groups[id], false, message);
    }
    return validationRunning = false;
  };

  validateButton = null;

  window.groupToolbarButtons.validate = {
    text: 'Run Lean',
    tooltip: 'Run Lean on this document',
    onclick: function() {
      validateButton.text('Running...');
      validateButton.disabled(true);
      return setTimeout(function() {
        validate();
        validateButton.disabled(false);
        return validateButton.text('Run Lean');
      }, 0);
    },
    onPostRender: function() {
      return validateButton = this;
    }
  };

  leanCommands = {
    check: 'check (TERM)',
    "eval": 'eval (TERM)',
    print: 'print "TERM"',
    "import": 'import TERM',
    open: 'open TERM',
    constant: 'constant TERM',
    variable: 'variable TERM',
    definition: 'definition TERM',
    theorem: 'theorem TERM',
    example: 'example TERM'
  };

  window.groupTypes = [
    {
      name: 'term',
      text: 'Lean Term',
      tooltip: 'Make the selection a Lean term',
      color: '#666666',
      imageHTML: '<font color="#666666"><b>[ ]</b></font>',
      openImageHTML: '<font color="#666666"><b>[</b></font>',
      closeImageHTML: '<font color="#666666"><b>]</b></font>',
      contentsChanged: clearAllValidity,
      tagContents: function(group) {
        var command;
        if (command = group.get('leanCommand')) {
          return "Command: " + command;
        } else {
          return null;
        }
      },
      contextMenuItems: function(group) {
        return [
          {
            text: 'Edit command...',
            onclick: function() {
              var newval, _ref;
              newval = prompt('Enter the Lean command to use on this code (or leave blank for none).\n \nValid options include:\n' + Object.keys(leanCommands).join(' '), (_ref = group.get('leanCommand')) != null ? _ref : '');
              if (newval !== null) {
                if (newval === '') {
                  return group.clear('leanCommand');
                } else if (!(newval in leanCommands)) {
                  return alert('That was not one of the choices.  No change has been made to your document.');
                } else {
                  return group.set('leanCommand', newval);
                }
              }
            }
          }
        ];
      },
      connectionRequest: function(from, to) {
        var c, _ref;
        if (to.typeName() !== 'term' && to.typeName() !== 'body') {
          return;
        }
        if (_ref = to.id(), __indexOf.call((function() {
          var _i, _len, _ref1, _results;
          _ref1 = from.connectionsOut();
          _results = [];
          for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
            c = _ref1[_i];
            _results.push(c[1]);
          }
          return _results;
        })(), _ref) >= 0) {
          return from.disconnect(to);
        } else if (pathExists(to.id(), from.id())) {
          return alert('That would create a cycle of arrows, which is not permitted.');
        } else {
          return from.connect(to);
        }
      },
      connections: function(group) {
        var ins, outs, t;
        outs = group.connectionsOut();
        ins = group.connectionsIn();
        return __slice.call(outs).concat(__slice.call(ins), __slice.call((function() {
            var _i, _len, _results;
            _results = [];
            for (_i = 0, _len = outs.length; _i < _len; _i++) {
              t = outs[_i];
              _results.push(t[1]);
            }
            return _results;
          })()), __slice.call((function() {
            var _i, _len, _results;
            _results = [];
            for (_i = 0, _len = ins.length; _i < _len; _i++) {
              t = ins[_i];
              _results.push(t[0]);
            }
            return _results;
          })()));
      }
    }
  ];

  termGroupToCode = window.termGroupToCode = function(group) {
    var arg, argMeanings, args, assignedBodies, assignedTypes, command, commandsTakingBodies, connection, e, groups, match, parentTerms, result, source, term, type, _i, _len, _ref, _ref1;
    groups = tinymce.activeEditor.Groups;
    if (group.children.length > 0) {
      throw Error('Invalid structure: Term groups may not contain other groups');
    }
    term = group.contentAsText().trim();
    args = (function() {
      var _i, _len, _ref, _results;
      _ref = group.connectionsOut();
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        connection = _ref[_i];
        _results.push(connection[1]);
      }
      return _results;
    })();
    argMeanings = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = args.length; _i < _len; _i++) {
        arg = args[_i];
        try {
          if (groups[arg].typeName() === 'term') {
            _results.push(termGroupToCode(groups[arg]));
          } else {
            _results.push(bodyGroupToCode(groups[arg]));
          }
        } catch (_error) {
          e = _error;
          markValid(groups[arg], false, e.message);
          throw Error("A term to which this term points (directly or indirectly) contains an error, and thus this term's meaning cannot be determined.");
        }
      }
      return _results;
    })();
    if (args.length > 0) {
      term = "( -- " + (group.id()) + "\n " + term + " -- " + (group.id()) + "\n " + (argMeanings.join('\n')) + "\n )";
    }
    parentTerms = [];
    assignedTypes = [];
    assignedBodies = [];
    _ref = group.connectionsIn();
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      connection = _ref[_i];
      source = groups[connection[0]];
      if (source.typeName() === 'type') {
        type = source.contentAsText().trim();
        if (__indexOf.call(assignedTypes, type) < 0) {
          assignedTypes.push(type);
        }
      } else if (source.typeName() === 'body' && (_ref1 = source.id(), __indexOf.call(assignedBodies, _ref1) < 0)) {
        assignedBodies.push(source.id());
      } else if (source.typeName() === 'term') {
        parentTerms.push(source);
      }
    }
    if (assignedTypes.length > 1) {
      throw Error("Invalid structure: Two different types are assigned to this term (" + (assignedTypes.join(', ')) + ")");
    }
    if (assignedBodies.length > 1) {
      throw Error("Invalid structure: Two bodies are assigned to this term.");
    }
    if (parentTerms.length > 0) {
      if (assignedTypes.length > 0) {
        throw Error("Invalid structure: A subterm of another term cannot have a type assigned.");
      }
      if (assignedBodies.length > 0) {
        throw Error("Invalid structure: A subterm of another term cannot have a body assigned.");
      }
    }
    if (assignedTypes.length > 0) {
      type = assignedTypes[0];
      if (match = /^\s*check\s+(.*)$/.exec(term)) {
        term = "check (" + match[1] + " : " + type + ")";
      } else if (match = /^\s*check\s+\((.*)\)\s*$/.exec(term)) {
        term = "check (" + match[1] + " : " + type + ")";
      } else if (match = /^(.*):=(.*)$/.exec(term)) {
        term = "" + match[1] + " : " + type + " := " + match[2];
      } else {
        term = "" + term + " : " + type;
      }
    }
    if (command = group.get('leanCommand')) {
      term = leanCommands[command].replace('TERM', term);
    }
    result = "" + term + " -- " + (group.id());
    if (assignedBodies.length > 0) {
      commandsTakingBodies = ['theorem', 'definition', 'example'];
      if (__indexOf.call(commandsTakingBodies, command) < 0) {
        throw Error("Terms may only be assigned bodies if they embed one of these commands: " + (commandsTakingBodies.join(', ')) + ".");
      }
      result += "\n:= " + (bodyGroupToCode(groups[assignedBodies[0]]));
    }
    return result;
  };

  documentToCode = window.documentToCode = function() {
    var e, group, lineOrLines, result, _i, _len, _ref;
    result = {
      lines: [],
      errors: {}
    };
    _ref = tinymce.activeEditor.Groups.topLevel;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      group = _ref[_i];
      if (group.typeName() === 'body' && bodyIsASection(group)) {
        lineOrLines = sectionGroupToCode(group);
        result.lines = result.lines.concat(lineOrLines.split('\n'));
        continue;
      }
      if (group.typeName() !== 'term' || isSubterm(group)) {
        continue;
      }
      try {
        lineOrLines = termGroupToCode(group);
        result.lines = result.lines.concat(lineOrLines.split('\n'));
      } catch (_error) {
        e = _error;
        result.errors[group.id()] = e.message;
      }
    }
    return result;
  };

  isSubterm = function(term) {
    var connection, _i, _len, _ref;
    _ref = term.connectionsIn();
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      connection = _ref[_i];
      if (tinymce.activeEditor.Groups[connection[0]].typeName() === 'term') {
        return true;
      }
    }
    return false;
  };

  bodyIsASection = function(group) {
    var connection, _i, _len, _ref;
    _ref = group.connectionsOut();
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      connection = _ref[_i];
      if (tinymce.activeEditor.Groups[connection[1]].typeName() === 'term') {
        return false;
      }
    }
    return true;
  };

  pathExists = function(source, destination) {
    var c, groups, nextId, toExplore, visited;
    groups = tinymce.activeEditor.Groups;
    visited = [];
    toExplore = [source];
    while (toExplore.length > 0) {
      if ((nextId = toExplore.shift()) === destination) {
        return true;
      }
      if (__indexOf.call(visited, nextId) >= 0) {
        continue;
      } else {
        visited.push(nextId);
      }
      toExplore = toExplore.concat((function() {
        var _i, _len, _ref, _results;
        _ref = groups[nextId].connectionsOut();
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          c = _ref[_i];
          _results.push(c[1]);
        }
        return _results;
      })());
    }
    return false;
  };

  window.groupTypes.push({
    name: 'type',
    text: 'Lean Type',
    tooltip: 'Make the selection a Lean type',
    color: '#66bb66',
    imageHTML: '<font color="#66bb66"><b>[ ]</b></font>',
    openImageHTML: '<font color="#66bb66"><b>[</b></font>',
    closeImageHTML: '<font color="#66bb66"><b>]</b></font>',
    contentsChanged: clearAllValidity,
    connectionRequest: function(from, to) {
      var c, _ref;
      if (to.typeName() !== 'term') {
        return;
      }
      if (_ref = to.id(), __indexOf.call((function() {
        var _i, _len, _ref1, _results;
        _ref1 = from.connectionsOut();
        _results = [];
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          c = _ref1[_i];
          _results.push(c[1]);
        }
        return _results;
      })(), _ref) >= 0) {
        return from.disconnect(to);
      } else {
        return from.connect(to);
      }
    }
  });

  window.useGroupConnectionsUI = true;

  window.groupTypes.push({
    name: 'body',
    text: 'Body of a Lean definition or section',
    tooltip: 'Make the selection a body',
    color: '#6666bb',
    imageHTML: '<font color="#6666bb"><b>[ ]</b></font>',
    openImageHTML: '<font color="#6666bb"><b>[</b></font>',
    closeImageHTML: '<font color="#6666bb"><b>]</b></font>',
    contentsChanged: clearAllValidity,
    contextMenuItems: function(group) {
      var name, rename;
      rename = function() {
        var newval;
        newval = prompt('Enter the identifier to use as the name of the namespace.', group.get('namespace'));
        if (newval !== null) {
          if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(newval)) {
            return alert('That was a valid Lean identifier.  No change has been made to your document.');
          } else {
            return group.set('namespace', newval);
          }
        }
      };
      if (!bodyIsASection(group)) {
        return [];
      } else if (name = group.get('namespace')) {
        return [
          {
            text: 'Make this a section',
            onclick: function() {
              return group.clear('namespace');
            }
          }, {
            text: 'Rename this namespace...',
            onclick: rename
          }
        ];
      } else {
        return [
          {
            text: 'Make this a namespace...',
            onclick: rename
          }
        ];
      }
    },
    tagContents: function(group) {
      var name;
      if (bodyIsASection(group)) {
        if (name = group.get('namespace')) {
          return "Namespace: " + name;
        } else {
          return 'Section';
        }
      } else {
        return '';
      }
    },
    connectionRequest: function(from, to) {
      var c, _ref;
      if (to.typeName() !== 'term') {
        return;
      }
      if (_ref = to.id(), __indexOf.call((function() {
        var _i, _len, _ref1, _results;
        _ref1 = from.connectionsOut();
        _results = [];
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          c = _ref1[_i];
          _results.push(c[1]);
        }
        return _results;
      })(), _ref) >= 0) {
        return from.disconnect(to);
      } else if (pathExists(to.id(), from.id())) {
        return alert('That would create a cycle of arrows, which is not permitted.');
      } else {
        return from.connect(to);
      }
    }
  });

  bodyGroupToCode = window.bodyGroupToCode = function(group) {
    var child, children, groups, index, match, results, traverseForBodies, _i, _j, _k, _len, _len1, _ref, _ref1;
    children = (function() {
      var _i, _len, _ref, _results;
      _ref = group.children;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        child = _ref[_i];
        if (child.typeName() === 'term' || child.typeName() === 'body') {
          _results.push(child);
        }
      }
      return _results;
    })();
    if (children.length === 0) {
      return "" + (group.contentAsText()) + " -- " + (group.id());
    }
    _ref = children.slice(0, -1);
    for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
      child = _ref[index];
      if (child.typeName() === 'body') {
        throw Error("A body group can only contain other body groups as its final child.  This one has another body group as child #" + (index + 1) + ".");
      }
    }
    groups = tinymce.activeEditor.Groups;
    traverseForBodies = function(g) {
      var connection, _j, _k, _len1, _len2, _ref1, _ref2, _results;
      _ref1 = g.connectionsIn();
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        connection = _ref1[_j];
        if (groups[connection[0]].typeName() === 'body') {
          throw Error('One of the groups inside this body has a body group connected to it.  That type of nesting is not permitted.');
        }
      }
      _ref2 = g.children;
      _results = [];
      for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
        child = _ref2[_k];
        _results.push(traverseForBodies(child));
      }
      return _results;
    };
    traverseForBodies(group);
    results = [];
    for (_j = 0, _len1 = children.length; _j < _len1; _j++) {
      child = children[_j];
      if (child.typeName() === 'term') {
        if (isSubterm(child)) {
          continue;
        }
        results.push(termGroupToCode(child));
      } else {
        results.push(bodyGroupToCode(child));
      }
    }
    for (index = _k = 0, _ref1 = results.length - 1; 0 <= _ref1 ? _k < _ref1 : _k > _ref1; index = 0 <= _ref1 ? ++_k : --_k) {
      match = /^(.*) -- (\d+)$/.exec(results[index]);
      results[index] = "assume " + match[1] + ", -- " + match[2];
    }
    return results.join('\n');
  };

  sectionGroupToCode = window.sectionGroupToCode = function(group) {
    var child, e, identifier, name, results, suffix, type, _i, _len, _ref;
    name = group.get('namespace');
    type = name ? 'namespace' : 'section';
    suffix = name != null ? name : group.id();
    identifier = (type === 'namespace' ? '' : type) + suffix;
    results = [];
    _ref = group.children;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      child = _ref[_i];
      if (isSubterm(child)) {
        continue;
      }
      try {
        if (child.typeName() === 'term') {
          results.push(termGroupToCode(child));
        } else if (child.typeName() === 'body') {
          if (!bodyIsASection(child)) {
            continue;
          }
          results.push(sectionGroupToCode(child));
        }
      } catch (_error) {
        e = _error;
        markValid(child, false, e.message);
      }
    }
    return "" + type + " " + identifier + " -- " + (group.id()) + "\n " + (results.join('\n')) + "\n end " + identifier + " -- " + (group.id());
  };

  window.afterEditorReady = function(editor) {
    return editor.on('KeyUp', function(event) {
      var allAfter, allBefore, allText, lastCharacter, modifiers, movements, newCursorPos, range, replaceWith, startFrom, toReplace, _ref, _ref1;
      movements = [33, 34, 35, 36, 37, 38, 39, 40];
      modifiers = [16, 17, 18, 91];
      if ((_ref = event.keyCode, __indexOf.call(movements, _ref) >= 0) || (_ref1 = event.keyCode, __indexOf.call(modifiers, _ref1) >= 0)) {
        return;
      }
      range = editor.selection.getRng();
      if (range.startContainer === range.endContainer && range.startContainer instanceof editor.getWin().Text) {
        allText = range.startContainer.textContent;
        lastCharacter = allText[range.startOffset - 1];
        if (lastCharacter !== ' ' && lastCharacter !== '\\' && lastCharacter !== String.fromCharCode(160)) {
          return;
        }
        allBefore = allText.substr(0, range.startOffset - 1);
        allAfter = allText.substring(range.startOffset - 1);
        startFrom = allBefore.lastIndexOf('\\');
        if (startFrom === -1) {
          return;
        }
        toReplace = allBefore.substr(startFrom + 1);
        allBefore = allBefore.substr(0, startFrom);
        if (!(replaceWith = corrections[toReplace])) {
          return;
        }
        newCursorPos = range.startOffset - toReplace.length - 1 + replaceWith.length;
        if (lastCharacter !== '\\') {
          allAfter = allAfter.substr(1);
          newCursorPos--;
        }
        range.startContainer.textContent = allBefore + replaceWith + allAfter;
        range.setStart(range.startContainer, newCursorPos);
        range.setEnd(range.startContainer, newCursorPos);
        return editor.selection.setRng(range);
      }
    });
  };

}).call(this);

//# sourceMappingURL=lean-example-solo.js.map

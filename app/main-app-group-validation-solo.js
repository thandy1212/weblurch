// Generated by CoffeeScript 1.8.0
(function() {
  var ruleLanguages,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  window.Group.prototype.saveValidation = function(data) {
    var color, symbol, _ref, _ref1;
    if (data === null) {
      if (this.wasValidated()) {
        if ((_ref = this.plugin) != null) {
          _ref.editor.undoManager.transact((function(_this) {
            return function() {
              _this.clear('validation');
              _this.clear('closeDecoration');
              return _this.clear('closeHoverText');
            };
          })(this));
        }
      }
      return;
    }
    color = data.result === 'valid' ? 'green' : data.result === 'invalid' ? 'red' : 'gray';
    symbol = data.result === 'valid' ? '&#10003;' : data.result === 'invalid' ? '&#10006;' : '...';
    return (_ref1 = this.plugin) != null ? _ref1.editor.undoManager.transact((function(_this) {
      return function() {
        _this.set('validation', data);
        _this.set('closeDecoration', "<font color='" + color + "'>" + symbol + "</font>");
        return _this.set('closeHoverText', "" + data.message + "\n(Double-click for details.)");
      };
    })(this)) : void 0;
  };

  window.Group.prototype.getValidation = function() {
    return this.get('validation');
  };

  window.Group.prototype.wasValidated = function() {
    return this.getValidation() != null;
  };

  window.afterEditorReadyArray.push(function(editor) {
    var oldHandler;
    oldHandler = editor.Groups.groupTypes.expression.contentsChanged;
    editor.Groups.groupTypes.expression.contentsChanged = function(group, firstTime) {
      oldHandler(group, firstTime);
      return setTimeout(function() {
        var addCitersToRevalidateList, addToRevalidateList, groupsToRevalidate, needsRevalidation, recursivelyMarkForRevalidation, _i, _len, _results;
        groupsToRevalidate = [];
        addToRevalidateList = function(newGroup) {
          if (__indexOf.call(groupsToRevalidate, newGroup) < 0) {
            return groupsToRevalidate.push(newGroup);
          }
        };
        addCitersToRevalidateList = function(ruleGroup, everything) {
          var allIds, citer, id, namesForRule, reason, reasons, start, text, _i, _j, _len, _len1, _ref;
          if (everything == null) {
            everything = false;
          }
          if (ruleGroup.lookupAttributes('rule').length === 0) {
            return;
          }
          allIds = editor.Groups.ids();
          if ((start = allIds.indexOf(ruleGroup.id())) === -1) {
            return;
          }
          namesForRule = window.lookupLabelsFor(ruleGroup);
          _ref = allIds.slice(start);
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            id = _ref[_i];
            if (!(citer = editor.Groups[id])) {
              continue;
            }
            reasons = citer.lookupAttributes('reason');
            if (everything && reasons.length > 0) {
              return addToRevalidateList(citer);
            }
            for (_j = 0, _len1 = reasons.length; _j < _len1; _j++) {
              reason = reasons[_j];
              text = reason instanceof OM ? reason.value : reason.contentAsText();
              if (__indexOf.call(namesForRule, text) >= 0) {
                addToRevalidateList(citer);
              }
            }
          }
        };
        recursivelyMarkForRevalidation = function(fromHere, lastStep) {
          var connection, key, _i, _len, _ref, _results;
          addToRevalidateList(fromHere);
          addCitersToRevalidateList(fromHere, lastStep === 'label');
          key = fromHere.get('key');
          if (key && key !== 'premise') {
            _ref = fromHere.connectionsOut();
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              connection = _ref[_i];
              _results.push(recursivelyMarkForRevalidation(editor.Groups[connection[1]], key));
            }
            return _results;
          }
        };
        recursivelyMarkForRevalidation(group);
        _results = [];
        for (_i = 0, _len = groupsToRevalidate.length; _i < _len; _i++) {
          needsRevalidation = groupsToRevalidate[_i];
          _results.push(needsRevalidation.validate());
        }
        return _results;
      }, 0);
    };
    return editor.on('dependencyLabelsUpdated', function(event) {
      var citer, id, reason, text, _i, _len, _ref, _results;
      _ref = editor.Groups.ids();
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        id = _ref[_i];
        if (!(citer = editor.Groups[id])) {
          continue;
        }
        _results.push((function() {
          var _j, _len1, _ref1, _results1;
          _ref1 = citer.lookupAttributes('reason');
          _results1 = [];
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            reason = _ref1[_j];
            text = reason instanceof OM ? reason.value : reason.contentAsText();
            if (__indexOf.call(event.oldAndNewLabels, text) >= 0) {
              _results1.push(citer.validate());
            } else {
              _results1.push(void 0);
            }
          }
          return _results1;
        })());
      }
      return _results;
    });
  });

  window.Group.prototype.validate = function() {
    var e, _base;
    if ((_base = this.plugin.editor.LoadSave).validationsPending == null) {
      _base.validationsPending = {};
    }
    this.plugin.editor.LoadSave.validationsPending[this.id()] = true;
    try {
      return this.computeValidationAsync((function(_this) {
        return function(result) {
          var e;
          try {
            _this.saveValidation(result);
            return delete _this.plugin.editor.LoadSave.validationsPending[_this.id()];
          } catch (_error) {
            e = _error;
            delete _this.plugin.editor.LoadSave.validationsPending[_this.id()];
            throw e;
          }
        };
      })(this));
    } catch (_error) {
      e = _error;
      delete this.plugin.editor.LoadSave.validationsPending[this.id()];
      throw e;
    }
  };

  window.Group.prototype.computeValidationAsync = function(callback, verbose) {
    if (verbose == null) {
      verbose = false;
    }
    if (this.lookupAttributes('rule').length > 0) {
      return this.computeRuleValidationAsync(callback, verbose);
    }
    if ((this.lookupAttributes('reason')).length === 0) {
      return callback(null);
    }
    return this.computeStepValidationAsync(callback, verbose);
  };

  ruleLanguages = ['JavaScript'];

  window.Group.prototype.computeRuleValidationAsync = function(callback, verbose) {
    var index, language, languages, r, validationData, _i, _len, _ref;
    if ((this.lookupAttributes('reason')).length > 0) {
      validationData = {
        result: 'invalid',
        message: 'You may not attempt to justify a rule using a reason.  Rule validity is determined solely by the rule\'s structure.'
      };
      if (verbose) {
        validationData.verbose = 'Try removing all reason attributes from the rule.';
      }
      return callback(validationData);
    }
    languages = this.lookupAttributes('code');
    if (languages.length === 0) {
      validationData = {
        result: 'invalid',
        message: 'Only code-based rules are supported at this time.  This rule does not have a code attribute.'
      };
      if (verbose) {
        validationData.verbose = "<p>Try adding an attribute with key \"code\" and value equal to the name of the language in which the code is written.  Supported languages:</p> <ul><li>" + (ruleLanguages.join('</li><li>')) + "</li></ul>";
      }
      return callback(validationData);
    }
    for (index = _i = 0, _len = languages.length; _i < _len; index = ++_i) {
      language = languages[index];
      languages[index] = language instanceof OM ? language.value : language.canonicalForm().value;
    }
    if (languages.length > 1) {
      validationData = {
        result: 'invalid',
        message: 'This code-based rule has more than one language specified, which is ambiguous.'
      };
      if (verbose) {
        validationData.verbose = "Too many languages specified for the rule.  Only one is permitted. You specified: " + (languages.join(',')) + ".";
      }
      return callback(validationData);
    }
    if (_ref = languages[0].toLowerCase(), __indexOf.call((function() {
      var _j, _len1, _results;
      _results = [];
      for (_j = 0, _len1 = ruleLanguages.length; _j < _len1; _j++) {
        r = ruleLanguages[_j];
        _results.push(r.toLowerCase());
      }
      return _results;
    })(), _ref) < 0) {
      validationData = {
        result: 'invalid',
        message: "Code rules must be written in " + (ruleLanguages.join('/')) + "."
      };
      if (verbose) {
        validationData.verbose = "<p>The current version of Lurch supports only code-based rules written in one of the following languages.  The rule you cited is written in " + languages[0] + ", and thus cannot be used.</p> <ul><li>" + (ruleLanguages.join('</li><li>')) + "</li></ul>";
      }
      return callback(validationData);
    }
    return callback({
      result: 'valid',
      message: 'This is a valid code-based rule.'
    });
  };

  window.Group.prototype.computeStepValidationAsync = function(callback, verbose) {
    var citedExpressions, expression, isValidRule, labelPairs, language, numFromDependencies, pair, r, reason, reasonText, reasons, rule, rules, validRules, validationData, wrappedCode, _i, _len, _ref;
    reasons = this.lookupAttributes('reason');
    if (reasons.length > 1) {
      validationData = {
        result: 'invalid',
        message: 'You may not attach more than one reason to an expression.'
      };
      if (verbose) {
        validationData.verbose = '<p>The following reasons are attached to the expression:</p><ul>';
        for (_i = 0, _len = reasons.length; _i < _len; _i++) {
          reason = reasons[_i];
          validationData.verbose += reason instanceof OM ? "<li>Hidden: " + reason.value + "</li>" : "<li>Visible: " + (reason.contentAsText()) + "</li>";
        }
        validationData.verbose += '</ul>';
      }
      return callback(validationData);
    }
    reason = reasons[0];
    reasonText = reason instanceof OM ? reason.value : reason.contentAsText();
    labelPairs = lookupLabel(reasonText);
    if (labelPairs.length === 0) {
      validationData = {
        result: 'invalid',
        message: "No rule called " + reasonText + " is accessible here."
      };
      if (verbose) {
        validationData.verbose = validationData.message;
      }
      return callback(validationData);
    }
    citedExpressions = (function() {
      var _j, _len1, _results;
      _results = [];
      for (_j = 0, _len1 = labelPairs.length; _j < _len1; _j++) {
        pair = labelPairs[_j];
        if (pair.target instanceof OM) {
          _results.push(pair.target);
        } else {
          _results.push(pair.target.completeForm());
        }
      }
      return _results;
    })();
    rules = (function() {
      var _j, _len1, _results;
      _results = [];
      for (_j = 0, _len1 = citedExpressions.length; _j < _len1; _j++) {
        expression = citedExpressions[_j];
        if (expression.getAttribute(OM.sym('rule', 'Lurch'))) {
          _results.push(expression);
        }
      }
      return _results;
    })();
    if (rules.length === 0) {
      validationData = {
        result: 'invalid',
        message: 'The cited reason is not the name of a rule.'
      };
      if (verbose) {
        numFromDependencies = ((function() {
          var _j, _len1, _results;
          _results = [];
          for (_j = 0, _len1 = labelPairs.length; _j < _len1; _j++) {
            pair = labelPairs[_j];
            if (pair.target instanceof OM) {
              _results.push(pair);
            }
          }
          return _results;
        })()).length;
        validationData.verbose = "The cited reason, \"" + reasonText + ",\" is the name of " + numFromDependencies + " expressions imported from other documents, and " + (labelPairs.length - numFromDependencies) + " expressions in this document, accessible from the citation.  None of those expressions is a rule.";
      }
      return callback(validationData);
    }
    isValidRule = function(rule) {
      var ruleValidationData;
      ruleValidationData = rule.getAttribute(OM.sym('validation', 'Lurch'));
      if (ruleValidationData == null) {
        return false;
      }
      try {
        return JSON.parse(ruleValidationData.value).result === 'valid';
      } catch (_error) {
        return false;
      }
    };
    validRules = (function() {
      var _j, _len1, _results;
      _results = [];
      for (_j = 0, _len1 = rules.length; _j < _len1; _j++) {
        rule = rules[_j];
        if (isValidRule(rule)) {
          _results.push(rule);
        }
      }
      return _results;
    })();
    if (validRules.length === 0) {
      validationData = {
        result: 'invalid',
        message: 'None of the cited rule are valid.'
      };
      if (verbose) {
        validationData.verbose = "Although there are " + rules.length + " rules called \"" + reasonText + ",\" none of them have been successfully validated.  Only a valid rule can be used to justify an expression.";
      }
      return callback(validationData);
    }
    if (validRules.length > 1) {
      validationData = {
        result: 'invalid',
        message: 'You may cite at most one valid rule.'
      };
      if (verbose) {
        validationData.verbose = "The reason \"" + reasonText + "\" refers to " + validRules.length + " valid rules.  Only one valid rule can be used at a time to justify an expression.";
      }
      return callback(validationData);
    }
    rule = validRules[0];
    language = rule.getAttribute(OM.sym('code', 'Lurch'));
    if (!language) {
      validationData = {
        result: 'invalid',
        message: 'Only code-based rules are supported.'
      };
      if (verbose) {
        validationData.verbose = "The current version of Lurch supports only code-based rules.  The rule you cited is not a piece of code, and thus cannot be used.";
      }
      return callback(validationData);
    }
    if (_ref = language.value.toLowerCase(), __indexOf.call((function() {
      var _j, _len1, _results;
      _results = [];
      for (_j = 0, _len1 = ruleLanguages.length; _j < _len1; _j++) {
        r = ruleLanguages[_j];
        _results.push(r.toLowerCase());
      }
      return _results;
    })(), _ref) < 0) {
      validationData = {
        result: 'invalid',
        message: "Code rules must be written in " + (ruleLanguages.join('/')) + "."
      };
      if (verbose) {
        validationData.verbose = "<p>The current version of Lurch supports only code-based rules written in one of the following languages.  The rule you cited is written in " + language.value + ", and thus cannot be used.</p> <ul><li>" + (ruleLanguages.join('</li><li>')) + "</li></ul>";
      }
      return callback(validationData);
    }
    wrappedCode = "function () { var conclusion = OM.decode( arguments[0] ); var premises = [ ]; for ( var i = 1 ; i < arguments.length ; i++ ) premises.push( OM.decode( arguments[i] ) ); " + rule.value + " }";
    return Background.addCodeTask(wrappedCode, [this], (function(_this) {
      return function(result) {
        return callback(result != null ? result : {
          result: 'invalid',
          message: 'The code in the rule did not run successfully.',
          verbose: 'The background process in which the code was to be run returned no value, so the code has an error.'
        });
      };
    })(this), void 0, ['openmath-duo.min.js']);
  };

}).call(this);

//# sourceMappingURL=main-app-group-validation-solo.js.map
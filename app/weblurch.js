// Generated by CoffeeScript 1.8.0
(function() {
  var BackgroundFunction, addToCache, cacheLookup, drawHTMLCache, makeBlob, markUsed, pruneCache,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __slice = [].slice,
    __hasProp = {}.hasOwnProperty,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  window.Background = {
    functions: {},
    registerFunction: function(name, func) {
      return window.Background.functions[name] = func;
    },
    runningTasks: [],
    waitingTasks: [],
    addTask: function(funcName, inputGroups, callback) {
      var group, index, newTask, task, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3;
      newTask = {
        name: funcName,
        inputs: inputGroups,
        callback: callback,
        id: "" + funcName + "," + ((function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = inputGroups.length; _i < _len; _i++) {
            group = inputGroups[_i];
            _results.push(group.id());
          }
          return _results;
        })())
      };
      _ref = window.Background.waitingTasks;
      for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
        task = _ref[index];
        if (task.id === newTask.id) {
          window.Background.waitingTasks.splice(index, 1);
          break;
        }
      }
      _ref1 = window.Background.runningTasks;
      for (index = _j = 0, _len1 = _ref1.length; _j < _len1; index = ++_j) {
        task = _ref1[index];
        if (task.id === newTask.id) {
          if ((_ref2 = task.runner) != null) {
            if ((_ref3 = _ref2.worker) != null) {
              if (typeof _ref3.terminate === "function") {
                _ref3.terminate();
              }
            }
          }
          window.Background.runningTasks.splice(index, 1);
          break;
        }
      }
      window.Background.waitingTasks.push(newTask);
      return window.Background.update();
    },
    available: {},
    update: function() {
      var B, func, runner, toStart, _ref;
      B = window.Background;
      while (B.runningTasks.length < B.concurrency()) {
        if ((toStart = B.waitingTasks.shift()) == null) {
          return;
        }
        runner = (_ref = B.available[toStart.name]) != null ? _ref.pop() : void 0;
        if (runner == null) {
          func = B.functions[toStart.name];
          if (func == null) {
            continue;
          }
          runner = new BackgroundFunction(func);
        }
        toStart.runner = runner;
        B.runningTasks.push(toStart);
        (function(toStart) {
          var cleanup;
          cleanup = function() {
            var index, _base, _name;
            index = B.runningTasks.indexOf(toStart);
            B.runningTasks.splice(index, 1);
            ((_base = B.available)[_name = toStart.name] != null ? _base[_name] : _base[_name] = []).push(runner);
            return window.Background.update();
          };
          return runner.call.apply(runner, toStart.inputs).sendTo(function(result) {
            cleanup();
            return typeof toStart.callback === "function" ? toStart.callback(result) : void 0;
          }).orElse(cleanup);
        })(toStart);
      }
    }
  };

  navigator.getHardwareConcurrency(function() {});

  window.Background.concurrency = function() {
    var _ref;
    return Math.max(1, ((_ref = navigator.hardwareConcurrency) != null ? _ref : 1) - 1);
  };

  BackgroundFunction = (function() {
    function _Class(_function) {
      this["function"] = _function;
      this.call = __bind(this.call, this);
      this.promise = {
        sendTo: (function(_this) {
          return function(callback) {
            _this.promise.resultCallback = callback;
            if (_this.promise.hasOwnProperty('result')) {
              _this.promise.resultCallback(_this.promise.result);
            }
            return _this.promise;
          };
        })(this),
        orElse: (function(_this) {
          return function(callback) {
            _this.promise.errorCallback = callback;
            if (_this.promise.hasOwnProperty('error')) {
              _this.promise.errorCallback(_this.promise.error);
            }
            return _this.promise;
          };
        })(this)
      };
      if (window.Worker) {
        this.worker = new window.Worker('worker.solo.js');
        this.worker.addEventListener('message', (function(_this) {
          return function(event) {
            var _ref;
            _this.promise.result = event.data;
            return (_ref = _this.promise) != null ? typeof _ref.resultCallback === "function" ? _ref.resultCallback(event.data) : void 0 : void 0;
          };
        })(this), false);
        this.worker.addEventListener('error', (function(_this) {
          return function(event) {
            var _ref;
            _this.promise.error = event;
            return (_ref = _this.promise) != null ? typeof _ref.errorCallback === "function" ? _ref.errorCallback(event) : void 0 : void 0;
          };
        })(this), false);
        this.worker.postMessage({
          setFunction: "" + this["function"]
        });
      }
    }

    _Class.prototype.call = function() {
      var args, group, groups, _i, _len;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      delete this.promise.result;
      delete this.promise.resultCallback;
      delete this.promise.error;
      delete this.promise.errorCallback;
      for (_i = 0, _len = arguments.length; _i < _len; _i++) {
        group = arguments[_i];
        if (group.deleted) {
          return;
        }
      }
      groups = (function() {
        var _j, _len1, _results;
        _results = [];
        for (_j = 0, _len1 = args.length; _j < _len1; _j++) {
          group = args[_j];
          _results.push(group.toJSON());
        }
        return _results;
      })();
      if (this.worker != null) {
        this.worker.postMessage({
          runOn: groups
        });
      } else {
        setTimeout((function(_this) {
          return function() {
            var e, _base, _base1;
            try {
              _this.promise.result = _this["function"].apply(_this, groups);
            } catch (_error) {
              e = _error;
              _this.promise.error = e;
              if (typeof (_base = _this.promise).errorCallback === "function") {
                _base.errorCallback(_this.promise.error);
              }
              return;
            }
            return typeof (_base1 = _this.promise).resultCallback === "function" ? _base1.resultCallback(_this.promise.result) : void 0;
          };
        })(this), 0);
      }
      return this.promise;
    };

    return _Class;

  })();

  CanvasRenderingContext2D.prototype.roundedRect = function(x1, y1, x2, y2, radius) {
    this.beginPath();
    this.moveTo(x1 + radius, y1);
    this.lineTo(x2 - radius, y1);
    this.arcTo(x2, y1, x2, y1 + radius, radius);
    this.lineTo(x2, y2 - radius);
    this.arcTo(x2, y2, x2 - radius, y2, radius);
    this.lineTo(x1 + radius, y2);
    this.arcTo(x1, y2, x1, y2 - radius, radius);
    this.lineTo(x1, y1 + radius);
    this.arcTo(x1, y1, x1 + radius, y1, radius);
    return this.closePath();
  };

  CanvasRenderingContext2D.prototype.roundedZone = function(x1, y1, x2, y2, upperLine, lowerLine, leftMargin, rightMargin, radius) {
    this.beginPath();
    this.moveTo(x1 + radius, y1);
    this.lineTo(this.canvas.width - rightMargin, y1);
    this.lineTo(this.canvas.width - rightMargin, lowerLine);
    this.lineTo(x2, lowerLine);
    this.lineTo(x2, y2 - radius);
    this.arcTo(x2, y2, x2 - radius, y2, radius);
    this.lineTo(leftMargin, y2);
    this.lineTo(leftMargin, upperLine);
    this.lineTo(x1, upperLine);
    this.lineTo(x1, y1 + radius);
    this.arcTo(x1, y1, x1 + radius, y1, radius);
    return this.closePath();
  };

  window.rectanglesCollide = function(x1, y1, x2, y2, x3, y3, x4, y4) {
    return !(x3 >= x2 || x4 <= x1 || y3 >= y2 || y4 <= y1);
  };

  window.imageURLForHTML = function(html, style) {
    var data, height, span, width, _ref, _ref1;
    if (style == null) {
      style = 'font-size:12px';
    }
    span = document.createElement('span');
    span.setAttribute('style', style);
    span.innerHTML = html;
    document.body.appendChild(span);
    span = $(span);
    width = span.width() + 2;
    height = span.height() + 2;
    span.remove();
    data = "<svg xmlns='http://www.w3.org/2000/svg' width='" + width + "' height='" + height + "'><foreignObject width='100%' height='100%'><div xmlns='http://www.w3.org/1999/xhtml' style='" + style + "'>" + html + "</div></foreignObject></svg>";
    return ((_ref = (_ref1 = window.URL) != null ? _ref1 : window.webkitURL) != null ? _ref : window).createObjectURL(makeBlob(data, 'image/svg+xml;charset=utf-8'));
  };

  makeBlob = function(data, type) {
    var bb, e, _ref, _ref1, _ref2;
    try {
      return new Blob([data], {
        type: type
      });
    } catch (_error) {
      e = _error;
      window.BlobBuilder = (_ref = (_ref1 = (_ref2 = window.BlobBuilder) != null ? _ref2 : window.WebKitBlobBuilder) != null ? _ref1 : window.MozBlobBuilder) != null ? _ref : window.MSBlobBuilder;
      if (e.name === 'TypeError' && (window.BlobBuilder != null)) {
        bb = new BlobBuilder();
        bb.append(data.buffer);
        return bb.getBlob(type);
      } else if (e.name === 'InvalidStateError') {
        return new Blob([data.buffer], {
          type: type
        });
      }
    }
  };

  drawHTMLCache = {
    order: [],
    maxSize: 100
  };

  cacheLookup = function(html, style) {
    var key;
    key = JSON.stringify([html, style]);
    if (drawHTMLCache.hasOwnProperty(key)) {
      return drawHTMLCache[key];
    } else {
      return null;
    }
  };

  addToCache = function(html, style, image) {
    var key;
    key = JSON.stringify([html, style]);
    drawHTMLCache[key] = image;
    return markUsed(html, style);
  };

  markUsed = function(html, style) {
    var index, key;
    key = JSON.stringify([html, style]);
    if ((index = drawHTMLCache.order.indexOf(key)) > -1) {
      drawHTMLCache.order.splice(index, 1);
    }
    drawHTMLCache.order.unshift(key);
    return pruneCache();
  };

  pruneCache = function() {
    var _results;
    _results = [];
    while (drawHTMLCache.order.length > drawHTMLCache.maxSize) {
      _results.push(delete drawHTMLCache[drawHTMLCache.order.pop()]);
    }
    return _results;
  };

  CanvasRenderingContext2D.prototype.drawHTML = function(html, x, y, style) {
    var image, url;
    if (style == null) {
      style = 'font-size:12px';
    }
    if (image = cacheLookup(html, style)) {
      this.drawImage(image, x, y);
      markUsed(html, style);
      return true;
    }
    url = imageURLForHTML(html, style);
    image = new Image();
    image.onload = function() {
      var _ref, _ref1;
      addToCache(html, style, image);
      return ((_ref = (_ref1 = window.URL) != null ? _ref1 : window.webkitURL) != null ? _ref : window).revokeObjectURL(url);
    };
    image.onerror = function(error) {
      addToCache(html, style, new Image());
      return console.log('Failed to load SVG with this <foreignObject> div content:', html);
    };
    image.src = url;
    return false;
  };

  CanvasRenderingContext2D.prototype.measureHTML = function(html, style) {
    var image;
    if (style == null) {
      style = 'font-size:12px';
    }
    if (image = cacheLookup(html, style)) {
      markUsed(html, style);
      return {
        width: image.width,
        height: image.height
      };
    } else {
      this.drawHTML(html, 0, 0, style);
      return null;
    }
  };

  window.installDOMUtilitiesIn = function(window) {
    window.Node.prototype.address = function(ancestor) {
      var recur;
      if (ancestor == null) {
        ancestor = null;
      }
      if (this === ancestor) {
        return [];
      }
      if (!this.parentNode) {
        if (ancestor) {
          return null;
        } else {
          return [];
        }
      }
      recur = this.parentNode.address(ancestor);
      if (recur === null) {
        return null;
      }
      return recur.concat([this.indexInParent()]);
    };
    window.Node.prototype.indexInParent = function() {
      if (this.parentNode) {
        return Array.prototype.slice.apply(this.parentNode.childNodes).indexOf(this);
      } else {
        return -1;
      }
    };
    window.Node.prototype.index = function(address) {
      var _ref;
      if (!(address instanceof Array)) {
        throw Error('Node address function requires an array');
      }
      if (address.length === 0) {
        return this;
      }
      if (typeof address[0] !== 'number') {
        return void 0;
      }
      return (_ref = this.childNodes[address[0]]) != null ? _ref.index(address.slice(1)) : void 0;
    };
    window.Node.prototype.toJSON = function(verbose) {
      var attribute, chi, result, _i, _len, _ref;
      if (verbose == null) {
        verbose = true;
      }
      if (this instanceof window.Text) {
        return this.textContent;
      }
      if (this instanceof window.Comment) {
        if (verbose) {
          return {
            comment: true,
            content: this.textContent
          };
        } else {
          return {
            m: true,
            n: this.textContent
          };
        }
      }
      if (!(this instanceof window.Element)) {
        throw Error("Cannot serialize this node: " + this);
      }
      result = {
        tagName: this.tagName
      };
      if (this.attributes.length) {
        result.attributes = {};
        _ref = this.attributes;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          attribute = _ref[_i];
          result.attributes[attribute.name] = attribute.value;
        }
      }
      if (this.childNodes.length) {
        result.children = (function() {
          var _j, _len1, _ref1, _results;
          _ref1 = this.childNodes;
          _results = [];
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            chi = _ref1[_j];
            _results.push(chi.toJSON(verbose));
          }
          return _results;
        }).call(this);
      }
      if (!verbose) {
        result.t = result.tagName;
        delete result.tagName;
        result.a = result.attributes;
        delete result.attributes;
        result.c = result.children;
        delete result.children;
      }
      return result;
    };
    window.Node.fromJSON = function(json) {
      var attributes, child, children, key, result, value, _i, _len;
      if (typeof json === 'string') {
        return window.document.createTextNode(json);
      }
      if ('comment' in json && json.comment) {
        return window.document.createComment(json.content);
      }
      if ('m' in json && json.m) {
        return window.document.createComment(json.n);
      }
      if (!'tagName' in json && !'t' in json) {
        throw Error("Object has no t[agName]: " + this);
      }
      result = window.document.createElement(json.tagName || json.t);
      if (attributes = json.attributes || json.a) {
        for (key in attributes) {
          if (!__hasProp.call(attributes, key)) continue;
          value = attributes[key];
          result.setAttribute(key, value);
        }
      }
      if (children = json.children || json.c) {
        for (_i = 0, _len = children.length; _i < _len; _i++) {
          child = children[_i];
          result.appendChild(Node.fromJSON(child));
        }
      }
      return result;
    };
    window.Node.prototype.nextLeaf = function(container) {
      var walk;
      if (container == null) {
        container = null;
      }
      walk = this;
      while (walk && walk !== container && !walk.nextSibling) {
        walk = walk.parentNode;
      }
      walk = walk != null ? walk.nextSibling : void 0;
      if (!walk) {
        return null;
      }
      while (walk.childNodes.length > 0) {
        walk = walk.childNodes[0];
      }
      return walk;
    };
    window.Node.prototype.previousLeaf = function(container) {
      var walk;
      if (container == null) {
        container = null;
      }
      walk = this;
      while (walk && walk !== container && !walk.previousSibling) {
        walk = walk.parentNode;
      }
      walk = walk != null ? walk.previousSibling : void 0;
      if (!walk) {
        return null;
      }
      while (walk.childNodes.length > 0) {
        walk = walk.childNodes[walk.childNodes.length - 1];
      }
      return walk;
    };
    window.Node.prototype.remove = function() {
      var _ref;
      return (_ref = this.parentNode) != null ? _ref.removeChild(this) : void 0;
    };
    window.Element.prototype.hasClass = function(name) {
      var classes, _ref;
      classes = (_ref = this.getAttribute('class')) != null ? _ref.split(/\s+/) : void 0;
      return classes && __indexOf.call(classes, name) >= 0;
    };
    window.Element.prototype.addClass = function(name) {
      var classes, _ref;
      classes = ((_ref = this.getAttribute('class')) != null ? _ref.split(/\s+/) : void 0) || [];
      if (__indexOf.call(classes, name) < 0) {
        classes.push(name);
      }
      return this.setAttribute('class', classes.join(' '));
    };
    window.Element.prototype.removeClass = function(name) {
      var c, classes, _ref;
      classes = ((_ref = this.getAttribute('class')) != null ? _ref.split(/\s+/) : void 0) || [];
      classes = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = classes.length; _i < _len; _i++) {
          c = classes[_i];
          if (c !== name) {
            _results.push(c);
          }
        }
        return _results;
      })();
      if (classes.length > 0) {
        return this.setAttribute('class', classes.join(' '));
      } else {
        return this.removeAttribute('class');
      }
    };
    return window.document.nodeFromPoint = function(x, y) {
      var elt, node, range, rect, _i, _j, _len, _len1, _ref, _ref1;
      elt = window.document.elementFromPoint(x, y);
      _ref = elt.childNodes;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        node = _ref[_i];
        if (node instanceof window.Text) {
          range = window.document.createRange();
          range.selectNode(node);
          _ref1 = range.getClientRects();
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            rect = _ref1[_j];
            if ((rect.left < x && x < rect.right) && (rect.top < y && y < rect.bottom)) {
              return node;
            }
          }
        }
      }
      return elt;
    };
  };

  installDOMUtilitiesIn(window);

  JSON.equals = function(x, y) {
    var key, xkeys, ykeys, _i, _len;
    if ((x instanceof Object) !== (y instanceof Object)) {
      return false;
    }
    if ((x instanceof Array) !== (y instanceof Array)) {
      return false;
    }
    if (!(x instanceof Object)) {
      return x === y;
    }
    xkeys = (Object.keys(x)).sort();
    ykeys = (Object.keys(y)).sort();
    if ((JSON.stringify(xkeys)) !== (JSON.stringify(ykeys))) {
      return false;
    }
    for (_i = 0, _len = xkeys.length; _i < _len; _i++) {
      key = xkeys[_i];
      if (!JSON.equals(x[key], y[key])) {
        return false;
      }
    }
    return true;
  };

}).call(this);

//# sourceMappingURL=weblurch.js.map

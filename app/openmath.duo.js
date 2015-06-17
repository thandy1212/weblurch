// Generated by CoffeeScript 1.8.0
(function() {
  var OMNode, exports, _ref,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __slice = [].slice,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  if (typeof exports === "undefined" || exports === null) {
    exports = (_ref = typeof module !== "undefined" && module !== null ? module.exports : void 0) != null ? _ref : window;
  }

  exports.OMNode = OMNode = (function() {
    OMNode.checkJSON = function(object) {
      var checkKeys, child, e, identRE, key, reason, symbol, value, variable, _i, _j, _k, _len, _len1, _len2, _ref1, _ref2, _ref3, _ref4;
      if (!(object instanceof Object)) {
        return "Expected an object, found " + (typeof object);
      }
      if (object.hasOwnProperty('a')) {
        _ref1 = object.a;
        for (key in _ref1) {
          if (!__hasProp.call(_ref1, key)) continue;
          value = _ref1[key];
          try {
            symbol = JSON.parse(key);
          } catch (_error) {
            e = _error;
            return "Key " + key + " invalid JSON";
          }
          if (symbol.t !== 'sy') {
            return "Key " + key + " is not a symbol";
          }
          if (reason = this.checkJSON(symbol)) {
            return reason;
          }
          if (reason = this.checkJSON(value)) {
            return reason;
          }
        }
      }
      checkKeys = function() {
        var list, _i, _len, _ref2;
        list = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        _ref2 = Object.keys(object);
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          key = _ref2[_i];
          if (__indexOf.call(list, key) < 0 && key !== 't' && key !== 'a') {
            return "Key " + key + " not valid in object of type " + object.t;
          }
        }
        return null;
      };
      identRE = /^[:A-Za-z_][:A-Za-z_.0-9-]*$/;
      switch (object.t) {
        case 'i':
          if (reason = checkKeys('v')) {
            return reason;
          }
          if (!/^[+-]?[0-9]+$/.test("" + object.v)) {
            return "Not an integer: " + object.v;
          }
          break;
        case 'f':
          if (reason = checkKeys('v')) {
            return reason;
          }
          if (typeof object.v !== 'number') {
            return "Not a number: " + object.v + " of type " + (typeof object.v);
          }
          if (isNaN(object.v)) {
            return 'OpenMath floats cannot be NaN';
          }
          if (!isFinite(object.v)) {
            return 'OpenMath floats must be finite';
          }
          break;
        case 'st':
          if (reason = checkKeys('v')) {
            return reason;
          }
          if (typeof object.v !== 'string') {
            return "Value for st type was " + (typeof object.v) + ", not string";
          }
          break;
        case 'ba':
          if (reason = checkKeys('v')) {
            return reason;
          }
          if (!(object.v instanceof Uint8Array)) {
            return "Value for ba type was not an instance of Uint8Array";
          }
          break;
        case 'sy':
          if (reason = checkKeys('n', 'cd', 'uri')) {
            return reason;
          }
          if (typeof object.n !== 'string') {
            return "Name for sy type was " + (typeof object.n) + ", not string";
          }
          if (typeof object.cd !== 'string') {
            return "CD for sy type was " + (typeof object.cd) + ", not string";
          }
          if ((object.uri != null) && typeof object.uri !== 'string') {
            return "URI for sy type was " + (typeof object.uri) + ", not string";
          }
          if (!identRE.test(object.n)) {
            return "Invalid identifier as symbol name: " + object.n;
          }
          if (!identRE.test(object.cd)) {
            return "Invalid identifier as symbol CD: " + object.cd;
          }
          break;
        case 'v':
          if (reason = checkKeys('n')) {
            return reason;
          }
          if (typeof object.n !== 'string') {
            return "Name for v type was " + (typeof object.n) + ", not string";
          }
          if (!identRE.test(object.n)) {
            return "Invalid identifier as variable name: " + object.n;
          }
          break;
        case 'a':
          if (reason = checkKeys('c')) {
            return reason;
          }
          if (!(object.c instanceof Array)) {
            return "Children of application object was not an array";
          }
          if (object.c.length === 0) {
            return "Application object must have at least one child";
          }
          _ref2 = object.c;
          for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
            child = _ref2[_i];
            if (reason = this.checkJSON(child)) {
              return reason;
            }
          }
          break;
        case 'bi':
          if (reason = checkKeys('s', 'v', 'b')) {
            return reason;
          }
          if (reason = this.checkJSON(object.s)) {
            return reason;
          }
          if (object.s.t !== 'sy') {
            return "Head of a binding must be a symbol";
          }
          if (!(object.v instanceof Array)) {
            return "In a binding, the v value must be an array";
          }
          _ref3 = object.v;
          for (_j = 0, _len1 = _ref3.length; _j < _len1; _j++) {
            variable = _ref3[_j];
            if (reason = this.checkJSON(variable)) {
              return reason;
            }
            if (variable.t !== 'v') {
              return "In a binding, all values in the v array must have type v";
            }
          }
          if (reason = this.checkJSON(object.b)) {
            return reason;
          }
          break;
        case 'e':
          if (reason = checkKeys('s', 'c')) {
            return reason;
          }
          if (reason = this.checkJSON(object.s)) {
            return reason;
          }
          if (object.s.t !== 'sy') {
            return "Head of an error must be a symbol";
          }
          if (!(object.c instanceof Array)) {
            return "In an error, the c key must be an array";
          }
          _ref4 = object.c;
          for (_k = 0, _len2 = _ref4.length; _k < _len2; _k++) {
            child = _ref4[_k];
            if (reason = this.checkJSON(child)) {
              return reason;
            }
          }
          break;
        default:
          return "Invalid type: " + object.t;
      }
      return null;
    };

    OMNode.decode = function(JSONstring) {
      var e, object, reason, setParents;
      try {
        object = JSON.parse(JSONstring);
      } catch (_error) {
        e = _error;
        return e.message;
      }
      if (reason = this.checkJSON(object)) {
        return reason;
      }
      setParents = function(node) {
        var c, k, v, _i, _j, _len, _len1, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6;
        _ref2 = (_ref1 = node.c) != null ? _ref1 : [];
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          c = _ref2[_i];
          c.p = node;
          setParents(c);
        }
        _ref4 = (_ref3 = node.v) != null ? _ref3 : [];
        for (_j = 0, _len1 = _ref4.length; _j < _len1; _j++) {
          v = _ref4[_j];
          v.p = node;
          setParents(v);
        }
        _ref6 = (_ref5 = node.a) != null ? _ref5 : {};
        for (k in _ref6) {
          if (!__hasProp.call(_ref6, k)) continue;
          v = _ref6[k];
          v.p = node;
          setParents(v);
        }
        if (node.s != null) {
          node.s.p = node;
          setParents(node.s);
        }
        if (node.b != null) {
          node.b.p = node;
          return setParents(node.b);
        }
      };
      setParents(object);
      object.p = null;
      return new OMNode(object);
    };

    function OMNode(tree) {
      this.tree = tree;
      this.encode = __bind(this.encode, this);
    }

    OMNode.prototype.encode = function() {
      return JSON.stringify(this.tree, function(k, v) {
        if (k === 'p') {
          return void 0;
        } else {
          return v;
        }
      });
    };

    return OMNode;

  })();

}).call(this);

//# sourceMappingURL=openmath.duo.js.map

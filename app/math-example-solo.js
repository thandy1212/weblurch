// Generated by CoffeeScript 1.8.0
(function() {
  var compute, inspect, menu, toXML,
    __slice = [].slice;

  setAppName('MathApp');

  addHelpMenuSourceCodeLink('app/math-example-solo.litcoffee');

  window.helpAboutText = '<p>See the fully documented <a target="top" href="https://github.com/nathancarter/weblurch/blob/master/app/math-example-solo.litcoffee" >source code for this demo app</a>.</p>';

  window.groupTypes = [
    {
      name: 'me',
      text: 'Mathematical Expression',
      tooltip: 'Make the selection a mathematical expression',
      color: '#666699',
      imageHTML: '<font color="#666699"><b>[ ]</b></font>',
      openImageHTML: '<font color="#666699"><b>[</b></font>',
      closeImageHTML: '<font color="#666699"><b>]</b></font>',
      contentsChanged: function(group, firstTime) {
        var info;
        info = inspect(group);
        if (info instanceof window.OMNode) {
          info = (function() {
            switch (info.type) {
              case 'i':
                return 'integer';
              case 'f':
                return 'float';
              case 'st':
                return 'string';
              case 'ba':
                return 'byte array';
              case 'sy':
                return 'symbol';
              case 'v':
                return 'variable';
              case 'a':
                switch (info.children[0].simpleEncode()) {
                  case 'arith1.plus':
                  case 'arith1.sum':
                    return 'sum';
                  case 'arith1.minus':
                    return 'difference';
                  case 'arith1.plusminus':
                    return 'sum/difference';
                  case 'arith1.times':
                    return 'product';
                  case 'arith1.divide':
                    return 'quotient';
                  case 'arith1.power':
                    return 'exponentiation';
                  case 'arith1.root':
                    return 'radical';
                  case 'arith1.abs':
                    return 'absolute value';
                  case 'arith1.unary_minus':
                    return 'negation';
                  case 'relation1.eq':
                    return 'equation';
                  case 'relation1.approx':
                    return 'approximation';
                  case 'relation1.neq':
                    return 'negated equation';
                  case 'relation1.lt':
                  case 'relation1.le':
                  case 'relation1.gt':
                  case 'relation1.ge':
                    return 'inequality';
                  case 'logic1.not':
                    return 'negated sentence';
                  case 'calculus1.int':
                    return 'indefinite integral';
                  case 'calculus1.defint':
                    return 'definite integral';
                  case 'transc1.sin':
                  case 'transc1.cos':
                  case 'transc1.tan':
                  case 'transc1.cot':
                  case 'transc1.sec':
                  case 'transc1.csc':
                    return 'trigonometric function';
                  case 'transc1.arcsin':
                  case 'transc1.arccos':
                  case 'transc1.arctan':
                  case 'transc1.arccot':
                  case 'transc1.arcsec':
                  case 'transc1.arccsc':
                    return 'inverse trigonometric function';
                  case 'overarc':
                    return 'overarc';
                  case 'overline':
                    return 'overline';
                  case 'd.diff':
                    return 'differential';
                  case 'interval1.interval_oo':
                  case 'interval1.interval_oc':
                  case 'interval1.interval_co':
                  case 'interval1.interval_cc':
                    return 'interval';
                  case 'integer1.factorial':
                    return 'factorial';
                  case 'limit1.limit':
                    return 'limit';
                }
                break;
              case 'b':
                return 'lambda closure';
            }
          })();
        }
        return group.set('tag', info);
      },
      tagContents: function(group) {
        return group.get('tag');
      },
      tagMenuItems: function(group) {
        return menu(group);
      },
      contextMenuItems: function(group) {
        return menu(group);
      }
    }
  ];

  inspect = function(group) {
    var e, newTag, node, nodes, parsed, selector, toParse, _ref;
    nodes = $(group.contentNodes());
    selector = '.mathquill-rendered-math';
    nodes = nodes.find(selector).add(nodes.filter(selector));
    newTag = null;
    if (nodes.length === 0) {
      return 'add math using the f(x) button';
    }
    if (nodes.length > 1) {
      return 'more than one math expression';
    }
    node = nodes.get(0);
    try {
      toParse = window.mathQuillToMeaning(node);
    } catch (_error) {
      e = _error;
      return "Error converting math expression to text: " + (e != null ? e.message : void 0);
    }
    try {
      parsed = (_ref = mathQuillParser.parse(toParse)) != null ? _ref[0] : void 0;
    } catch (_error) {
      e = _error;
      return "Error parsing math expression as text: " + (e != null ? e.message : void 0);
    }
    if (parsed instanceof window.OMNode) {
      return parsed;
    }
    return "Could not parse this mathematical text: " + (toParse != null ? typeof toParse.join === "function" ? toParse.join(' ') : void 0 : void 0) + " -- Error: " + parsed;
  };

  menu = function(group) {
    return [
      {
        text: 'See full OpenMath structure',
        onclick: function() {
          var e, info, _ref, _ref1;
          if (!((info = inspect(group)) instanceof OMNode)) {
            return alert("Could not understand the bubble contents:\n " + info);
          } else {
            try {
              return alert((_ref = toXML(info)) != null ? _ref : "Some part of that expression is not supported in this demo for conversion to XML.");
            } catch (_error) {
              e = _error;
              return alert((_ref1 = e.message) != null ? _ref1 : e);
            }
          }
        }
      }, {
        text: 'Evaluate this',
        onclick: function() {
          var info, result;
          if (!((info = inspect(group)) instanceof OMNode)) {
            info = "Could not understand the bubble contents:\n " + info;
          } else {
            result = compute(info);
            info = "" + result.value;
            if (result.message != null) {
              info += "\n\nNote:\n" + result.message;
            }
          }
          return alert(info);
        }
      }
    ];
  };

  toXML = function(node) {
    var body, c, head, indent, inside, text, v, vars;
    indent = function(text) {
      return "  " + (text.replace(RegExp('\n', 'g'), '\n  '));
    };
    switch (node.type) {
      case 'i':
        return "<OMI>" + node.value + "</OMI>";
      case 'sy':
        return "<OMS cd=\"" + node.cd + "\" name=\"" + node.name + "\"/>";
      case 'v':
        return "<OMV name=\"" + node.name + "\"/>";
      case 'f':
        return "<OMF dec=\"" + node.value + "\"/>";
      case 'st':
        text = node.value.replace(/\&/g, '&amp;').replace(/</g, '&lt;');
        return "<OMSTR>" + text + "</OMSTR>";
      case 'a':
        inside = ((function() {
          var _i, _len, _ref, _results;
          _ref = node.children;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            c = _ref[_i];
            _results.push(indent(toXML(c)));
          }
          return _results;
        })()).join('\n');
        return "<OMA>\n" + inside + "\n</OMA>";
      case 'bi':
        head = indent(toXML(node.symbol));
        vars = ((function() {
          var _i, _len, _ref, _results;
          _ref = node.variables;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            v = _ref[_i];
            _results.push(toXML(v));
          }
          return _results;
        })()).join('');
        vars = indent("<OMBVAR>" + vars + "</OMBVAR>");
        body = indent(toXML(node.body));
        return "<OMBIND>\n" + head + "\n" + vars + "\n" + body + "\n</OMBIND>";
      default:
        throw "Cannot convert this to XML: " + (node.simpleEncode());
    }
  };

  compute = function(node) {
    var call, result, tmp;
    call = function() {
      var arg, args, e, func, index, indices, message, value, _i, _len;
      func = arguments[0], indices = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      message = void 0;
      args = [];
      for (_i = 0, _len = indices.length; _i < _len; _i++) {
        index = indices[_i];
        arg = compute(node.children[index]);
        if (arg.value == null) {
          return arg;
        }
        if (arg.message != null) {
          if (message == null) {
            message = '';
          } else {
            message += '\n';
          }
          message += arg.message;
        }
        args.push(arg.value);
      }
      try {
        value = func.apply(null, args);
      } catch (_error) {
        e = _error;
        if (message == null) {
          message = '';
        } else {
          message += '\n';
        }
        message += e.message;
      }
      return {
        value: value,
        message: message
      };
    };
    result = (function() {
      switch (node.type) {
        case 'i':
        case 'f':
        case 'st':
        case 'ba':
          return {
            value: node.value
          };
        case 'v':
          switch (node.name) {
            case 'π':
              return {
                value: Math.PI,
                message: 'The actual value of π has been rounded.'
              };
            case 'e':
              return {
                value: Math.exp(1),
                message: 'The actual value of e has been rounded.'
              };
          }
          break;
        case 'sy':
          switch (node.simpleEncode()) {
            case 'units.degrees':
              return {
                value: Math.PI / 180
              };
            case 'units.percent':
              return {
                value: 0.01
              };
            case 'units.dollars':
              return {
                value: 1,
                message: 'Dollar units were dropped'
              };
          }
          break;
        case 'a':
          switch (node.children[0].simpleEncode()) {
            case 'arith1.plus':
              return call((function(a, b) {
                return a + b;
              }), 1, 2);
            case 'arith1.minus':
              return call((function(a, b) {
                return a - b;
              }), 1, 2);
            case 'arith1.times':
              return call((function(a, b) {
                return a * b;
              }), 1, 2);
            case 'arith1.divide':
              return call((function(a, b) {
                return a / b;
              }), 1, 2);
            case 'arith1.power':
              return call(Math.pow, 1, 2);
            case 'arith1.root':
              return call((function(a, b) {
                return Math.pow(b, 1 / a);
              }), 1, 2);
            case 'arith1.abs':
              return call(Math.abs, 1);
            case 'arith1.unary_minus':
              return call((function(a) {
                return -a;
              }), 1);
            case 'relation1.eq':
              return call((function(a, b) {
                return a === b;
              }), 1, 2);
            case 'relation1.approx':
              tmp = call((function(a, b) {
                return Math.abs(a - b) < 0.01;
              }), 1, 2);
              if ((tmp.message != null ? tmp.message : tmp.message = '').length) {
                tmp.message += '\n';
              }
              tmp.message += 'Values were rounded to two decimal places for approximate comparison.';
              return tmp;
            case 'relation1.neq':
              return call((function(a, b) {
                return a !== b;
              }), 1, 2);
            case 'relation1.lt':
              return call((function(a, b) {
                return a < b;
              }), 1, 2);
            case 'relation1.gt':
              return call((function(a, b) {
                return a > b;
              }), 1, 2);
            case 'relation1.le':
              return call((function(a, b) {
                return a <= b;
              }), 1, 2);
            case 'relation1.ge':
              return call((function(a, b) {
                return a >= b;
              }), 1, 2);
            case 'logic1.not':
              return call((function(a) {
                return !a;
              }), 1);
            case 'transc1.sin':
              return call(Math.sin, 1);
            case 'transc1.cos':
              return call(Math.cos, 1);
            case 'transc1.tan':
              return call(Math.tan, 1);
            case 'transc1.cot':
              return call((function(a) {
                return 1 / Math.tan(a);
              }), 1);
            case 'transc1.sec':
              return call((function(a) {
                return 1 / Math.cos(a);
              }), 1);
            case 'transc1.csc':
              return call((function(a) {
                return 1 / Math.sin(a);
              }), 1);
            case 'transc1.arcsin':
              return call(Math.asin, 1);
            case 'transc1.arccos':
              return call(Math.acos, 1);
            case 'transc1.arctan':
              return call(Math.atan, 1);
            case 'transc1.arccot':
              return call((function(a) {
                return Math.atan(1 / a);
              }), 1);
            case 'transc1.arcsec':
              return call((function(a) {
                return Math.acos(1 / a);
              }), 1);
            case 'transc1.arccsc':
              return call((function(a) {
                return Math.asin(1 / a);
              }), 1);
            case 'transc1.ln':
              return call(Math.log, 1);
            case 'transc1.log':
              return call(function(base, arg) {
                return Math.log(arg) / Math.log(base);
              }, 1, 2);
            case 'integer1.factorial':
              return call(function(a) {
                var i, _i, _ref;
                if (a <= 1) {
                  return 1;
                }
                if (a >= 20) {
                  return Infinity;
                }
                result = 1;
                for (i = _i = 1, _ref = a | 0; 1 <= _ref ? _i <= _ref : _i >= _ref; i = 1 <= _ref ? ++_i : --_i) {
                  result *= i;
                }
                return result;
              }, 1);
          }
      }
    })();
    if (result == null) {
      result = {
        value: void 0
      };
    }
    if (typeof result.value === 'undefined') {
      result.message = "Could not evaluate " + (node.simpleEncode());
    }
    return result;
  };

}).call(this);

//# sourceMappingURL=math-example-solo.js.map

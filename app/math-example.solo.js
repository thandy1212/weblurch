// Generated by CoffeeScript 1.8.0
(function() {
  setAppName('MathApp');

  window.menuBarIcon = {};

  window.helpAboutText = 'See the fully documented source code for this demo app at the following URL:\n \nhttps://github.com/nathancarter/weblurch/blob/master/app/math-example.solo.litcoffee';

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
        var e, result;
        result = (function() {
          try {
            return "" + (math["eval"](group.contentAsText()));
          } catch (_error) {
            e = _error;
            return "???";
          }
        })();
        if (result !== group.get('result')) {
          return group.set('result', result);
        }
      },
      tagContents: function(group) {
        return group.get('result');
      }
    }
  ];

}).call(this);

//# sourceMappingURL=math-example.solo.js.map

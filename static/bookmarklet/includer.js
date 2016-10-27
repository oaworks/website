(function() {
  var version = '1.0.0';
  var url = 'http://oab.test.cottagelabs.com/static/bookmarklet';
  var fls = ['bookmarklet.css','oab.js','ui.js','bookmarklet.js'];
  for (var i = 0; i < fls.length; i++) {
    var tp = fls[i].indexOf('css') !== -1 ? 'link' : 'script';
    var ms = document.createElement(tp);
    if ( tp === 'link' ) {
      ms.rel = 'stylesheet';
      ms.href = url + '/' + fls[i] + '?v=' + version;
    } else {
      ms.src = url + '/' + fls[i] + '?v=' + version;      
    }
    document.getElementsByTagName('head')[0].appendChild(ms);
  }
})();

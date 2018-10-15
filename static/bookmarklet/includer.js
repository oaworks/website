(function() {
  var version = '4.2.0';
  var api_address = '{{api}}';
  var site_address = '{{site_url}}';
  var url = site_address + '/static/bookmarklet';

  var fls = ['bookmarklet.css','oab.js'];
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
  setTimeout(function() {
    if (site_address.indexOf('https://open') === -1) {
      var w = document.createElement('div');
      w.setAttribute('class','reset-this');
      w.setAttribute('style','position:fixed;top:0;left:0;right:0;min-height:100px;padding:10px;font-size:20px;background-color:#ee927f;color:black;');
      w.innerHTML = '<p>Warning: You are using the development version of our Open Access Button bookmarklet.<br>Please ensure you get the latest bookmarklet from our website at <br><a target="_blank" href="https://openaccessbutton.org">https://openaccessbutton.org</a> before proceeding. Thank you!</p>';
      document.body.appendChild(w);
    }
    var popup = document.createElement('div');
    popup.setAttribute('id','oabutton_popup');
    popup.setAttribute('class','reset-this');
    popup.innerHTML = '<img id="iconloading" style="width:40px;height:40px;" src="' + url + '/img/spin_orange.svg" /><div id="isopen" style="display:none;"><p>This article is available!</p><p><a id="linkopen" href=""><img style="width:100%;" src="' + url + '/img/open.png" /></a></p></div><div id="isclosed" style="display:none;"><p>This article is not currently available,<br>but you can request it from the author.</p><p><a id="linkclosed" href=""><img style="width:100%;" src="' + url + '/img/closed.png" /></a></p></div><div id="iserror" style="display:none;"><p>Sorry, there was an error. Please click to report it.</p><p><a id="linkerror" href=""><img style="width:100%;" src="' + url + '/img/error.png" /></a></p></div><a href="#" id="iconarticle" style="display:none;padding-left:5px;padding-right:3px;"></a>';
    document.body.appendChild(popup);
    oabutton_ui({{debug}},version,api_address,site_address);
  },1500);
})();

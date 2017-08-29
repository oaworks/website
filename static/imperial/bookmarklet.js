var oabutton_bookmarklet = function(apikey) {
  oab.bookmarklet = '1.0.3';

  var popup = document.createElement('div');
  popup.setAttribute('id','oabutton_popup');
  popup.setAttribute('class','reset-this');
  var lib = oab.library ? oab.library.substring(0,1).toUpperCase() + oab.library.substring(1,oab.library.length) : false;
  var form = '\
    <h2 style="text-align:center;">Get PDF</h2> \
    <div id="loading_area" style="margin:5px 0px 10px -10px;"> \
      <img id="icon_loading" style="width:150px;margin:20px auto 10px 110px;" src="' + oab.site_address + '/static/imperial/img/spin_orange.svg"> \
      <p style="text-align:center;">We\'re looking!<br> Give us a moment.</p> \
    </div> \
    <div class="collapse" id="buttonstatus" style="margin:5px 0px 10px -10px;min-height:180px;"> \
      <a href="#" target="_blank" id="iconarticle" class="need" data-type="article" alt="Sorry, we couldn\'t find an open access version. Click to start a new request" title="Sorry, we couldn\'t find an open access version. Click to start a new request" style="margin-bottom:10px;';
  if (!oab.dataable) {
    form += 'width:330px;'
  }
  form += '"> \
        <img style="height:100px;width:80px;margin-bottom:12px;" src="' + oab.site_address + '/static/imperial/img/oab_article.png"><br>\
        <span id="iconarticletext">Unavailable</span>\
      </a>';
  if (oab.dataable) {
    form += '<a href="#" target="_blank" id="icondata" class="need" data-type="data" alt="Sorry, we couldn\'t find any related data. Click to start a new request" title="Sorry, we couldn\'t find any related data. Click to start a new request"> \
        <img style="height:110px;width:80px;margin-top:2px;" src="' + oab.site_address + '/static/imperial/img/oab_data.png"><br>\
        <span id="icondatatext">Unavailable</span>\
      </a>';
  }
  if (lib) {
    form += '<div style="clear:both;margin:0px 0px 11px 10px;padding:5px;border-radius:3px;background-color:#398bc5;" id="library" class="collapse"></div> \
      <a href="#" target="_blank" style="margin:3px 0px 10px 11px;font-size:0.7em;" id="ill" alt="Click to start a request" title="Click to start a request"> \
        Not the right item? Start a request \
      </a>';
  }
  form += '</div> \
    <div id="message" style="margin-top:5px;"></div> \
    <div class="collapse" id="story_div">';
  if (lib) {
    form += '<textarea id="title" class="reset-this" placeholder="Enter the article title"></textarea>';
    form += '<input type="text" id="id" class="reset-this" placeholder="Enter your ' + lib + ' email address">';
  }
  form += ' \
      <textarea class="reset-this" id="story" placeholder="How would getting access to this research help you? This message will be sent to the author."></textarea> \
      <img id="icon_submitting" style="width:30px;margin:0px auto 0px 10px;" src="' + oab.site_address + '/static/imperial/img/spin_orange.svg" class="collapse"> \
      <button type="submit" id="submit" disabled>Say why you need this in up to <br><span id="counter">25</span> words to create this request</button>'
  if (lib) {
    form += '<div id="terms" style="font-size:0.7em;margin-top:5px;"></div>';
  }
  form += '</div> \
    <p style="font-size:14px;margin-top:40px;margin-bottom:-20px;">Powered by <a target="_blank" href="https://openaccessbutton.org"><b>Open Access Button</b></a><br>and <a target="_blank" href="https://www.imperial.ac.uk/admin-services/library"><b>Imperial College London Library</b></a></p>\
    <p style="text-align:right;"> \
      <a href="" id="oab_close" style="font-size:18px;font-weight:bold;color:#999;" alt="close" title="close">x</a> \
    </p>';
  popup.innerHTML = form;
  document.body.appendChild(popup);
  document.getElementById('oab_close').onclick = function() { document.getElementById('oabutton_popup').style.display = 'none'; };

  oabutton_ui(apikey);

}
setTimeout(function() {oabutton_bookmarklet(apikey); },1500);

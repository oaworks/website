var oabutton_bookmarklet = function(apikey) {
  oab.bookmarklet = '0.2.4';

  var popup = document.createElement('div');
  popup.setAttribute('id','oabutton_popup');
  popup.setAttribute('class','reset-this');
  popup.innerHTML = '\
    <h2><img src="' + oab.site_address + '/static/bookmarklet/img/oa128.png" style="width:40px;vertical-align:text-top;"> Open Access Button</h2> \
    <div id="loading_area" style="margin:5px -10px 10px -10px;"> \
      <img id="icon_loading" style="width:150px;margin:20px auto 10px 110px;" src="' + oab.site_address + '/static/bookmarklet/img/spin_orange.svg"> \
      <p style="text-align:center;">We\'re looking!<br> Give us a moment.</p> \
    </div> \
    <div class="collapse" id="buttonstatus" style="margin:5px -10px 10px -10px;min-height:180px;"> \
      <a href="#" target="_blank" id="iconarticle" class="need" data-type="article" alt="Sorry, we couldn\'t find it. Click to start a new request" title="Sorry, we couldn\'t find it. Click to start a new request"> \
        <img style="height:100px;width:80px;margin-bottom:12px;" src="' + oab.site_address + '/static/bookmarklet/img/oab_article.png"><br> \
        Unavailable \
      </a> \
      <a href="#" target="_blank" id="icondata" class="need" data-type="data" alt="Sorry, we couldn\'t find it. Click to start a new request" title="Sorry, we couldn\'t find it. Click to start a new request"> \
        <img style="height:110px;width:80px;margin-top:2px;" src="' + oab.site_address + '/static/bookmarklet/img/oab_data.png"><br> \
        Unavailable \
      </a> \
    </div> \
    <div id="message" style="margin-top:5px;"></div> \
    <div class="collapse" id="story_div"> \
      <textarea class="reset-this" id="story" placeholder="How would getting access to this research help you? This message will be sent to the author."></textarea> \
      <img id="icon_submitting" style="width:30px;margin:0px auto 0px 10px;" src="' + oab.site_address + '/static/bookmarklet/img/spin_orange.svg" class="collapse"> \
      <button type="submit" id="submit" disabled>Say why you need this in up to <br><span id="counter">25</span> words to create this request</button> \
    </div> \
    <p style="text-align:right;"> \
      <a href="#" id="oab_close" style="font-size:18px;font-weight:bold;color:#999;" alt="close Open Access Button" title="close Open Access Button">x</a> \
    </p>';
  document.body.appendChild(popup);
  document.getElementById('oab_close').onclick = function() { document.getElementById('oabutton_popup').style.display = 'none'; };
  
  oabutton_ui(apikey);

}
setTimeout(function() {oabutton_bookmarklet(apikey); },1500);

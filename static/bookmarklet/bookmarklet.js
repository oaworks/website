var oabutton_bookmarklet = function() {
  var popup = document.createElement('div');
  popup.setAttribute('id','oabutton_popup');
  popup.setAttribute('class','reset-this');
  popup.innerHTML = '\
    <img id="iconloading" style="width:40px;height:40px;" src="https://openaccessbutton.org/static/bookmarklet/img/spin_orange.svg"> \
    <a href="#" target="_blank" id="iconarticle" style="display:none;padding-left:5px;padding-right:3px;"></a>';
  document.body.appendChild(popup);

  oabutton_ui();
}
setTimeout(function() {oabutton_bookmarklet(undefined,'4.1.1'); },1500);

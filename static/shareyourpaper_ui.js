
var uc = undefined;
_preview = false;

var view = function(e,which) {
  var evented = true;
  try { e.preventDefault(); } catch(err) { evented = e; }
  if (which) {
    $('.section').hide();
    if (which.indexOf('.') !== 0 && which.indexOf('#') !== 0) which = '#' + which;
    $(which).show();
  } else if ($(this).attr('href') === undefined) {
    $('.section').hide();
    if (window.location.hash && window.location.href.indexOf('/setup') !== -1) {
      $(window.location.hash).show();
    } else {
      $('.section').first().show();
    	if ('pushState' in window.history) window.history.pushState("", document.title, window.location.pathname + window.location.search);
    }
  } else if ($(this).attr('href').length > 1) {
    $('.section').hide();
    which = $(this).attr('href');
    if (which.indexOf('.') !== 0 && which.indexOf('#') !== 0) which = '#' + which;
    $(which).show();
  } else {
    var movefrom = '#' + $('.section:visible').first().attr('id');
    $('.section').hide();
    $(this).hasClass('previous') ? $(movefrom).prev().show() : $(movefrom).next().show();
    which = '#' + $('.section:visible').first().attr('id');
  }
  if (($(this).hasClass('pull') || !evented) && $('#shareyourpaper','.section:visible').length !== 1) $('#shareyourpaper').appendTo($('.content','.section:visible'));
  /*if ($('div.content:visible').offset().top > $(window).height()) {
    var pad = Math.floor(($('div.green').height() - $('#shareyourpaper').height())/2);
    $('div.content:visible').css({'padding-top':pad+'px'});
  } else if ($('div.content:visible').height() < $(window).height()) {
    var pad = Math.floor($('div.content:visible').offset().top + $('div.content:visible').height()/2 + $(window).height()/3);
    $('div.content:visible').css({'padding-top':pad+'px'});
  }*/
  //$('div.green:visible').css({'min-height':$(document).height()+'px'});
  $('div.content:visible').css({'padding-top':'100px'});
	if (which && 'pushState' in window.history) window.history.pushState("", which, which);
}
$('body').on('click','.view',view);
//$(window).on('popstate', view);
view();

var preview = function(e,val) {
  try { e.preventDefault(); } catch (err) {}
  // do nothing if called with a save class, as the save will catch it and pass it on
  if (!$(this).hasClass('save')) {
    if (typeof val !== 'string') {
      if (uc && uc.val) {
        val = $(this).attr('val');
      } else {
        if (uc && uc.val) val = uc.val;
      }
    }
    if (typeof val !== 'string' || val.length < 10) val = '10.1234/oab-syp-aam';
    if ($(this).hasClass('view')) {
      if ($('#shareyourpaper','.section:visible').length !== 1) {
        $('#shareyourpaper').appendTo($('.content','.section:visible'));
      }
    } else if (!$('#shareyourpaper').is(':visible')) {
      view(undefined,'#demo');
    }
    _restart(undefined,val);
  }
}
$('body').on('click','.preview',preview);

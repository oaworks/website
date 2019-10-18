
var uc = undefined;

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
  if (($(this).hasClass('pull') || !evented) && $('#instantill','.section:visible').length !== 1) $('#instantill').appendTo($('.content','.section:visible'));
  if ($('div.content:visible').offset().top > $(window).height()) {
    var pad = Math.floor(($('div.green').height() - $('#instantill').height())/2);
    $('div.content:visible').css({'padding-top':pad+'px'});
  } else if ($('div.content:visible').height() < $(window).height()) {
    var pad = Math.floor($('div.content:visible').offset().top + $('div.content:visible').height()/2 + $(window).height()/3);
    $('div.content:visible').css({'padding-top':pad+'px'});
  }
  //$('div.green:visible').css({'min-height':$(document).height()+'px'});
	if (which && 'pushState' in window.history) window.history.pushState("", which, which);
}
$('body').on('click','.view',view);
$(window).on('popstate', view);
view();

var preview = function(e,val) {
  try { e.preventDefault(); } catch (err) {}
  if ($(this).hasClass('save') && val === undefined) {
    // do nothing, the save will call this again once ready to run the preview with new values
  } else {
    if (typeof val !== 'string') {
      try {
        try {
          if (uc.val) val = uc.val;
        } catch(err) {
          val = $(this).attr('val');
        }
      } catch(err) {
        val = '10.1145/2908080.2908114';
      }
    }
    if (typeof val !== 'string' || val.length < 10) val = '10.1145/2908080.2908114';
    if ($(this).hasClass('view')) {
      if ($('#instantill','.section:visible').length !== 1) {
        $('#instantill').appendTo($('.content','.section:visible'));
      }
    } else if (!$('#instantill').is(':visible')) {
      view(undefined,'#demo');
    }
    _instantill_restart();
    $('#oabutton_input').val(val);
    setTimeout(function() { $('#oabutton_find').trigger('click'); },300);
  }
}
$('body').on('click','.preview',preview);


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
    if (window.location.hash && window.location.href.indexOf('/setup') !== -1 && (window.location.hash !== '#login' || !noddy.loggedin())) {
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
  if ($(this).hasClass('restart')) _instantill_restart();
  
  /*if ($('div.content:visible').offset().top > $(window).height()) {
    var pad = Math.floor(($('div.green').height() - $('#instantill').height())/2);
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
$(window).on('popstate', view);
view();
setTimeout(function() { $('#demo').show();}, 2000);

var preview = function(e,val,specialval) {
  try { if ($(this).hasClass('specialval') && specialval === undefined) specialval = uc.val; } catch(err) {}
  try { e.preventDefault(); } catch (err) {}
  if ($(this).hasClass('save') && val === undefined) {
    // do nothing, the save will call this again once ready to run the preview with new values
  } else {
    if (typeof val !== 'string') val = $(this).attr('val');
    if (typeof val !== 'string' || val.length < 10) val = '10.1145/2908080.2908114';
    if (specialval) val = specialval;
    if ($(this).hasClass('view')) {
      if ($('#instantill','.section:visible').length !== 1) {
        $('#instantill').appendTo($('.content','.section:visible'));
      }
    } else if (!$('#instantill').is(':visible')) {
      view(undefined,'#demo');
    }
    _instantill_restart(undefined,val);
  }
}
$('body').on('click','.preview',preview);

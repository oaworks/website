
if ($('#rebrand').height() < $(window).height()) $('#rebrand').css({'min-height':$(window).height()+'px'});
$('div.green').css({'min-height':$(window).height()+'px'});

var _ill_response = undefined;
var fakeill = function(e) {
  if (e) e.preventDefault();
  $('#fakeilltable').html('');
  try {
    for ( var i in _ill_response.meta.article) {
      if (['started','ended','took','cache','redirect','source'].indexOf(i) === -1) {
        if (i === 'author') {
          var append = '<tr><td>Author(s)</td><td><p>';
          for (var a in _ill_response.meta.article.author) {
            try {
              if (a !== '0') append += ', ';
              append += _ill_response.meta.article.author[a].given + ' ' + _ill_response.meta.article.author[a].family
            } catch(err) {}
          }
          $('#fakeilltable').append(append + '</p></td></tr>');
        } else {
          try {
            $('#fakeilltable').append('<tr><td>' + i.substring(0,1).toUpperCase() + (['doi','issn'].indexOf(i.toLowerCase()) !== -1 ? i.substring(1).toUpperCase() : i.substring(1)) + '</td><td><p>' + _ill_response.meta.article[i] + '</p></td></tr>');
          } catch(err) {}
        }
      }
    }
  } catch(err) {}
  if (($('#fakeill').height() + $('#fakeill').offset().top) > $(window).height()) {
    var diff = Math.floor(($(window).height() - $('#fakeill').height())/2)-20;
    if (diff < 20) diff = 20;
    $('#fakeill').children('div.content').css({'padding-top':diff+'px'});
  }
  view(true,'#fakeill');
}

$(document).ajaxComplete(function(e,xhr) {
  if (xhr && xhr.responseJSON && xhr.responseJSON.data && xhr.responseJSON.data.match !== undefined) {
    _ill_response = xhr.responseJSON.data;
    // an availability check finished, reposition the instantill window if necessary
    if (($('#instantill').height() + $('#instantill').offset().top) > ($(window).height()*.95)) {
      var diff = Math.floor(($(window).height() - $('#instantill').height())/2)-20;
      if (diff < 20) diff = 20;
      $('div.content:visible').css({'padding-top':diff+'px'});
    }
    $('.oabutton_ill').off();
    $('body').on('click','.oabutton_ill',fakeill);
  }
});

var view = function(e,which) {
  var evented = true;
  try { e.preventDefault(); } catch(err) { evented = e; }
  if (which) {
    $('.section').hide();
    if (which.indexOf('.') !== 0 && which.indexOf('#') !== 0) which = '#' + which;
    $(which).show();
  } else if ($(this).attr('href') === undefined) {
    $('.section').hide();
    //if (window.location.hash) {
    //  $(window.location.hash).show();
    //} else {
    $('.section').first().show();
    //}
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
  if ($('div.content:visible').height() < $(window).height()) {
    var pad = Math.floor($('div.content:visible').offset().top + $('div.content:visible').height()/2 + $(window).height()/3);
    $('div.content:visible').css({'padding-top':pad+'px'});
  }
  $('div.green:visible').css({'min-height':$(document).height()+'px'});
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
        val = $(this).attr('val');
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


var runas = false;

var get_code = function(e) {
  try { e.preventDefault(); } catch(err) {}
  if ($('#instantill').length) $('#instantill').toggle();
  if ($('#shareyourpaper').length) $('#shareyourpaper').toggle();
  $('#embed_code').toggle();
}
$('body').on('click','.get_embed',get_code);

var view = function(e) {
  try {
    e.preventDefault();
  } catch(err) {}
  var which = typeof e === 'string' ? e : false;
  if (typeof e === 'string') {
    $('.section').hide();
    if (which.indexOf('.') !== 0 && which.indexOf('#') !== 0) which = '#' + which;
    $(which).show();
  } else if ($(this).attr('href') === undefined) {
    $('.section').hide();
    if (window.location.hash && window.location.href.indexOf('/setup') !== -1 && $(window.location.hash).length) {
      which = window.location.hash;
      $(which).show();
    } else {
      $('.section').first().show();
    }
  } else if ($(this).attr('href').length > 1) {
    $('.section').hide();
    which = $(this).attr('href');
    if (which.indexOf('.') !== 0 && which.indexOf('#') !== 0) which = '#' + which;
    $(which).show();
  } else {
    var movefrom = $('.section:visible').first().attr('id');
    var backwards = $('.section:visible').first().hasClass('previous');
    $('.section').hide();
    which = '#';
    var n = 0;
    $('.section').each(function(i) {
      if ($(this).attr('id') === movefrom) n = i;
    });
    if (backwards) {
      while (n > 0) {
        n -= 1;
        if (!$('.section').eq(n).hasClass('skip')) {
          $('.section').eq(n).show();
          which += $('.section').eq(n).attr('id');
          break;
        }
      }
    } else {
      while (n < $('.section').length) {
        n += 1;
        if (!$('.section').eq(n).hasClass('skip')) {
          $('.section').eq(n).show();
          which += $('.section').eq(n).attr('id');
          break;
        }
      }
    }
    if (which === '#' || which === '#undefined') {
      $('.section').first().show();
      which = '#menu';
    }
  }
  if (which && which !== '#menu') {
    $('#previewer').show();
    $('#startsave').html('Save & Continue');
    if ($('#startsave').hasClass('btn-hollow-green')) {
      $('#startsave').removeClass('btn-hollow-green').addClass('btn-demo-green').addClass('save');
    } else {
      $('#startsave').removeClass('btn-hollow-blue').addClass('btn-demo-blue').addClass('save');
    }
  } else {
    $('#previewer').hide();
    $('#startsave').html('Get started');
    $('#setup').show();
  }
  if (which) {
    if ($(which).hasClass('full')) $('.full').not(which).hide();
  	if ('pushState' in window.history) window.history.pushState("", which, which);
  } else {
    $('.full').not('#setup').hide();
    $('#setup').show();
  }
  try { if (($('#instantill').length && !$('#instantill').is(':visible')) || ($('#shareyourpaper').length && !$('#shareyourpaper').is(':visible'))) get_code(); } catch(err) {}
  try { if ($('.section:visible').first().hasClass('nopreview')) $('#previewer').hide(); } catch(err) {}
}
$('body').on('click', '.view', view);
$(window).on('popstate', view);
view();

var settings = function(uc,clear) {
  if (typeof uc === 'object') {
    if (clear !== false) {
      $('.setting').each(function() {
        // clear everything first
        if ($(this).is(':checkbox')) {
          $('#'+k).prop('checked', false);
        } else if (!$(this).is('input')) {
          $('#' + $(this).attr('id') + ' option:selected').prop('selected', false);
          $('#' + $(this).attr('id') + 'target option:first').prop('selected', 'selected');
        } else {
          $(this).val('');
        }
      });
    }
    for (var k in uc) {
      if ((k === 'pilot' || k === 'live') && uc[k] !== '$DELETE') {
        $('#'+k).prop('checked', uc[k]);
      } else if (typeof uc[k] === 'boolean') {
        $('#'+k).prop('checked', uc[k] === true);
      } else if (k === 'subscription') {
        if (typeof uc.subscription === 'string') uc.subscription = uc.subscription.split(',');
        for ( var s in uc.subscription) {
          if (parseInt(s) !== 0) addsubscription();
          if (typeof uc.subscription[s] === 'object') {
            var url = uc.subscription[s].url;
            var type = uc.subscription[s].type;
          } else {
            url = uc.subscription[s];
            try {
              type = uc.subscription_type[s];
            } catch(err) {
              type = 'unknown';
            }
          }
          $('.subscription').last().val(url);
          $('.subscription_type').last().val(type);
        }
      } else if (k !== 'subscription_type' && uc[k]) {
        $('#'+k).val(uc[k]);
      }
    }
  }
};
settings(_oab.config);

var cleared = false;
var save = function(e, preview) {
  try { e.preventDefault(); } catch (err) {}
  var data = {};
  if (window.location.search.indexOf('clear=') !== -1 && !cleared) {
    cleared = true;
  } else {
    if (_oab.config && _oab.config.community) data.community = _oab.config.community; // deal with multiple community id annoyances that we should not have
    $('.setting').each(function(i, obj) {
      if ($(this).val() !== undefined) {
        if ( $(this).attr('id') === 'community') {
          var evl = $(this).val();
          try {
            if (evl.indexOf('/') !== -1) evl = evl.split('communities/')[1].split('/')[0];
          } catch(err) {}
          if ( _oab.config && ((_oab.config.community !== undefined && evl !== _oab.config.community) || (_oab.config.community === undefined && evl !== '') ) ) {
            $('input').each(function(i, obj) { if ( $(this).attr('id') === 'community') { $(this).val(evl); } });
            data.community = evl;
          }
        } else if ( $(this).is(':checkbox') ) {
          if ($(this).attr('id') === 'live' || $(this).attr('id') === 'pilot') {
            if ($(this).is(':checked')) data[$(this).attr('id')] = Date.now();
          } else {
            data[$(this).attr('id')] = $(this).is(':checked');
          }
        } else if ( $(this).hasClass('subscription') ) {
          if ($(this).val()) {
            if (data.subscription === undefined) data.subscription = [];
            data.subscription.push($(this).val());
          } else if ($('.subscription').length > 1) {
            $(this).remove();
          }
        } else if ( $(this).hasClass('subscription_type') ) {
          if ($(this).val()) {
            if (data['subscription_type'] === undefined) data['subscription_type'] = [];
            data['subscription_type'].push($(this).val());
          } else if ($('.subscription_type').length > 1) {
            $(this).remove();
          }
        } else {
          data[$(this).attr('id')] = $(this).val();
          if (['ill_form','terms','book','other'].indexOf($(this).attr('id')) !== -1 && data[$(this).attr('id')] !== '' && data[$(this).attr('id')].indexOf('http') !== 0) {
            data[$(this).attr('id')] = 'http://' + data[$(this).attr('id')];
            $(this).val(data[$(this).attr('id')]);
          }
        }
      }
    });
  }
  
  settings(data);
  if (preview) {
    _oab.configure(data, true, undefined, preview);
  } else {
    var configured;
    var dsv = undefined;
    try {
      dsv = $('.section:visible').first().prev().attr('save');
    } catch(err) {}
    if (dsv === 'restart') {
      configured = _oab.configure(data, true);
      _oab.restart();
    } else {
      configured = _oab.configure(data, true, undefined, dsv);
    }
    if (noddy.apikey) {
      if (runas) configured.uid = runas;
      $.ajax({
        url: api + '/' + (_oab.plugin === 'instantill' ? 'ill' : 'deposit') + '/config',
        type:'POST',
        cache:false,
        processData:false,
        contentType: 'application/json',
        dataType: 'json',
        data: JSON.stringify(configured),
        beforeSend: function (request) { request.setRequestHeader("x-apikey", noddy.apikey); }
      });
    }
  }
};
$('body').on('click','.save',save);

var preview = function(e) {
  e.preventDefault();
  save(undefined, $('.section:visible').first().attr('preview') ? $('.section:visible').first().attr('preview') : ($(this).attr('val') ? $(this).attr('val') : (_oab.plugin === 'instantill' ? '10.1126/scitranslmed.abc2344' : '10.1126/scitranslmed.abc2344')));
}
$('body').on('click', '.preview', preview);

var restart = function(e) {
  e.preventDefault();
  _oab.restart();
}
$('body').on('click', '.restart', restart);

jQuery(document).ready(function() {
  if ($('#demo').height() < $(window).height()) $('#demo').css({'min-height':$(window).height()+'px'});
  $('.settings').css({'min-height':$(window).height()+'px'});
  var diff = Math.floor(($(window).height() - $('div.content:visible').height())/4);
  $('div.content:visible').css({'padding-top':diff+'px'});

  if (api.indexOf('dev.') !== -1) {
    $('.dev_api').html("api: 'https://dev.api.cottagelabs.com/service/oab', ");
    $('.dev_var').html('_oab=');
    $('.dev_url').each(function() {
      $(this).html($(this).html().replace('https://','https://dev.'));
    })
  }
  $('.site_url').html('https://' + (api.indexOf('dev.') !== -1 ? 'dev.' : '') + _oab.plugin + '.org/embed.js');

  var loginorurl = function(e) {
    if (e.keyCode === 13) {
      var vl = $(this).val();
      if (vl.indexOf('@') === -1) {
        e.preventDefault();
        $('#loginorurl').hide();
        // given a url, check if it has been used by syp/ill depending on which _oab.plugin is in use
        // if it has, try to get the config that came in with it, and setup the page with it if found
        try {
          $.ajax({
            url: api + '/' + (_oab.plugin === 'instantill' ? 'ill' : 'deposit') + '/config?url=' + vl,
            type: 'GET',
            success: function(ufg) {
              settings(ufg);
              _oab.configure(ufg);
              $('#maingetembed').show();
            },
            error: function() {
              $('#_oab_error').html('<p>Sorry, we couldn\'t find a pre-existing config for you.</p>').show();
              setTimeout(function() { $('#_oab_error').hide(); }, 3000);
            }
          });
        } catch(err) {}
      } else {
        noddy.token();
      }
    }
  }
  $('body').on('keyup', '#noddyEmail', loginorurl);

  var se = undefined;
  noddy.afterLogin = function() {
    $('#loginorurl').hide();
    $('#maingetembed').show();
    if ($('.user_id').length) $('.user_id').html('uid: "' + noddy.user.account._id + '", ');
    var cfg = false;
    if (window.location.search.indexOf('as=') !== -1 && noddy.hasRole('openaccessbutton.admin')) {
      runas = window.location.search.split('as=')[1].split('&')[0].split('#')[0];
      _oab.local = false;
      _oab.uid = runas;
      _oab.config = {};
      _oab.configure();
      se = setInterval(function() {
        if (JSON.stringify(_oab.config) !== '{}') {
          console.log('Rebuilding settings');
          clearInterval(se);
          settings(_oab.config);
        }
      }, 500);
      if ($('.user_id').length) $('.user_id').html('uid: "' + runas + '", ');
    } else if (noddy.user.account.service && noddy.user.account.service.openaccessbutton) {
      if (_oab.plugin === 'instantill' && noddy.user.account.service.openaccessbutton.ill && noddy.user.account.service.openaccessbutton.ill.config !== undefined) {
        cfg = noddy.user.account.service.openaccessbutton.ill.config;
      } else if (noddy.user.account.service.openaccessbutton.deposit && noddy.user.account.service.openaccessbutton.deposit.config !== undefined) {
        cfg = noddy.user.account.service.openaccessbutton.deposit.config;
      }
    }
    if (window.location.search.indexOf('clear=') !== -1 && !cleared) {
      save();
    } else if (cfg) {
      if (!cfg.owner) cfg.owner = noddy.user.email ? noddy.user.email : (noddy.user.emails !== undefined ? noddy.user.emails[0].address : undefined);
      _oab.configure(cfg, noddy.user.account._id);
      settings(cfg);
    } else {
      _oab.configure(noddy.user.account._id);
    }

    if (_oab.plugin === 'instantill') {
      try { // for ill
        $.ajax({
          url: api + '/ill/url?uid=' + (runas ? runas : noddy.user.account._id),
          type: 'GET',
          success: function(url) {
            if (url) {
              var ex = 'You can use this as the Base URL to integrate InstantILL into your other systems:<br>' + url + '.<br><br>Here is an example URL:<br>' + url + '?doi=10.1145/2908080.2908114 .<br><br>You likely have a more complex looking OpenURL. Not to worry! InstantILL can recognize a wide variety of standard OpenURL parameters so it should still just work.';
              $('#noembeddedexampleavailable').hide();
              $('#embeddedexample').html(ex).show();
            }
          }
        });
      } catch(err) {}
    } else {
      try { // for syp
        var q = {"size": 0, "query": {"filtered": {"query": {"bool": {"must": [{"term": {"plugin": "shareyourpaper"}},{"term": {"from.exact": noddy.user.account._id}}]}}}}};
        q.aggregations = {"embeds": {"terms": {"field": "embedded.exact"}}};
        $.ajax({
          url: api + '/availabilities',
          type: 'POST',
          data: q,
          success: function(iia) {
            try {
              var eurl = false;
              for (var eu in iia.aggregations.embeds.buckets) {
                var eur = iia.aggregations.embeds.buckets[eu].key.split('?')[0].split('#')[0];
                if (eur.indexOf('shareyourpaper.org') === -1 && eur.indexOf('openaccessbutton.org') === -1) {
                  eurl = eur;
                  break;
                }
              }
              if (eurl) {
                var ex = 'Here is an example:<br> <a href ="' + eurl + '?doi=10.1126/scitranslmed.abc2344&email=something@university.edu" target="_blank"> '+ eurl +'?doi=10.1126/scitranslmed.abc2344&email=something@university.edu</a>.<br><br>Any DOI will work, and you don’t need to include an email if you don’t have it.';
                $('#embeddedexample').html(ex).show();
              } else {
                $('#noembeddedexampleavailable').show();
              }
            } catch(err) {
              $('#noembeddedexampleavailable').show();
            }
          }
        });
      } catch(err) {}
    }
  };
  noddy.nologin = function() {
    $('#loginorurl').show(); // changed plans to always ask for login for now
    scroll(0,0);
    if (JSON.stringify(_oab.config) === '{}') {
      $('#maingetembed').hide();
      //$('#loginorurl').show();
    } else {
      settings(_oab.config);
    }
  }
  if (window.location.href.indexOf('/setup') !== -1) noddy.login(); // login current user on setup page, if possible, but not on other demo pages
});

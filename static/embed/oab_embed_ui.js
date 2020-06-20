
var get_code = function(e) {
  try { e.preventDefault(); } catch(err) {}
  if ($('#instantill').length) $('#instantill').toggle();
  if ($('#shareyourpaper').length) $('#shareyourpaper').toggle();
  $('#embed_code').toggle();
}
$('body').on('click','.get_embed',get_code);

var firstview = true;
var fv = function() {
  firstview = false;
  $('#previewer').show();
  $('#startsave').html('Save & Continue');
  if ($('#startsave').hasClass('btn-hollow-green')) {
    $('#startsave').removeClass('btn-hollow-green').addClass('btn-demo-green').addClass('save');
  } else {
    $('#startsave').removeClass('btn-hollow-blue').addClass('btn-demo-blue').addClass('save');
  }
}
var view = function(e) {
  try {
    e.preventDefault();
    if (firstview) fv()
  } catch(err) {}
  var which = typeof e === 'string' ? e : false;
  if (typeof e === 'string') {
    $('.section').hide();
    if (which.indexOf('.') !== 0 && which.indexOf('#') !== 0) which = '#' + which;
    $(which).show();
  } else if ($(this).attr('href') === undefined) {
    $('.section').hide();
    if (window.location.hash && window.location.href.indexOf('/setup') !== -1 && $(window.location.hash).length) {
      if (firstview) fv()
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
    if (which === '#') {
      $('.section').first().show();
      which += $('.section').first().attr('id');
    }
  }
  if ($(which).hasClass('full')) {
    $('.full').not(which).hide();
  } else {
    $('.full').not('#setup').hide();
    $('#setup').show();
  }
  try { if (($('#instantill').length && !$('#instantill').is(':visible')) || ($('#shareyourpaper').length && !$('#shareyourpaper').is(':visible'))) get_code(); } catch(err) {}
	if ('pushState' in window.history) window.history.pushState("", (which ? which : document.title), (which ? which : window.location.pathname + window.location.search));
  scrollTo(0,0);
}
$('body').on('click', '.view', view);
$(window).on('popstate', view);
view();

var configure = function(uc) {
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
};
configure(_oab.config);

var save = function(e, preview) {
  try { e.preventDefault(); } catch (err) {}
  var data = {};
  if (_oab.config && _oab.config.community) data.community = _oab.config.community; // deal with multiple community id annoyances that we should not have
  $('.setting').each(function(i, obj) {
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
      data[$(this).attr('id')] = $(this).is(':checked');
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
    } else if ( $(this).val() !== undefined ) {
      data[$(this).attr('id')] = $(this).val();
      if (['ill_redirect_base_url','terms','book','other'].indexOf($(this).attr('id')) !== -1 && data[$(this).attr('id')] !== '' && data[$(this).attr('id')].indexOf('http') !== 0) {
        data[$(this).attr('id')] = 'http://' + data[$(this).attr('id')];
        $(this).val(data[$(this).attr('id')]);
      }
    }
  });

  if (preview) {
    _oab.configure(data, undefined, undefined, preview);
  } else {
    var configured = _oab.configure(data);
    if (noddy.apikey) {
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
  scrollTo(0,0);
  save(undefined, $(this).attr('val') ? $(this).attr('val') : (_oab.plugin === 'instantill' ? '10.1145/2908080.2908114' : '10.1234/oab-syp-aam'));
}
$('body').on('click', '.preview', preview);

var restart = function(e) {
  e.preventDefault();
  scrollTo(0,0);
  _oab.restart();
}
$('body').on('click', '.restart', restart);

jQuery(document).ready(function() {
  if ($('#demo').height() < $(window).height()) $('#demo').css({'min-height':$(window).height()+'px'});
  $('.settings').css({'min-height':$(window).height()+'px'});
  var diff = Math.floor(($(window).height() - $('div.content:visible').height())/4);
  $('div.content:visible').css({'padding-top':diff+'px'});

  noddy.afterLogin = function() {
    $('#loginorurl').hide();
    if ($('.user_id').length) $('.user_id').html('uid: "' + noddy.user.account._id + '"');
    // alter to account for which plugin is in use
    var cfg = false;
    if (noddy.user.account.service && noddy.user.account.service.openaccessbutton) {
      if (_oab.plugin === 'instantill' && noddy.user.account.service.openaccessbutton.ill && noddy.user.account.service.openaccessbutton.ill.config !== undefined) {
        cfg = noddy.user.account.service.openaccessbutton.ill.config;
      } else if (noddy.user.account.service.openaccessbutton.deposit && noddy.user.account.service.openaccessbutton.deposit.config !== undefined) {
        cfg = noddy.user.account.service.openaccessbutton.deposit.config;
      }
    }
    if (cfg) {
      if (!cfg.email) cfg.email = noddy.user.email ? noddy.user.email : noddy.user.emails[0].address;
      _oab.configure(cfg, noddy.user.account._id);
      configure(cfg);
    } else {
      _oab.configure(noddy.user.account._id);
    }
    
    if (_oab.plugin === 'instantill') {
      try { // for ill
        $.ajax({
          url: api + '/ill/url?uid=' + noddy.user.account._id,
          type: 'GET',
          success: function(url) {
            if (url) {
              var ex = 'You can use this as the Base URL to integrate InstantILL into your other systems:<br>' + url + '.<br><br>Here is an example URL:<br>' + url + '?doi=10.1145/2908080.2908114 .<br><br>You likely have a more complex looking OpenURL. Not to worry! InstantILL can recognize a wide variety of standard OpenURL parameters so it should still just work.';
              $('#embeddedexample').html(ex).show();
            } else {
              $('#noembeddedexampleavailable').show();
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
                var ex = 'Here is an example:<br> <a href ="' + eurl + '?doi=10.10/something&email=something@university.edu" target="_blank"> '+ eurl +'?doi=10.10/something&email=something@university.edu</a>.<br><br>Any DOI will work, and you don’t need to include an email if you don’t have it.';
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
    $('#loginorurl').show();
    // if a url is put into loginorurl, get config from queries received from that url if possible, or can try direct from the url too...
    configure(_oab.config);
  }
  if (window.location.href.indexOf('/setup') !== -1) noddy.login(); // login current user on setup page, if possible, but not on other demo pages
});
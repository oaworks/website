
// to use InstantILL, just include this js file, and then call instantill() in a script on the page
// If jquery is not already used on the site, jquery is retrieved too.
// bootstrap can optionally be used to apply styling
// <script src="https://openaccessbutton.org/static/instantill.js"></script>
// <script>jQuery(document).ready(function() { instantill(); });</script>

// new features will be added to this script and a variable will be used to control which users
// see newly developed features. These will be alpha, beta, etc, in a var called version. Running
// this script without that var will result in the latest features being used.

var _oab_opts = {};
var _oab_config = {};
var _lib_contact = undefined;

var instantill_config = function() {
  var opts = _oab_opts;
  var api = opts.api ? opts.api : 'https://api.openaccessbutton.org';
  if (opts.uid) {
    $.ajax({
      type:'GET',
      url:api+'/ill/config?uid='+opts.uid,
      success: function(data) {
        _oab_config = data;
        instantill_run();
      },
      error: function() {
        instantill_run();
      }
    });
  } else {
    instantill_run();
  }
}

var instantill_run = function() {
  var config = _oab_config;
  var cml = config.problem_email ? config.problem_email : (config.email ? config.email : (config.adminemail ? config.adminemail : undefined));
  _lib_contact = 'Please try ' + (cml ? '<a href="mailto:' + cml + '">contacting your library</a>' : 'contacting your library') + ' directly';
  var opts = _oab_opts;
  if (opts.bootstrap === undefined && opts.css === undefined) opts.bootstrap = 'btn btn-primary btn-iu';
  if (opts.placeholder === undefined) opts.placeholder = 'e.g. Lessons in data entry from digital native populations';
  if (opts.data === undefined) opts.data = false;
  var api = opts.api ? opts.api : 'https://api.openaccessbutton.org';
  var site = opts.site ? opts.site : 'https://openaccessbutton.org';
  if (window.location.host.indexOf('dev.openaccessbutton.org') !== -1) {
    if (!opts.api) api = 'https://dev.api.cottagelabs.com/service/oab';
    if (!opts.site) site = 'https://dev.openaccessbutton.org';
  }
  if (opts.element === undefined) opts.element = '#instantill';
  if (opts.uid === undefined) opts.uid = 'anonymous';
  if ($(opts.element).length === 0) $('body').append('<div id="instantill"></div>');

  var w = '<h2 id="oabutton_request" style="display:none;">Request a paper</h2><div id="oabutton_inputs">\
  <p>If you need a paper or book you can request it from any library in the world through Interlibrary loan. \
  Start by entering a full article title, citation, DOI or URL:</p>\
  <p><br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" type="text" id="oabutton_input" placeholder="' + opts.placeholder + '" aria-label="' + opts.placeholder + '" style="box-shadow:none;"></input></p>\
  <p><a class="oabutton_find ' + (opts.bootstrap !== false ? (typeof opts.bootstrap === 'string' ? opts.bootstrap : 'btn btn-primary') : '') + '" href="#" id="oabutton_find" aria-label="Search" style="min-width:150px;">Find paper</a></p>';
  if (config.book || config.other) {
    w += '<p>Need ';
    if (config.book) w += 'a <a href="' + config.book + '"><b>book</b></a>';
    if (config.other) w += (config.book ? ' or ' : ' ') + '<a href="' + config.other + '"><b>something else</b></a>';
    w += '?</p>';
  }
  w += '\
</div>\
<div id="oabutton_availability"></div>\
<div id="oabutton_error" style="display:none;"></div>';

// <img style="width:30px;" src="' + site + '/static/spin_orange.svg">   Powered by the <a href="https://openaccessbutton.org" target="_blank">Open Access Button</a>

  var ws = '#oabutton_inputs {\
  position: relative;\
  display: table;\
  width:100%;\
  border-collapse: separate;\
}\
.oabutton_form {\
  /*display: inline-block;\
  width: 100%;*/\
  height: 34px;\
  padding: 6px 12px;\
  font-size: 16px;\
  line-height: 1.428571429;\
  color: #555555;\
  vertical-align: middle;\
  background-color: #ffffff;\
  background-image: none;\
  border: 1px solid #cccccc;\
  border-radius: 4px;\
  -webkit-box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.075);\
          box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.075);\
  -webkit-transition: border-color ease-in-out 0.15s, box-shadow ease-in-out 0.15s;\
          transition: border-color ease-in-out 0.15s, box-shadow ease-in-out 0.15s;\
}\
#oabutton_find {\
  /*display: table-cell;\
  width:40px;*/\
  height:34px;\
  padding: 6px 3px;\
  margin-bottom: 0;\
  font-size: 14px;\
  font-weight: normal;\
  line-height: 1.428571429;\
  text-align: center;\
  white-space: nowrap;\
  vertical-align: middle;\
  cursor: pointer;\
  background-image: none;\
  border: 1px solid transparent;\
  border-radius: 0px 4px 4px 0px;\
  -webkit-user-select: none;\
     -moz-user-select: none;\
      -ms-user-select: none;\
       -o-user-select: none;\
          user-select: none;\
  color: #ffffff;\
  background-color: #428bca;\
  border-color: #357ebd;\
}\
.oabutton_ill {\
  /*display: inline-block;*/\
  height:34px;\
  padding: 6px 3px;\
  margin-bottom: 0;\
  font-size: 14px;\
  font-weight: normal;\
  line-height: 1.428571429;\
  text-align: center;\
  white-space: nowrap;\
  vertical-align: middle;\
  cursor: pointer;\
  background-image: none;\
  border: 1px solid transparent;\
  border-radius: 4px;\
  -webkit-user-select: none;\
     -moz-user-select: none;\
      -ms-user-select: none;\
       -o-user-select: none;\
          user-select: none;\
  color: #ffffff;\
  background-color: #428bca;\
  border-color: #357ebd;\
}';

  if (opts.bootstrap !== false) {
    var bs = true;
    $('body').append('<div class="btn" id="oabutton_bootstrap_test" style="display:none;"></div>');
    if ( $('#oabutton_bootstrap_test').css('height') !== '0px' ) bs = false;
    $('#oabutton_bootstrap_test').remove();
    if (bs) {
      var bs = document.createElement("link");
      bs.setAttribute("rel", "stylesheet");
      bs.setAttribute("type", "text/css");
      bs.setAttribute("href", site + '/static/bootstrap.min.css');
      document.getElementsByTagName("head")[0].appendChild(bs);
    }
  } else if (opts.css !== false) {
    w = '<style>' + (typeof opts.css === 'string' ? opts.css : ws) + '</style>' + w;
  }
  $(opts.element).html(w);

  var matched = false;
  var avail = undefined;
  var attempts = 0;
  var clickwrong = false;
  var gotmore = false;
  
  var restart = function() {
    matched = false;
    avail = undefined;
    attempts = 0;
    clickwrong = false;
    gotmore = false;
    $('#oabutton_availability').html('').hide();
    $('#oabutton_input').val('');
    $('#oabutton_inputs').show();
  }

  var sorryping = function(what) {
    try {
      var noddy_api = api.indexOf('dev.') !== -1 ? 'https://dev.api.cottagelabs.com' : 'https://api.cottagelabs.com';
      $.ajax({
        url: noddy_api + '/ping.png?service=openaccessbutton&action=' + what
      });
    } catch (err) {}
  }

  var fail = function(info) {
    if (info === undefined) {
      info = '<h3>Unknown article</h3><p>Sorry, we cannot find this article or sufficient metadata. ' + _lib_contact + '</p>';
      sorryping('InstantILL_unknown_article');
    }
    $('.oabutton_find').html('Find paper');
    $('#oabutton_inputs').hide();
    $('#oabutton_availability').html(info).show();
    setTimeout(restart, 6000);
  }

  var openurl = function() {
    $.ajax({
      type:'POST',
      url:api+'/ill/openurl?uid='+opts.uid,
      cache: false,
      processData: false,
      contentType: 'application/json',
      dataType: 'json',
      data: JSON.stringify(avail.data.meta.article),
      success: function(res) {
        window.location = res;
      },
      error: function(data) {
        try {
          window.location = avail.data.ill.openurl;
        } catch(err) {
          $('#oabutton_error').html('<p>Sorry, we could\'nt create an Interlibrary Loan request for you. ' + _lib_contact + '</p>').show();
          sorryping('InstantILL_openurl_couldnt_create_ill');
          fail('');
        }
      }
    });
  }

  var getmore = function(e) {
    try { e.preventDefault(); } catch(err) {}
    if (attempts > 2) {
      fail();
    } else {
      attempts += 1;
      var info = '<div>';
      info += '<p>Sorry we didn\'t find that article! Can you please provide or amend the article details?</p>';
      info += '<p>Article title (required)<br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" id="oabutton_title" type="text"></p>';
      info += '<p>Author(s)<br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" id="oabutton_author" type="text"></p>';
      info += '<p>Journal title (required)<br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" id="oabutton_journal" type="text"></p>';
      info += '<p>Year of publication (required)<br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" id="oabutton_year" type="text"></p>';
      info += '<p>Article DOI or URL<br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" id="oabutton_doi" type="text"></p>';
      info += '<p><a href="#" class="oabutton_find ' + (opts.bootstrap !== false ? (typeof opts.bootstrap === 'string' ? opts.bootstrap : 'btn btn-primary') : '') + '" id="oabutton_find" style="min-width:150px;">Continue</a></p>';
      info += '<p><a href="#" class="restart" style="font-weight:bold;">Try again</a></p>';
      info += '</div>';
      $('#oabutton_availability').html(info);
      gotmore = true;
      try {
        for ( var m in avail.data.meta.article ) {
          try {
            if ( $('#oabutton_'+m).length ) {
              var mv = avail.data.meta.article[m];
              if (m === 'journal' && mv.indexOf('(') !== -1) mv = mv.split('(')[0].trim();
              if (m === 'author' && typeof mv !== 'string') {
                var smv = '';
                for ( var a in mv ) {
                  if (mv[a].fullName) {
                    if (smv !== '') smv += ', ';
                    smv += mv[a].fullName;
                  } else if (mv[a].family) {
                    if (smv !== '') smv += ', ';
                    smv += mv[a].family;
                    if (mv[a].given) smv += ' ' + mv[a].given;
                  }
                }
                mv = smv;
              }
              $('#oabutton_'+m).val(mv);
            }
          } catch(err) {}
        }
      } catch(err) {}
    }
  }

  var cite = function(meta) {
    var c = '';
    // if we got nothing back but what we put in, then we have not found anything suitable :(
    if (meta.year || meta.journal || meta.volume || meta.issue) {
      if (meta.title) c += '<h2>' + meta.title + '</h2>';
      c += '<p><b style="color:#666;">';
      if (meta.year) c += '' + meta.year + (meta.journal || meta.volume || meta.issue ? ', ' : '');
      if (meta.journal) {
        c+= meta.journal;
      } else {
        if (meta.volume) c += 'vol. ' + meta.volume;
        if (meta.issue) c += (meta.volume ? ', ' : '') + 'issue ' + meta.issue;
      }
      c += '</b></p>';
    }
    return c;
  }

  var _submit_ill = function() {
    $('.oabutton_find').html('Submitting .');
    $('.oabutton_ill').html('Submitting .');
    var eml = typeof matched === 'string' ? matched : $('#oabutton_email').val();
    var data = {url:avail.data.match, email:eml, from:opts.uid, plugin:'instantill', embedded:window.location.href, metadata: avail.data.meta.article }
    if (!data.metadata.title || !data.metadata.journal || !data.metadata.year) {
      matched = data.email;
      if (!matched) matched = true;
      getmore();
    } else {
      if (avail.data.ill && avail.data.ill.openurl && avail.data.ill.openurl.indexOf('notes') === -1 && (avail.data.ill.subscription || avail.data.availability)) {
        data.notes = '';
        if (avail.data.ill.subscription) data.notes += 'Subscription check done, found ' + (avail.data.ill.subscription.url ? avail.data.ill.subscription.url : 'nothing') + '. ';
        if (avail.data.availability) data.notes += 'OA availability check done, found ' + (avail.data.availability.length && avail.data.availability[0].url ? avail.data.availability[0].url : 'nothing') + '. ';
      }
      if (avail.data.ill.openurl && opts.openurl !== false && !data.email) data.forwarded = true;
      var illopts = {
        type:'POST',
        url:api+'/ill',
        cache: false,
        processData: false,
        contentType: 'application/json',
        dataType: 'json',
        data: JSON.stringify(data),
        success: function(res) {
          if (avail.data.ill.openurl && opts.openurl !== false && !data.email) {
            if (matched) {
              openurl();
            } else {
              window.location = avail.data.ill.openurl;
            }
          } else {
            $('.oabutton_find').html('Find paper');
            $('.oabutton_ill').html('Complete request');
            var eml = typeof matched === 'string' ? matched : $('#oabutton_email').val();
            $('#oabutton_availability').html('<h3>Thanks! Your request has been received</h3><p>Your confirmation code is: ' + res + ', this will not be emailed to you. The paper will be sent to ' + eml + ' as soon as possible.</p><p><a href="#" class="restart" style="font-weight:bold;">Try again</a></p>').show();
          }
        },
        error: function(data) {
          if (avail.data.ill.openurl && opts.openurl !== false && !data.email) {
            if (matched) {
              openurl();
            } else {
              window.location = avail.data.ill.openurl;
            }
          } else {
            $('.oabutton_find').html('Find paper');
            $('.oabutton_ill').html('Complete request');
            $('#oabutton_error').html('<p>Sorry, we were not able to create an ILL request for you. ' + _lib_contact + '</p><p><a href="#" class="restart" style="font-weight:bold;">Try again</a></p>').show();
            sorryping('InstantILL_couldnt_submit_ill');
            setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
          }
        }
      }
      $.ajax(illopts);
    }
  }
  var ill = function(e) {
    e.preventDefault();
    $('.oabutton_ill').html('Submitting .');
    if ($(this).hasClass('oabutton_ill_email')) {
      try { e.preventDefault(); } catch (err) {}
      if ($('#oabutton_read_terms').length && !$('#oabutton_read_terms').is(':checked')) {
        $('#oabutton_error').html('<p>Please agree to the terms first.</p>').show();
        setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
        return;
      }
      if (!$('#oabutton_email').val().length) {
        $('#oabutton_error').html('<p>Please provide your university email address.</p>').show();
        setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
        $('#oabutton_email').css('border-color','#f04717').focus();
        return;
      } else {
        $.ajax({
          url: api + '/ill/validate?uid=' + opts.uid + '&email=' + $('#oabutton_email').val(),
          type: 'POST',
          success: function(data) {
            if (data === true) {
              _submit_ill();
            } else {
              $('#oabutton_error').html('<p>Sorry, your email does not look right. ' + (data !== false ? 'Did you mean ' + data + '? ' : '') + 'Please check and try again.</p>').show();
              $('.oabutton_ill').html('Complete request');
              setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
            }
          },
          error: function(data) {
            _submit_ill();
          }
        });
      }
    } else {
      _submit_ill();
    }
  }

  var inform = function() {
    $('#oabutton_inputs').hide();
    $('#oabutton_error').html('').hide();
    var info = '';
    if (avail.data.ill && avail.data.ill.error && avail.data.ill.error.length) {
      $('#oabutton_error').html('<p>Please note, we encountered errors querying the following subscription services: ' + avail.data.ill.error.join(', ') + '</p>').show();
      setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
    }
    if (avail.data.meta && avail.data.meta.article) {
      var cit = cite(avail.data.meta.article);
      if (cit.length < 1) {
        if (attempts === 0) {
          attempts = 1;
          getmore();
        } else if ((avail.data.ill.subscription && avail.data.ill.subscription.url) || (avail.data.availability && avail.data.availability.length && avail.data.availability[0].url)) {
          if (avail.data.meta.article.title) {
            info += '<h2>' + avail.data.meta.article.title + '</h2>';
          } else {
            info += '<h2>Unknown article</h2>';
          }
        } else if (!gotmore) {
          fail();
        }
      } else {
        info += cit;
      }
    }
    info += '<p><a id="oabutton_getmore" href="#"><b>This is not the article I searched.</b></a></p>';
    var needmore = true;
    if (avail.data.ill.subscription && avail.data.ill.subscription.url) {
      needmore = false;
      // if there is a subscribed version available show a link to it
      info += '<div>';
      info += '<h3>We have an online copy instantly available</h3>';
      info += '<p><a target="_blank" href="' + avail.data.ill.subscription.url  + '"><b>Open article in a new tab</b></a></p>';
      info += '</div>';
    } else {
      if (avail.data.availability && avail.data.availability.length && avail.data.availability[0].url) {
        needmore = false;
        // else if there is an oa article show a link to it
        info += '<div>';
        info += '<h3><br>There is a free, instantly accessible copy online</h3>';
        info += '<p>It may not be the final published version and may lack graphs or figures making it unsuitable for citations.</p>';
        info += '<p><a target="_blank" href="' + avail.data.availability[0].url  + '"><b>Open article in a new tab</b></a></p>';
        info += '</div>';
        if (opts.requests !== false) {
          if (avail.data.requests) {
            // show the request (not yet part of instantill)
          } else {
            // offer to create a request (not yet part of instantill)
            //info += '<p><a target="_blank" href="' + site + '/request?data=false&plugin=instantill&from=' + opts.uid + '&url=' + encodeURIComponent(data.data.match) + '"><b>Start a request to the author to share it with you</b></a>';
          }
        }
      }
      if (avail.data.ill && opts.ill !== false) {
        needmore = false;
        info += '<div>';
        info += '<h3><br>Ask the library to digitally send you the published full-text via Interlibrary Loan</h3>';
        info += '<p>It ' + (config.cost ? 'costs ' + config.cost : 'is free to you,') + ' and we\'ll usually email the link within ' + (config.time ? config.time : '24 hours') + '.<br></p>';
        if (avail.data.ill.openurl && opts.openurl !== false) {
          if (avail.data.ill.openurl.indexOf('notes') === -1) {
            avail.data.ill.openurl += '&notes=';
            if (avail.data.ill.subscription) avail.data.ill.openurl += 'Subscription check done, found ' + (avail.data.ill.subscription.url ? avail.data.ill.subscription.url : 'nothing') + '. ';
            if (avail.data.availability) avail.data.ill.openurl += 'OA availability check done, found ' + (avail.data.availability.length && avail.data.availability[0].url ? avail.data.availability[0].url : 'nothing') + '. ';
          }
          info += '<p><a class="oabutton_ill oabutton_ill_openurl ' + (opts.bootstrap !== false ? (typeof opts.bootstrap === 'string' ? opts.bootstrap : 'btn btn-primary') : '') + '" href="' + avail.data.ill.openurl + '" style="min-width:150px;">Complete request</a></p>';
        } else {
          if (avail.data.ill.terms) info += '<p id="oabutton_terms_note"><input type="checkbox" id="oabutton_read_terms"> I have read the <a target="_blank" href="' + avail.data.ill.terms + '"><b>terms and conditions</b></a></p>';
          info += '<p><input placeholder="Your university email address" id="oabutton_email" type="text" class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '"></p>';
          info += '<p><a class="oabutton_ill oabutton_ill_email ' + (opts.bootstrap !== false ? (typeof opts.bootstrap === 'string' ? opts.bootstrap : 'btn btn-primary') : '') + '" href="' + api + '/ill?from=' + opts.uid + '&plugin=instantill&data=false&url=' + encodeURIComponent(avail.data.match) + '" style="min-width:150px;">Complete request</a></p>';
        }
        info += '</div>';
      }
    }
    $('.oabutton_find').html('Find paper');
    $('#oabutton_inputs').hide();
    $('#oabutton_availability').html(info).show();
    if ($('.oabutton_ill').length) $('.oabutton_ill').bind('click',ill);
    if ($('#oabutton_email').length) $('#oabutton_email').bind('keyup', function(e) { if (e.keyCode === 13) ill() });
    if ($('#oabutton_getmore').length) {
      $('#oabutton_getmore').bind('click',function(e) { e.preventDefault(); clickwrong = true; getmore(); });
      if (needmore || cit.length === 0) getmore();
    }
  }

  var _doing_availability = false;
  var _intervaled = false;
  var availability = function(e) {
    if (!_doing_availability && ($(this).attr('id') === 'oabutton_find' || e === undefined || e.keyCode === 13)) {
      _doing_availability = true;
      $('#oabutton_error').html('').hide();
      if (e && $(this).attr('id') === 'oabutton_find') e.preventDefault();
      var input = $('#oabutton_input').val().trim();
      if (input.lastIndexOf('.') === input.length-1) input = input.substring(0,input.length-1);
      var data = {};
      if ($('#oabutton_title').length) {
        if ($('#oabutton_title').val()) data.title = $('#oabutton_title').val();
        if ($('#oabutton_author').length && $('#oabutton_author').val()) data.author = $('#oabutton_author').val();
        if ($('#oabutton_journal').length && $('#oabutton_journal').val()) data.journal = $('#oabutton_journal').val();
        if ($('#oabutton_year').length && $('#oabutton_year').val()) data.year = $('#oabutton_year').val();
        if ($('#oabutton_doi').length && $('#oabutton_doi').val()) data.doi = $('#oabutton_doi').val();
        if (data.year && data.year.length !== 4) {
          $('#oabutton_error').html('<p>Please provide the full year e.g 2019</p>').show();
          setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
          return;
        }
        if (!data.title || !data.journal || !data.year) {
          $('#oabutton_error').html('<p>Please complete all required fields</p>').show();
          setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
          return;
        }
      }
      if (matched) {
        for ( var d in data ) {
          if (data[d] && (avail.data.meta.article[d] === undefined || avail.data.meta.article[d] ==='')) avail.data.meta.article[d] = data[d]
        }
        _submit_ill();
        return;
      }
      if (clickwrong) {
        data.wrong = true;
        clickwrong = false;
      }
      if (data.doi && data.doi.indexOf('10.') === -1 && (data.doi.indexOf('/') === -1 || data.doi.indexOf('http') === 0)) {
        data.url = data.doi;
        delete data.doi;
      }
      if (!input || !input.length) input = data.title;
      if (input === undefined || !input.length || (input.toLowerCase().indexOf('http') === -1 && input.indexOf('10.') === -1 && input.indexOf('/') === -1 && isNaN(parseInt(input.toLowerCase().replace('pmc',''))) && (input.length < 30 || input.replace(/\+/g,' ').split(' ').length < 3) ) ) {
        $('#oabutton_error').html('<p>Sorry, we can\'t use partial titles/citations. Please provide the full title or citation, or a suitable URL or identifier.</p>').show();
        setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
        _doing_availability = false;
        return;
      }
      if (!data.url) data.url = input;
      $('.oabutton_find').html('Searching .');
      if (!_intervaled) {
        _intervaled = true;
        setInterval(function() {
          try {
            var w = $('.oabutton_ill').length ? $('.oabutton_ill') : $('.oabutton_find');
            var srch = w.first().html();
            if (srch.indexOf('.') !== -1) {
              var dots = srch.split('.');
              if (dots.length >= 4) {
                srch = srch.replace(/\./g,'').trim() + ' .';
              } else {
                srch += ' .';
              }
              w.html(srch);
            }
          } catch(err) {}
        }, 800);
      }
      data.from = opts.uid;
      data.plugin = 'instantill';
      data.embedded = window.location.href;

      var avopts = {
        type:'POST',
        url:api+'/availability',
        cache: false,
        processData: false,
        contentType: 'application/json',
        dataType: 'json',
        data: JSON.stringify(data),
        success: function(data) {
          _doing_availability = false;
          avail = data;
          $('#oabutton_input').val('');
          inform();
        },
        error: function() {
          _doing_availability = false;
          $('#oabutton_input').val('');
          $('.oabutton_find').html('Find paper');
          $('#oabutton_error').show().html('<p>Oh dear, the service is down! We\'re aware, and working to fix the problem. ' + _lib_contact + '</p>');
          setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
        }
      };
      $.ajax(avopts);
    }
  }
  $('#oabutton_input').bind('keyup',availability);
  $('body').on('click','.oabutton_find',availability);
  $('body').on('click','.restart',restart);
}

var instantill = function(opts) {
  _oab_opts = opts;
  if ($ === undefined) {
    var site = opts.site ? opts.site : 'https://openaccessbutton.org';
    if (window.location.host.indexOf('dev.openaccessbutton.org') !== -1 && !opts.site) site = 'https://dev.openaccessbutton.org';
    var headTag = document.getElementsByTagName("head")[0];
    var jqTag = document.createElement('script');
    jqTag.type = 'text/javascript';
    jqTag.src = site + '/static/jquery-1.10.2.min.js';
    jqTag.onload = instantill_config;
    headTag.appendChild(jqTag);
  } else {
     instantill_config();
  }
}

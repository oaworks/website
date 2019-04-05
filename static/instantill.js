
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

var instantill_config = function() {
  var opts = _oab_opts;
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
  <p><br>If you need a paper or book you can request it from any library in the world through Interlibrary loan. \
  Start by entering a full article title, citation, DOI or URL:</p>\
  <p><br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" type="text" id="oabutton_input" placeholder="' + opts.placeholder + '" aria-label="' + opts.placeholder + '"></input></p>\
  <p><a class="' + (opts.bootstrap !== false ? (typeof opts.bootstrap === 'string' ? opts.bootstrap : 'btn btn-primary') : '') + '" href="#" id="oabutton_find" aria-label="Search">Find paper</a></p>';
  if (config.book || config.other) {
    w += '<p>Need ';
    if (config.book) w += 'a <a href="' + config.book + '"><b>book</b></a>';
    if (config.other) w += (config.book ? ' or ' : ' ') + '<a href="' + config.other + '"><b>something else</b></a>';
    w += '?</p>';
  }
  w += '\
</div>\
<div id="oabutton_loading" style="display:none;margin-top:10px;" class="' + (opts.bootstrap !== false ? 'alert alert-info' : '') + '"><p id="oabutton_searching">Searching</p></div>\
<div id="oabutton_availability"></div>\
<div id="oabutton_error" class="' + (opts.bootstrap !== false ? 'alert alert-danger' : '') + '" style="display:none;"></div>';

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

  var searchfor = undefined;
  var avail = undefined;
  var attempts = 0;
  
  var getmore = function(e) {
    try { e.preventDefault(); } catch(err) {}
    var info = '<div>';
    info += '<p>Sorry that didn\'t work! Can you please tell us the article details?</p>';
    info += '<p>Article title (required)<br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" id="oabutton_title" type="text"></p>';
    info += '<p>Author(s) (required)<br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" id="oabutton_author" type="text"></p>';
    info += '<p>Journal title (required)<br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" id="oabutton_journal" type="text"></p>';
    info += '<p>Year of publication (required)<br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" id="oabutton_year" type="text"></p>';
    info += '<p>Article DOI or URL<br><input class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '" id="oabutton_doi" type="text"></p>';
    info += '<p><a href="#" class="' + (opts.bootstrap !== false ? (typeof opts.bootstrap === 'string' ? opts.bootstrap : 'btn btn-primary') : '') + '" id="oabutton_find">Continue</a></p>';
    info += '</div>';
    $('#oabutton_availability').html(info);
  }
  
  var cite = function(meta) {
    var c = '';
    
    // if we got nothing back but what we put in, then we have not found anything suitable :(
    try { delete meta.started; delete meta.ended; delete meta.took; } catch(err) {}
    var keys = 0
    for ( var k in meta ) keys += 1;
    if (keys.length === 0 || (keys.length === 1 && meta.title && meta.title.toLowerCase() === searchfor.toLowerCase())) return c;
    
    if (meta.title) c += '<h2>' + meta.title + '</h2>';
    if (meta.year || meta.journal || meta.volume || meta.issue) c += '<p><b style="color:#666;">';
    if (meta.year) c += '' + meta.year + (meta.journal || meta.volume || meta.issue ? ', ' : '');
    if (meta.journal) {
      c+= meta.journal;
    } else {
      if (meta.volume) c += 'vol. ' + meta.volume;
      if (meta.issue) c += (meta.volume ? ', ' : '') + 'issue ' + meta.issue;
    }
    if (meta.year || meta.journal || meta.volume || meta.issue) c += '</b></p>';
    return c;
  }
  
  var _submit_ill = function() {
    $('#oabutton_availability').hide();
    $('#oabutton_searching').html('Submitting');
    $('#oabutton_loading').show();
    var data = {url:avail.data.match, email:$('#oabutton_email').val(), from:opts.uid, plugin:'instantill', embedded:window.location.href, metadata: avail.data.meta.article }
    if (avail.data.ill.redirect.indexOf('notes') === -1 && (avail.data.subscription || avail.data.availability)) {
      data.notes = '';
      if (avail.data.subscription) data.notes += 'Subscription check done, found ' + (avail.data.subscription.url ? avail.data.subscription.url : 'nothing') + '. ';
      if (avail.data.availability) data.notes += 'OA availability check done, found ' + (avail.data.availability.length && avail.data.availability[0].url ? avail.data.availability[0].url : 'nothing') + '. ';
    }
    var illopts = {
      type:'POST',
      url:api+'/ill',
      cache: false,
      processData: false,
      contentType: 'application/json',
      dataType: 'json',
      data: JSON.stringify(data),
      success: function(data) {
        $('#oabutton_loading').hide();
        $('#oabutton_searching').html('Searching');
        var email = $('#oabutton_email').val();
        $('#oabutton_availability').html('<h3>Submission confirmed</h3><p>Go you, you\'ve submittted the ILL. The confirmation code is: ' + data + ' and you\'ll be emailed at ' + email + ' with the paper. Save this for your records. You won\'t get an email.</p>').show();
      },
      error: function(data) {
        $('#oabutton_loading').hide();
        $('#oabutton_searching').html('Searching');
        if (window.location.href.indexOf('openaccessbutton.org') !== -1) {
          $('#oabutton_error').html('<p>Sorry, we were not able to create an example ILL request for you - try logging in first.</p>').show();
          setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
        } else {
          $('#oabutton_loading').hide();
          $('#oabutton_error').html('<p>Sorry, we were not able to create an ILL request for you. Please try contacting your library directly.</p>').show();
          setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
        }
      }
    }
    $.ajax(illopts);
  }
  var ill = function(e) {
    if ($(this).hasClass('oabutton_ill_email')) {
      try { e.preventDefault(); } catch (err) {}
      if ($('#oabutton_read_terms').length && !$('#oabutton_read_terms').is(':checked')) {
        $('#oabutton_error').html('<p>Please agree to the terms first.</p>').show();
        setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
        return;
      }
      if (!$('#oabutton_email').val().length) {
        $('#oabutton_error').html('<p>Please provide your email address.</p>').show();
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
              $('#oabutton_error').html('<p>Sorry, we could not validate the email address you provided. ' + (data !== false ? 'Did you mean ' + data + '? ' : '') + 'Please check and try again.</p>').show();
              setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
            }
          },
          error: function(data) {
            _submit_ill();
          }
        });
      }
    } else {
      // do nothing if not the ILL email link, that way the user just gets taken to the openurl redirect page
      // later if we need that to trigger anything else first, add it here then follow the link
    }
  }

  var inform = function() {
    var info = '';
    if (avail.data.meta && avail.data.meta.article) {
      var cit = cite(avail.data.meta.article);
      if (cit.length < 1) {
        if (attempts === 0) {
          attempts = 1;
          getmore();
        } else {
          if (searchfor) info = '<p>' + searchfor + '</p>';
          info += '<p>Unknown article</p>';
        }
      } else {
        info += cit;
      }
    }
    info += '<p><a id="oabutton_getmore" href="#"><b>This is not the article I searched.</b></a></p>';
    var needmore = true;
    if (avail.data.subscription && avail.data.subscription.url) {
      needmore = false;
      // if there is a subscribed version available show a link to it
      info += '<div>';
      info += '<p>We have an online copy instantly available</p>';
      info += '<p><a href="' + avail.data.subscription.url  + '"><b>Open article</b></a></p>';
      info += '</div>';
    } else {
      if (avail.data.availability && avail.data.availability.length && avail.data.availability[0].url) {
        needmore = false;
        // else if there is an oa article show a link to it
        info += '<div>';
        info += '<p><br>There is a free, instantly accessible copy online</p>';
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
        info += '<p><br>Ask the library to digitally send you the published full-text</p>';
        info += '<p>It ' + (config.cost ? 'costs ' + config.cost : 'is free') + ' and we\'ll email a link within ' + (config.time ? config.time : '24 hours') + '.<br></p>';
        if (avail.data.ill.redirect && opts.redirect !== false) {
          if (avail.data.ill.redirect.indexOf('notes') === -1) {
            avail.data.ill.redirect += '&notes=';
            if (avail.data.subscription) avail.data.ill.redirect += 'Subscription check done, found ' + (avail.data.subscription.url ? avail.data.subscription.url : 'nothing') + '. ';
            if (avail.data.availability) avail.data.ill.redirect += 'OA availability check done, found ' + (avail.data.availability.length && avail.data.availability[0].url ? avail.data.availability[0].url : 'nothing') + '. ';
          }
          info += '<p><a class="oabutton_ill ' + (opts.bootstrap !== false ? (typeof opts.bootstrap === 'string' ? opts.bootstrap : 'btn btn-primary') : '') + '" href="' + avail.data.ill.redirect + '">Complete request</a></p>';
        } else {
          if (avail.data.ill.terms) info += '<p id="oabutton_terms_note"><input type="checkbox" id="oabutton_read_terms"> I have read the <a target="_blank" href="' + avail.data.ill.terms + '"><b>terms and conditions</b></a></p>';
          info += '<p><input placeholder="Your university email address" id="oabutton_email" type="text" class="oabutton_form' + (opts.bootstrap !== false ? ' form-control' : '') + '"></p>';
          info += '<p><a class="oabutton_ill oabutton_ill_email ' + (opts.bootstrap !== false ? (typeof opts.bootstrap === 'string' ? opts.bootstrap : 'btn btn-primary') : '') + '" href="' + api + '/ill?from=' + opts.uid + '&plugin=instantill&data=false&url=' + encodeURIComponent(avail.data.match) + '">Complete request</a></p>';
        }
        info += '</div>';
      }
    }
    $('#oabutton_loading').hide();
    $('#oabutton_inputs').hide();
    $('#oabutton_availability').html(info).show();
    if ($('.oabutton_ill').length) $('.oabutton_ill').bind('click',ill);
    if ($('#oabutton_email').length) $('#oabutton_email').bind('keyup', function(e) { if (e.keyCode === 13) ill() });
    if ($('#oabutton_getmore').length) {
      $('#oabutton_getmore').bind('click',getmore);
      if (needmore || cit.length === 0) getmore();
    }
  }

  var availability = function(e) {
    if ($(this).attr('id') === 'oabutton_find' || e === undefined || e.keyCode === 13) {
      $('#oabutton_error').html('').hide();
      if (e && $(this).attr('id') === 'oabutton_find') e.preventDefault();
      var input = $('#oabutton_input').val().trim();
      $('#oabutton_input').val('');
      searchfor = input;
      if (input.lastIndexOf('.') === input.length-1) input = input.substring(0,input.length-1);
      var data = {};
      if ($('#oabutton_title').length) {
        if ($('#oabutton_title').val()) data.title = $('#oabutton_title').val();
        if ($('#oabutton_author').length && $('#oabutton_author').val()) data.author = $('#oabutton_author').val();
        if ($('#oabutton_journal').length && $('#oabutton_journal').val()) data.journal = $('#oabutton_journal').val();
        if ($('#oabutton_year').length && $('#oabutton_year').val()) data.year = $('#oabutton_year').val();
        if ($('#oabutton_doi').length && $('#oabutton_doi').val()) data.doi = $('#oabutton_doi').val();
        if (data.year && data.year.length !== 4) {
          $('#oabutton_error').html('<p>Please provide a 4 digit year</p>').show();
          setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
          return;
        }
        if (!data.title || !data.author || !data.journal || !data.year) {
          $('#oabutton_error').html('<p>Please complete all required fields</p>').show();
          setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
          return;
        }
      }
      if (!input || !input.length) input = data.title;
      if (data.doi && data.doi.indexOf('10.') === -1 && (data.doi.indexOf('/') === -1 || data.doi.indexOf('http') === 0)) {
        data.url = data.doi;
        delete data.doi;
      }
      if (JSON.stringify(data) === '{}') {
        if (input === undefined || !input.length || (input.toLowerCase().indexOf('http') === -1 && input.indexOf('10.') === -1 && input.indexOf('/') === -1 && isNaN(parseInt(input.toLowerCase().replace('pmc',''))) && (input.length < 35 || input.split(' ').length < 3) ) ) {
          $('#oabutton_error').html('<p>Sorry, we can\'t match titles/citations that are too short. Please provide a longer title or citation, or a suitable URL or identifier.</p>').show();
          setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
          return;
        } else {
          if (!data.url) data.url = input;
          $('#oabutton_inputs').hide();
          $('#oabutton_loading').show();
          if ($('#oabutton_searching').length) {
            setInterval(function() {
              var srch = $('#oabutton_searching').html();
              var dots = srch.split('.');
              if (dots.length >= 5) {
                srch = srch.replace(/\./g,'').trim();
              } else {
                srch += ' .';
              }
              $('#oabutton_searching').html(srch);
            }, 800);
          }
        }
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
          avail = data;
          inform();
        },
        error: function() {
          $('#oabutton_loading').hide();
          $('#oabutton_error').show().html('<p>Enter a full article title, citation, or link. Go to library search if you\'re unsure what you\'re looking for.</p>');
          setTimeout(function() { $('#oabutton_error').html('').hide(); }, 5000);
          $('#oabutton_inputs').show()
        }
      };
      $.ajax(avopts);
    }
  }
  $('#oabutton_input').bind('keyup',availability);
  $('body').on('click','#oabutton_find',availability);
}

var instantill = function(opts) {
  _oab_opts = opts;
  if (typeof jQuery=='undefined') {
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
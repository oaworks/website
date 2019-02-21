
// This will become InstantILL, so far is just a copy of openaccessbutton_widget with names changed
// This must do the usual search but then if nothing is found, must offer option to forward the user 
// to "create an ILL" by forwarding them to a page on a library CMS that expects openURL formatted values 
// to be passed to it, and must also (alternatively?) be able to email the ILL to some user at the uni

// to use InstantILL, just include this js file, and then call instantill() in a script on the page
// If jquery is not already used on the site, jquery is required too.
// bootstrap can optionally be used to apply styling
// this can be done like so:
// <script src="https://openaccessbutton.org/static/jquery-1.10.2.min.js"></script>
// <link rel="stylesheet" href="https://openaccessbutton.org/static/bootstrap.min.css">
// <script src="https://openaccessbutton.org/static/instantill.js"></script>
// <script>jQuery(document).ready(function() { instantill(); });</script>

// a comment to fix merge oddities
// need an input field called oabutton_url
// and an oabutton_find button to trigger it (although triggers on enter too)
// and oabutton_availability div required for inserting results
// and optional oabutton_loading

var instantill = function(opts) {
  if (opts === undefined) opts = {};
  if (opts.placeholder === undefined) opts.placeholder = 'Skip the paywall using a URL, DOI, Title, or Citation';
  if (opts.redirect === undefined) opts.redirect = false;
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
  
  var w = '<div id="oabutton_inputs">\
  <input id="oabutton_url" placeholder="' + opts.placeholder + '"></input>\
  <a href="#" id="oabutton_find"><img style="height:90%;" src="' + site + '/static/search.png"></img></a>\
</div>\
<div id="oabutton_loading" style="display:none;"><p><img style="width:30px;" src="' + site + '/static/spin_orange.svg">   Powered by the <a href="https://openaccessbutton.org" target="_blank">Open Access Button</a></p></div>\
<div id="oabutton_availability"></div>';

  var ws = '#oabutton_inputs {\
  position: relative;\
  display: table;\
  width:100%;\
  border-collapse: separate;\
}\
#oabutton_url {\
  display: table-cell;\
  width: 100%;\
  height: 34px;\
  padding: 6px 12px;\
  font-size: 16px;\
  line-height: 1.428571429;\
  color: #555555;\
  vertical-align: middle;\
  background-color: #ffffff;\
  background-image: none;\
  border: 1px solid #cccccc;\
  border-radius: 4px 0px 0px 4px;\
  -webkit-box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.075);\
          box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.075);\
  -webkit-transition: border-color ease-in-out 0.15s, box-shadow ease-in-out 0.15s;\
          transition: border-color ease-in-out 0.15s, box-shadow ease-in-out 0.15s;\
}\
#oabutton_email {\
  display: inline-block;\
  width: 100%;\
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
  display: table-cell;\
  height:34px;\
  width:40px;\
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
}';
  if (opts.css !== false) w = '<style>' + (typeof opts.css === 'string' ? opts.css : ws) + '</style>' + w;
  $(opts.element).html(w);
  
  var match = undefined;
  var ill = function(e) {
    try { e.preventDefault(); } catch (err) {}
    if ( $('#oabutton_email').length ) {
      $('#oabutton_loading').show();
      var illopts = {
        type:'POST',
        url:api+'/ill',
        cache: false,
        processData: false,
        contentType: 'application/json',
        dataType: 'json',
        data: JSON.stringify({url:match, email:$('#oabutton_email').val(), from:opts.uid, plugin:'instantill', embedded:window.location.href }),
        success: function(data) {
          $('#oabutton_loading').hide();
          $('#oabutton_availability').html('<p>Thanks, your ILL request has been sent to your library. You will hear back from them soon.</p>');
        },
        error: function(data) {
          $('#oabutton_loading').hide();
          if (window.location.href.indexOf('openaccessbutton.org') !== -1) {
            $('#oabutton_availability').html('<p>Sorry, we were not able to create an example ILL request for you - try logging in first.</p>');
          } else {
            $('#oabutton_availability').html('<p>Sorry, we were not able to create an ILL request for you. Please try contacting your library directly.</p>');
          }
        }
      }
      $.ajax(illopts);
    } else {
      $('#oabutton_availability').html('<p>Please type your email address then press enter, so we can create an ILL for you - your library will get back to you via the address you provide.<br><input type="text" id="oabutton_email" placeholder="Email address"></p>');
      $('#oabutton_email').bind('keyup', function(e) { if (e.keyCode === 13) ill() });
    }
  }
  
  var availability = function(e) {
    if ($(this).attr('id') === 'oabutton_find' || e === undefined || e.keyCode === 13) {
      if (e && $(this).attr('id') === 'oabutton_find') e.preventDefault();
      var url = $('#oabutton_url').val().trim();
      if (!url.length) {
        $('#oabutton_url').css('border-color','#f04717').focus();
        return;
      }
      if (url.lastIndexOf('.') === url.length-1) url = url.substring(0,url.length-1);
      $('#oabutton_loading').show();
      var avopts = {
        type:'POST',
        url:api+'/availability',
        cache: false,
        processData: false,
        contentType: 'application/json',
        dataType: 'json',
        data: JSON.stringify({url:url,from:opts.uid,plugin:'instantill',embedded:window.location.href}),
        success: function(data) {
          $('#oabutton_loading').hide();
          $('#oabutton_availability').show();
          var has = {};
          if (data.data.availability.length > 0) {
            for ( var a in data.data.availability ) {
              has[data.data.availability[a].type] = {url:data.data.availability[a].url};
            }
          }
          if (data.data.requests.length > 0) {
            for ( var r in data.data.requests ) {
              if (!has[data.data.requests[r].type]) has[data.data.requests[r].type] = {id:data.data.requests[r]._id,ucreated:data.data.requests[r].ucreated,usupport:data.data.requests[r].usupport};
            }
          }
          match = data.data.match;
          if (data.data.match && data.data.match.indexOf('http') !== 0 && data.data.meta && data.data.meta.article && data.data.meta.article.doi) data.data.match = 'https://doi.org/' + data.data.meta.article.doi;
          if (window.location.href.indexOf('test=true') !== -1 && window.location.href.indexOf('ill=true') !== -1) {
            var availability = '<p><b>This article is not freely available (TEST)</b></p>';
            //availability += '<p><a target="_blank" href="' + site + '/request?data=false&plugin=instantill&from=' + opts.uid + '&url=' + encodeURIComponent(data.data.match) + '">Start a request to the author to share it with you</a>';
            availability += '<p><a class="ill" href="' + site + '/ill?from=' + opts.uid + '&plugin=instantill&data=false&url=' + encodeURIComponent(data.data.match) + '">Ask the library to get you a copy through an Interlibrary Loan</a>.</p>';
            $('#oabutton_availability').html(availability);
          } else if (JSON.stringify(has) === '{}') {
            if (data.data.match.indexOf('http') === 0) {
              if (opts.redirect) {
                var dr = {};
                try { dr.title = data.data.meta.article.title; } catch(err) {}
                try { dr.doi = data.data.meta.article.doi; } catch(err) {}
                try { dr.url = data.data.match; } catch(err) {}
                var ropts = {
                  type:'POST',
                  url: api+'/request?fast=true',
                  cache:false,
                  processData:false,
                  contentType: 'application/json',
                  dataType: 'json',
                  data: JSON.stringify(dr),
                  success: function(resp) {
                    window.location = site + '/request/' + resp._id;
                  },
                  error: function() {
                    window.location = site + '/request?url=' + encodeURIComponent(data.data.match);
                  }
                }
                $.ajax(ropts);
              } else {
                var availability = '<p><b>This article is not freely available</b></p>';
                //availability += '<p><a target="_blank" href="' + site + '/request?data=false&plugin=instantill&from=' + opts.uid + '&url=' + encodeURIComponent(data.data.match) + '">Start a request to the author to share it with you</a>';
                availability += '<p><a class="ill" href="' + site + '/ill?from=' + opts.uid + '&plugin=instantill&data=false&url=' + encodeURIComponent(data.data.match) + '">Ask the library to get you a copy through an Interlibrary Loan</a>.</p>';
                $('#oabutton_availability').html(availability);
              }
            } else {
              var availability = '<p>Sorry, we couldn\'t find the article <b>' + data.data.match + '</b>.</p><p>Matching titles and citations can be tricky. Please find a DOI, PMID or PMCID and try again.';
              availability += '<p>Or <a class="ill" href="' + site + '/ill?from=' + opts.uid + '&plugin=instantill&data=false&url=' + encodeURIComponent(data.data.match) + '">ask the library to get you a copy through an Interlibrary Loan</a>.</p>';
              $('#oabutton_availability').html(availability);
            }
          } else if (has.article && !has.data) {
            var availability = '';
            if (has.article.id) {
              availability += '<p style="color:#212f3f;padding-top:0px;">';
              if (has.article.ucreated) {
                availability += 'You already created a request for this article <a class="btn btn-action" href="/request/' + has.article.id + '">View the request</a></p>';
              } else if (has.article.usupport) {
                availability += 'You already support a request for this article <a class="btn btn-action" href="/request/' + has.article.id + '">View the request</a></p>';
              } else {
                availability += '<p><b>This article is not freely available.</b></p>Someone has already requested the author freely share this article<a class="btn btn-action" href="/request/' + has.article.id + '?support=true">Notify me</a></p>';
              }
            } else {
              availability += '<p><b>This article is freely available!</b></p>';
              availability += '<p"><a style="word-wrap:break-word;overflow-wrap:break-word;" target="_blank" href="' + has.article.url + '">' + 'Click here to view it' + '</a></p>';
            }
            if (opts.data) {
              availability += '<p>';
              availability += 'Want the data supporting the article? ';
              availability += '<a target="_blank" class="btn btn-action" href="' + site + '/request?type=data&url=' + encodeURIComponent(data.data.match) + '">Request it from the author</a></p>';
            }
            $('#oabutton_availability').html(availability);
          } else if (!has.article && has.data) {
            var availability = '<p><b>This article is not freely available</b></p>';
            //availability += '<p><a target="_blank" class="btn btn-action" href="' + site + '/request?data=false&url=' + encodeURIComponent(data.data.match) + '">Start a request</a>';
            availability += '<p><a class="ill" href="' + site + '/ill?from=' + opts.uid + '&plugin=instantill&data=false&url=' + encodeURIComponent(data.data.match) + '">Ask the library to get you a copy through an Interlibrary Loan</a>.</p>';
            if (opts.data) {
              availability += '<p>';
              if (has.data.id) {
                  availability += 'Someone has requested access to the data. <a target="_blank" class="btn btn-action" href="' + site + '/request/' + has.data.id + '?support=true">Notify me';
              } else {
                availability += 'However there is data available:</p>';
                availability += '<p"><a style="word-wrap:break-word;overflow-wrap:break-word;" target="_blank" href="' + has.data.url + '">' + has.data.url;
              }
              availability += '</a></p>';
            }
            $('#oabutton_availability').html(availability);
          } else if (has.article && has.data) {
            if (has.article.id && has.data.id && opts.redirect) {
              window.location = site + '/request/' + has.article.id + '?data=false';
            } else {
              var availability = '';
              if (has.article.url) {
                availability += '<p><b>This article is available!</b></p>';
                availability += '<p><a style="word-wrap:break-word;overflow-wrap:break-word;" target="_blank" href="' + has.article.url + '">' + 'Click here to view it</a></p>';
              }
              if (has.article.id) {
                //availability += '<p><b>Someone has already requested the author freely share this article. <a target="_blank" class="btn btn-action" href="' + site + '/request/' + has.article.id + '?data=false&support=true">Notify me</a></b>';
                availability += '<p><a class="ill" href="' + site + '/ill?from=' + opts.uid + '&plugin=instantill&data=false&url=' + encodeURIComponent(data.data.match) + '">Ask the library to get you a copy through an Interlibrary Loan</a>.</p>';
              }
              if (opts.data) {
                availability += '<p>';
                if (has.data.url) {
                  availability += 'And there is data available for this article:</p><p>';
                  availability += '<a style="word-wrap:break-word;overflow-wrap:break-word;" target="_blank" href="' + has.data.url + '">' + has.data.url;
                }
                if (has.data.id) {
                  availability += 'Someone has requested access to the data. <a target="_blank" class="btn btn-action" href="' + site + '/request/' + has.data.id + '?support=true">Notify me';
                }
                availability += '</a></p>';
              }
              $('#oabutton_availability').html(availability);
            }
          }
          if ($('.ill').length) $('.ill').bind('click',ill);
        },
        error: function() {
          $('#oabutton_loading').hide();
          $('#oabutton_loading').after('<p>Sorry, something went wrong. <a target="_blank" href="' + site + '/feedback#bug">Can you let us know?</a></p>');
        }
      };
      $.ajax(avopts);
    }
  }
  $('#oabutton_url').bind('keyup',availability);
  $('#oabutton_find').bind('click',availability);
}

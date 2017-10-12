/* Using the OAB API */

var oab = {

  debug : true, // this puts the button in debug mode, issues debug warnings

  bookmarklet : true, // this lib is also used by a bookmarklet, which sets this to change plugin type

  location : false, // whether or not to try geolocation

  signup : false, // whether or not to prompt signup

  library : 'imperial', // either false or the name of a library to do a catalogue lookup and ILL for

  requestable : false, // whether or not a user is allowed to create a request (whether logged in or not)

  supportable : false, // whether or not a user is allowed to support a request (whether logged in or not)

  dataable : false, // whether or not to bother with the data icons

  api_address : 'https://dev.api.cottagelabs.com/service/oab',// 'https://api.openaccessbutton.org',

  site_address : 'https://dev.openaccessbutton.org',// 'https://openaccessbutton.org',

  howto_address : '/instructions',

  register_address : '/account',

  bug_address : '/feedback#bug',

  messages: 'message', // a div ID name to put error messages etc

  // Tell the API which plugin version is in use for each POST
  signPluginVersion: function(data) {
    // Add the debug key if turned on
    try {
      var manifest = chrome.runtime.getManifest();
      data.plugin = manifest.version_name;
    } catch (err) {
      data.plugin = oab.bookmarklet ? 'bookmarklet_'+oab.bookmarklet : 'oab_test_page';
      if (oab.library) data.plugin = oab.library + '_' + data.plugin;
    }
    if (oab.debug) data.test = true;
    return data;
  },

  sendILL: function(api_key, data, success_callback, failure_callback) {
    // data has story id and title by now - but check oab.availabilityResponse for full info
    if (oab.availabilityResponse) {
      if (!data.title && oab.availabilityResponse.meta && oab.availabilityResponse.meta.article && oab.availabilityResponse.meta.article.title) data.title = oab.availabilityResponse.meta.article.title;
      if (oab.availabilityResponse.meta && oab.availabilityResponse.meta.article && oab.availabilityResponse.meta.article.doi) data.doi = oab.availabilityResponse.meta.article.doi;
      if (oab.availabilityResponse.library && oab.availabilityResponse.library.journal) data.journal = oab.availabilityResponse.library.journal;
      if (oab.availabilityResponse.library.primo) data.primo = oab.availabilityResponse.library.primo;
    }
    data.url = window.location.href;
    if (oab.library) oab.postLocated('/ill/' + oab.library, api_key, data, success_callback, failure_callback);
  },

  sendAvailabilityQuery: function(api_key, data, success_callback, failure_callback) {
    if (oab.library) data.library = oab.library;
    oab.postLocated('/availability', api_key, data, success_callback, failure_callback);
  },

  sendRequestPost: function(api_key, data, success_callback, failure_callback) {
    var request_id = data._id ? data._id : '';
    oab.postLocated('/request/' + request_id, api_key, data, success_callback, failure_callback);
  },

  sendSupportPost: function(api_key, data, success_callback, failure_callback) {
    var request_id = data._id ? data._id : undefined;
    if ( request_id ) {
      oab.postLocated('/support/' + request_id, api_key, data, success_callback, failure_callback);
    } else {
      // refuse to send
      oab.debugLog('Not sending support post without request ID');
    }
  },

  // try to append location to the data object before POST
  postLocated: function(request_type,key,data,success_callback,error_callback) {
    try {
      if (oab.location && navigator.geolocation) {
        var opts = {timeout: 5000};
        navigator.geolocation.getCurrentPosition(function (position) {
          data.location = {geo: {lat: position.coords.latitude, lon: position.coords.longitude}};
          oab.postToAPI(request_type,key,data,success_callback,error_callback);
        }, function (error) {
          oab.debugLog(error.message);
          oab.postToAPI(request_type,key,data,success_callback,error_callback);
        }, opts);
      } else {
        // Browser does not support location
        if (oab.location) oab.debugLog('GeoLocation is unsupported.');
        oab.postToAPI(request_type,key,data,success_callback,error_callback);
      }
    } catch (e) {
      oab.debugLog("A location error has occurred.");
      oab.postToAPI(request_type,key,data,success_callback,error_callback);
    }
  },

  postToAPI: function(request_type, api_key, data, success_callback, failure_callback) {
    var http = new XMLHttpRequest();
    var url = oab.api_address + request_type;
    http.open("POST", url, true);
    http.setRequestHeader("Content-type", "application/json; charset=utf-8");
    if (api_key !== undefined) http.setRequestHeader("x-apikey", api_key);
    http.onreadystatechange = function() {
      if (http.readyState == XMLHttpRequest.DONE) {
        http.status === 200 ? success_callback(JSON.parse(http.response)) : failure_callback(http);
      }
    }
    http.send(JSON.stringify(this.signPluginVersion(data)));
    oab.debugLog('POST to ' + request_type + ' ' + JSON.stringify(data));
  },

  displayMessage: function(msg, div, type) {
    if (div === undefined) div = document.getElementById(oab.messages);
    if (type === undefined) {
      type = '';
    } else if ( type === 'error' ) {
      type = 'alert-danger';
    }
    div.innerHTML = '<div class="alert ' + type + '" role="alert">' + msg + '</div>';
  },

  handleAPIError: function(data, displayError) {
    document.getElementById('icon_submitting').className = 'collapse';
    document.getElementById('icon_loading').className = 'collapse';
    var error_text = '';
    if (data.status === 400) {
      error_text = 'Sorry, the Button does not work on pages like this. You might want to check the <a href="' + oab.site_address + oab.howto_address + '" id="goto_instructions">instructions</a> for help. If you think it should work here, <a id="goto_bug" href="' + oab.site_address + oab.bug_address + '">file a bug</a>.';
    } else if (data.status === 401) {
      error_text = "You need an account for this. Go to ";
      error_text += '<a href="' + oab.site_address + oab.register_address + '" id="goto_register">';
      error_text += oab.site_address + oab.register_address + "</a> and either sign up or sign in - then your plugin will work.";
    } else if (data.status === 403) {
      error_text = 'Something is wrong, please <a id="goto_bug" href="' + oab.site_address + oab.bug_address + '">file a bug</a>.';
    } else if (data.status === 412) {
      error_text = data.response.message;
    } else {
      error_text = data.status + '. Hmm, we are not sure what is happening. You or the system may be offline. Please <a id="goto_bug" href="' + oab.site_address + oab.bug_address + '">file a bug</a>.';
    }
    if (error_text !== '') {
      var error_img = '<p><img src="';
      error_img += oab.bookmarklet ? oab.site_address + '/static/bookmarklet/img/error.png' : '../img/error.png';
      error_img += '" style="margin:5px auto 10px 100px;"></p>';
      error_text = error_img + error_text;
      document.getElementById('loading_area').className = 'row collapse';
      oab.displayMessage(error_text, undefined, 'error');
      if (chrome && chrome.tabs) {
        if ( document.getElementById('goto_instructions') ) {
          document.getElementById('goto_instructions').onclick = function () {
            chrome.tabs.create({'url': oab.site_address + oab.howto_address});
          };
        }
        if ( document.getElementById('goto_bug') ) {
          document.getElementById('goto_bug').onclick = function () {
            chrome.tabs.create({'url': oab.site_address + oab.bug_address});
          };
        }
        if ( document.getElementById('goto_register') ) {
          document.getElementById('goto_register').onclick = function () {
            chrome.tabs.create({'url': oab.site_address + oab.register_address});
          };
        }
      }
    }
  },

  debugLog: function(message) {
    if (oab.debug) {
      console.log(message)
    }
  }
};

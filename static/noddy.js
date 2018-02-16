
noddy = {};

noddy.getCookie = function(cname) {
  if (cname === undefined) cname = noddy.cookie;
  var name = cname + "=";
  var ca = document.cookie.split(';');
  for (var i=0; i<ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0)==' ') c = c.substring(1);
    if (c.indexOf(name) != -1) return JSON.parse(decodeURIComponent(c.substring(name.length,c.length)));
  }
  return false;
}

noddy.setCookie = function(name, values, options) {
  options = options || {};
  var text = name + '=';
  if (values) {
    if (!options.raw) values = encodeURIComponent(JSON.stringify(values));
    text += values;
  }

  // expires
  var date = options.expires;
  if (typeof date === 'number') {
    date = new Date();
    date.setDate(date.getDate() + options.expires);
  }
  if (date instanceof Date) text += '; expires=' + date.toUTCString();
  // domain
  if (typeof options.domain === 'string' && options.domain !== '') text += '; domain=' + options.domain;
  // path
  if (typeof options.path === 'string' && options.path !== '') {
    text += '; path=' + options.path;
  } else {
    text += '; path=/';
  }
  // secure
  if (options.secure) text += '; secure';
  // httponly
  if (options.httponly) text += '; HttpOnly';

  document.cookie = text;
  return text;
};

noddy.removeCookie = function(name,domain) {
  noddy.setCookie(name,undefined,{domain:domain,expires:-1});
}

noddy.hasRole = function(grouprole) {
  var parts = grouprole.split('.');
  var group = parts.length === 2 ? parts[0] : '__global_roles__';
  var role = parts.length === 2 ? parts[1] : parts[0];
  var roles = noddy.getCookie().roles;
  return roles && ( (roles[group] && roles[group].indexOf(role) !== -1) || (roles.__global_roles__ && roles.__global_roles__.indexOf('root') !== -1) );
}
noddy.addrole = function(grouprole,uid) {
  if (uid === undefined) uid = noddy.user.account._id;
  var opts = {
    type:'POST',
    url: noddy.api + '/accounts/'+uid+'/roles/'+grouprole,
    success: function(data) {
      if (noddy.debug) console.log('role add success');
    },
    error: function(data) {}
  }
  if (noddy.apikey) opts.beforeSend = function (request) { request.setRequestHeader("X-apikey", noddy.apikey); }
  $.ajax(opts);
}
noddy.removerole = function(grouprole,uid) {
  if (uid === undefined) uid = noddy.user.account._id;
  var opts = {
    type:'DELETE',
    url: noddy.api + '/accounts/'+uid+'/roles/'+grouprole,
    success: function(data) {
      if (noddy.debug) console.log('role remove success');
    },
    error: function(data) {}
  }
  if (noddy.apikey) opts.beforeSend = function (request) { request.setRequestHeader("X-apikey", noddy.apikey); }
  $.ajax(opts);
}

// if a user is logged in you can then control which parts of UI to show them
// NOTE this is not secure - if your UI has unsecure data in it, anyone can see it if they know how
// but this is actually always the case. Any app that can be within the js context of the browser page
// has access to the content that is in the page, including the cookies. So we are no worse off,
// as long as we retrieve the sensitive data via js and insert into the page IF the user is signed in.

// If the user is logged in, and if the accounts system is setting cookies that are not limited to httponly,
// then a query can be sent to the accounts API for more account data about the logged in user, such as their API key.

noddy.debug = false; // if true will output debug messages to console
noddy.api = window.location.host.indexOf('test.cottagelabs.com') === -1 ? 'https://api.cottagelabs.com' : 'https://dev.api.cottagelabs.com';
noddy.fingerprint = true; // if true the fingerprint library will be necessary too
noddy.hashlength = 40; // this should ideally be retrieved via an init request to accounts API for config settings
noddy.tokenlength = 7; // as above
noddy.cookie = 'noddy'; // the name we use for our login cookie
noddy.days = 180;
noddy.next = undefined; //  place to go after login (can be read from url vars too, and from old cookie)
noddy.apikey = undefined; // this could be set manually but should not be. If cookies are restricted to httponly the backend will return a key that can be used

noddy.oauthRedirectUri = undefined; // this can be set, but if not, current page will be used (whatever is used has to be authorised as a redirect URI with the oauth provider)
noddy.oauthGoogleClientId = '360291218230-r9lteuqaah0veseihnk7nc6obialug84.apps.googleusercontent.com';
noddy.oauthFacebookAppId = '161023221115840';

noddy.user = {
  email:undefined, // set to email string when user provides email, or email found in cookie
  account:undefined, // set to user object when user account info retrieved via login or account info retrieval - expect profile object and username string keys
  token:undefined, // set to success or error after a request is sent to get a login email token sent to a user. Also token supplied in UI is stored here
  login:undefined, // set to success or error after login attempt is sent to backend
  logout:undefined, // as above but for logout...
  retrieved:undefined, // set to success or error when user account info is retrieved
  fingerprint:undefined // whenever a device fingerprint is calculated it will be stored here
};

// the following functions can be customised, but do not necessarily need to be
// it may be useful to customise the failure callback if you have a contact email address, and
// there is also the afterLogin function where you can put any functionality you want to happen after a login is completed

noddy.afterFailure = function(data,action) {} // a function to customise to do something after failure
noddy.failureCallback = function(data,action) {
  $('.noddyLoading').hide();
  data.page = window.location.href;
  data.action = action;
  data.user = noddy.user;
  data.cookie = noddy.getCookie();
  if ( action === 'login' ) {
    if (data.cookie) noddy.removeCookie(noddy.cookie,data.cookie.domain);
    if ( $('#noddyToken').length && $('#noddyToken').val().length === noddy.tokenlength ) {
      // token login error seems to be occurring, so say token must be invalid
      $('.noddyMessage').html('<p>Sorry, your login token appears to be invalid. Please refresh the page and try logging in again.</p>');
    }
  }
  if ( action === 'oauth' ) $('.noddyMessage').html('<p>Sorry, we could not sign you in. Please try another method.</p>');
  if (action === 'login' || action === 'oauth') {
    $('.noddin').hide();
    $('.nottin').show();
    $('.noddyToken').hide();
    $('.noddyLogin').show();
  }
  try {
    data.navigator = {
      userAgent: navigator.userAgent,
      platform: navigator.platform,
      vendor: navigator.vendor,
      plugins: navigator.plugins
    }
  } catch(err) {}
  $.ajax({
    type:'POST',
    url: noddy.api+'/mail/feedback?token=08f98hfwhef98wehf9w8ehf98whe98fh98hw9e8h',
    cache:false,
    processData:false,
    contentType: 'application/json',
    dataType: 'json',
    data:JSON.stringify(data)
  });
  if (noddy.debug) console.log('Login failure callback sent error msg to remote');
  if (action !== undefined && typeof noddy[action+'Failure'] === 'function') {
    noddy[action+'Failure']();
  } else if (typeof noddy.afterFailure === 'function') {
    noddy.afterFailure();
  }
}

noddy.form = function(matcher) {
  if (noddy.debug) console.log('Noddy building form');
  if ( !$(matcher).length ) {
    var form = '<div class="noddyLogin">';
    form += '<p><input type="email" class="form-control" id="noddyEmail" placeholder="Enter your email address"></p>';
    form += '<p><button id="noddyLogin" type="submit" class="btn btn-primary btn-block">Log in</button></p>';
    form += '<p><a id="noddyOauthGoogle" class="btn btn-default btn-block" href="#">Sign in with Google</a></p>';
    form += '<a id="noddyOauthFacebook" class="btn btn-default btn-block" href="#">Sign in with Facebook</a></p>';
    form += '</div>';
    form += '<div class="noddyToken" style="display:none;">';
    form += '<p><input type="text" class="form-control" id="noddyToken" placeholder="Enter your token"></p>';
    form += '<p>A login email has been sent to you. Please click the link in the email, or enter the token above. If you don\'t get the email, check your spam.</p>'
    form += '</div>';
    form += '<div class="noddyMessage" style="margin-top:5px;"></div>';
    form += '<div class="noddyLoading"><img style="height:30px;" src="//static.cottagelabs.com/spin_grey.svg"></div>';
    $((matcher !== undefined ? matcher : 'body')).html(form);
  }
}

noddy.retrieve = function(email,callback) {
  if (noddy.debug) console.log('Noddy retrieving account info');
  $('.noddyLoading').show();
  $('.noddyMessage').html('');
  var opts = {
    type:'GET',
    url: noddy.api + '/accounts/'+noddy.user.email,
    success: function(data) {
      $('.noddyLoading').hide();
      noddy.user.retrieved = 'success';
      noddy.user.account = data.data;
      if (typeof callback === 'function') callback();
    },
    error: function(data) {
      noddy.user.retrieved = 'error';
      noddy.user.account = 'error';
    }
  }
  if (noddy.apikey) opts.beforeSend = function (request) { request.setRequestHeader("X-apikey", noddy.apikey); }
  $.ajax(opts);
}

noddy.progress_interval;
noddy.tokenSuccess = function(data) {
  if (noddy.debug) console.log('Login token successfully requested');
  noddy.user.token = 'requested'; // check nothing relied on this being success, the old value
  $('.noddyLoading').hide();
  $('.noddyLogin').hide();
  $('.noddyToken').show();
  $('#noddyToken').focus();
  if (data && data.responseText) data = data.responseText;
  noddy.progress_interval = setInterval(noddy.tokenProgress,3000);
  if (data && data.mid && data.mid !== true) {
    noddy.setCookie('noddyprogress',{interval:noddy.progress_interval,mid:data.mid,email:noddy.user.email,createdAt:(new Date()).valueOf()});
  } else {
    noddy.tokenProgress();
  }
}
noddy.tokenProgress = function() {
  if (noddy.getCookie(noddy.cookie)) window.location = window.location.href;
  var progress = noddy.getCookie('noddyprogress');
  var timeout = (new Date()).valueOf() - 180000;
  if (progress && progress.createdAt > timeout) {
    var opts = {
      type:'GET',
      url: noddy.api + '/mail/progress?q=Message-Id.exact:"' + progress.mid + '"',
      success: function(data) {
        try {
          var event = data.hits.hits[0]._source.event;
          noddy.user.token = event;
          if (event === 'delivered') $('#noddyToken').attr('placeholder','Delivered to ' + progress.email).css('border-color','orange');
          if (event === 'opened') $('#noddyToken').attr('placeholder','Email opened by ' + progress.email).css('border-color','green');
          if (event === 'dropped') {
            $('#noddyToken').attr('placeholder','Enter your email address').css('border-color','#ccc');
            $('.noddyLogin').show();
            $('.noddyToken').hide();
            $('.noddyMessage').html('Email failed to deliver to ' + progress.email + '. Please try again.');
            clearInterval(progress.interval);
            noddy.removeCookie('noddyprogress');
          }
        } catch(err) {}
      }
    }
    $.ajax(opts);
  } else if (progress && progress.interval) {
    clearInterval(progress.interval);
    noddy.removeCookie('noddyprogress');
  } else if (noddy.progress_interval) {
    clearInterval(noddy.progress_interval);
  }
}
noddy.token = function(e) {
  if (e) e.preventDefault();
  if (noddy.debug) console.log('Login requesting token');
  try { noddy.removeCookie(noddy.cookie); } catch(err) {}
  $('.noddyLoading').show();
  $('.noddyMessage').html('');
  if (noddy.user.email === undefined) noddy.user.email = $('#noddyEmail').val();
  if (!noddy.user.email) {
    // TODO add a mailgun email verification step - if not verified, bounce back to the user to fix and try again
    $('#noddyEmail').css('border-color','#f04717').focus();
    return;
  }
  $('#noddyToken').attr('placeholder','Delivering to ' + noddy.user.email);
  var opts = {
    type:'POST',
    cache: false,
    success:noddy.tokenSuccess,
    error:noddy.tokenSuccess,
    url: noddy.api + '/accounts/token'
  }
  var url = window.location.protocol+'//'+window.location.hostname
  if (window.location.pathname !== '/') url += window.location.pathname;
  if (opts.type === 'POST') {
    opts.data = {
      email: noddy.user.email,
      url: url,
      service: noddy.service
    };
    opts.dataType = 'JSON';
    opts.contentType = 'application/json';
  } else {
    opts.url += '?email='+encodeURIComponent(noddy.user.email)+'&url='+url+'&service='+noddy.service;
  }
  if (noddy.fingerprint) {
    try {
      new Fingerprint2().get(function(result, components) {
        noddy.user.fingerprint = result;
        if (opts.type === 'POST') {
          opts.data.fingerprint = result;
          opts.data = JSON.stringify(opts.data);
        } else {
          opts.url += '&fingerprint=' + result;
        }
        $.ajax(opts);
      });
    } catch(err) {
      opts.data = JSON.stringify(opts.data);
      $.ajax(opts);
    }
  } else {
    opts.data = JSON.stringify(opts.data);
    $.ajax(opts);
  }
  // this should really be the ajax success callback, but some browsers appear to behave oddly after the GET request
  // even if it is successful. So instead just call it directly.
  if (opts.type === 'GET') noddy.tokenSuccess();
}
noddy.loginWithToken = function() {
  if (noddy.debug) console.log('Login logging in with token');
  var token = $('#noddyToken').val();
  if ( token.length === noddy.tokenlength ) noddy.login();
}

noddy.afterOauth = function() {}
noddy.oauthLogin = function() {
  if (noddy.debug) console.log('Noddy has valid oauth creds, passing to backend to login user');
  if (noddy.debug) console.log(noddy.oauth);
  var opts = {
    type:'POST',
    url: noddy.api + '/accounts/login',
    cache:false,
    processData:false,
    contentType: 'application/json',
    dataType: 'json',
    success: function(data) {
      noddy.afterOauth();
      noddy.loginSuccess(data);
    },
    error: function(data) {
      noddy.oauth = undefined;
      noddy.user.login = 'error';
      noddy.failureCallback(data,'oauth');
    }
  }
  var data = {
    oauth: noddy.oauth,
    service: noddy.service,
    location: window.location.protocol + '//' + window.location.hostname
  }
  if (window.location.pathname !== '/') data.location += window.location.pathname;
  opts.data = JSON.stringify(data);
  if ('.noddyLoading') $('.noddyLoading').show();
  $.ajax(opts);
}

noddy.afterLogin = function() {
  // something the user of this lib can configure to do things after the loginCallback runs
  // or they could just overwrite the loginCallback for complete control
}
noddy.loginSuccess = function(data) {
  if (noddy.debug) console.log('Login successful');
  noddy.user.login = 'success';

  var progress = noddy.getCookie('noddyprogress');
  if (progress) {
    clearInterval(progress.interval);
    noddy.removeCookie('noddyprogress');
  } else if (noddy.progress_interval) {
    clearInterval(noddy.progress_interval);
  }
  var nextcookie = noddy.getCookie('noddynext');
  if (nextcookie) {
    noddy.next = nextcookie.next;
    noddy.removeCookie('noddynext');
  } else {
    $('.noddyLoading').hide();
    $('.noddyLogin').hide();
    $('.noddyToken').hide();
    $('.nottin').hide();
    $('.noddin').show();
  }

  noddy.apikey = data.apikey;
  noddy.user.account = data.account;
  if (noddy.user.email === undefined) noddy.user.email = noddy.user.account.email;

  //data.cookies = ['http://localhost:3000/api/accounts/cutter?test=1234'];
  if (data.cookies) {
    for ( var dc in data.cookies ) {
      $('body').append('<iframe class="noddy_cookie_cutter" style="display:none;" src="' + data.cookies[dc] + '&apikey=' + noddy.apikey + '"></iframe>');
    }
    setTimeout(function() { $('.noddy_cookie_cutter').remove(); },3000);
  }

  var cookie = data.account;
  cookie.timestamp = data.settings.timestamp;
  cookie.resume = data.settings.resume;
  cookie.domain = data.settings.domain;
  if (noddy.fingerprint) {
    try {
      new Fingerprint2().get(function(result, components) {
        noddy.user.fingerprint = result;
        cookie.fingerprint = result;
        noddy.setCookie(noddy.cookie, cookie, data.settings);
        if (noddy.next) {
          window.location = noddy.next;
        } else if (typeof noddy.afterLogin === 'function') {
          noddy.afterLogin();
        }
      });
    } catch(err) {
      noddy.setCookie(noddy.cookie, cookie, data.settings);
      if (noddy.next) {
        window.location = noddy.next;
      } else if (typeof noddy.afterLogin === 'function') {
        noddy.afterLogin();
      }
    }
  } else {
    noddy.setCookie(noddy.cookie, cookie, data.settings);
    if (noddy.next) {
      window.location = noddy.next;
    } else if (typeof noddy.afterLogin === 'function') {
      noddy.afterLogin();
    }
  }
}
noddy.nologin = function() {
  // a function to run if there is nothing to perform for a login, e.g. no email or hash available
  // this is most handily replaced by a function that does what is needed on pages where users must be logged in
  if (noddy.debug) console.log('No login info available');
}
noddy.login = function(e) {
  if (e) e.preventDefault();
  try {
    // a reloader for use in dev - if the noddy build.js script is being used, and knows to update the API reloader
    if (noddy.debug && typeof noddy.reload === 'function' && noddy.service && _reloadpid === undefined) {
      console.log('Starting reloader');
      _reloadpid = setInterval(noddy.reload, 2000);
    }
  } catch(err) {}

  // init calls login, and if login fails (e.g. user does not already have an auth cookie that works), bind the login buttons so they can be used
  $('#noddyLogin').unbind('click').bind('click',noddy.token);
  $('#noddyEmail').unbind('keyup').bind('keyup',function(e) { if (e.keyCode === 13) { $('#noddyLogin').trigger('click'); } });
  $('#noddyToken').unbind('keyup').bind('keyup',noddy.loginWithToken);
  $('#noddyLogout').unbind('click').bind('click',noddy.logout);

  // first check to see if an oauth login has been started
  if ( window.location.hash.indexOf('access_token=') !== -1 ) {
    if (noddy.debug) console.log('Noddy validating oauth creds found in url hash');
    $('#noddyEmail').hide();
    $('.noddyLoading').show();
    var pts = window.location.hash.replace('#','').split('&');
    noddy.oauth = {};
    for ( var p in pts ) noddy.oauth[pts[p].split('=')[0]] = pts[p].split('=')[1];
    var oauthcookie = noddy.getCookie('noauth');
    if (noddy.debug) console.log(oauthcookie);
    noddy.oauth.service = oauthcookie.service;
    if (noddy.debug) console.log(noddy.oauth.state === oauthcookie.state)
    if (noddy.oauth.state === oauthcookie.state) noddy.oauthLogin()
    try {
      if (!noddy.debug && 'pushState' in window.history) window.history.pushState("", "oauth", window.location.pathname + window.location.search);
    } catch(err) {}
    if (!noddy.debug) noddy.removeCookie('noauth');
  } else {
    if (noddy.debug) console.log('Login starting login');

    // init calls login, so if not already in an oauth loop and oauth buttons exist on page, bind them here so they can be used
    var state = Math.random().toString(36).substring(2,8);
    if (noddy.oauthRedirectUri === undefined) noddy.oauthRedirectUri = window.location.href.split('#')[0].split('?')[0];
    if ( $('#noddyOauthGoogle').length && noddy.oauthGoogleClientId ) {
      if (noddy.debug) console.log('Noddy prepping google oauth button');
      var grl = 'https://accounts.google.com/o/oauth2/v2/auth?response_type=token&include_granted_scopes=true';
      grl += '&scope=https://www.googleapis.com/auth/userinfo.email+https://www.googleapis.com/auth/userinfo.profile';
      grl += '&state=' + state + '&redirect_uri=' + noddy.oauthRedirectUri + '&client_id=' + noddy.oauthGoogleClientId;
      $('#noddyOauthGoogle').attr('href',grl).unbind('click').bind('click',function() { noddy.setCookie('noauth',{state:state,service:'google'},{expires:1}); });
    }
    if ( $('#noddyOauthFacebook').length && noddy.oauthFacebookAppId ) {
      if (noddy.debug) console.log('Noddy prepping facebook oauth button');
      var frl = 'https://www.facebook.com/v2.10/dialog/oauth?state=' + state;
      frl += '&response_type=token&scope=public_profile,email,user_friends';//,user_location';
      frl += '&redirect_uri=' + noddy.oauthRedirectUri + '&client_id=' + noddy.oauthFacebookAppId;
      $('#noddyOauthFacebook').attr('href',frl).unbind('click').bind('click',function() { noddy.setCookie('noauth',{state:state,service:'facebook'},{expires:1}); });
    }

    $('.noddyMessage').html('');
    var progress = noddy.getCookie('noddyprogress');
    if (progress && !$('#noddyToken').val()) {
      noddy.tokenSuccess();
    } else {
      noddy.removeCookie('noddyprogress');
    }
    if (!noddy.next && window.location.href.indexOf('next=') !== -1) noddy.next = decodeURIComponent(window.location.href.split('next=')[1].split('&')[0]);
    if (!noddy.next && noddy.getCookie('noddynext')) noddy.next = noddy.getCookie('noddynext');
    if (noddy.next && !noddy.getCookie('noddynext')) noddy.setCookie('noddynext', {next:noddy.next}, {expires:1});

    var opts = {
      type:'POST',
      url: noddy.api + '/accounts/login',
      cache:false,
      processData:false,
      contentType: 'application/json',
      dataType: 'json',
      success: noddy.loginSuccess,
      error: function(data) {
        noddy.user.login = 'error';
        noddy.failureCallback(data,'login');
      }
    }
    if ( window.location.hash.replace('#','').length === noddy.hashlength ) {
      noddy.user.hash = window.location.hash.replace('#','');
      try { if ('pushState' in window.history) { window.history.pushState("", "token", window.location.pathname + window.location.search); } } catch(err) {}
    }
    var data = {
      email: noddy.user.email,
      token: $('#noddyToken').val(),
      hash: noddy.user.hash,
      service: noddy.service,
      url: window.location.protocol + '//' + window.location.hostname
    }
    noddy.user.token = data.token;
    if (window.location.pathname !== '/') data.url += window.location.pathname;
    var cookie = noddy.getCookie();
    if (cookie) {
      if ( !data.email ) data.email = cookie.email;
      data.fingerprint = cookie.fingerprint;
      data.resume = cookie.resume;
      data.timestamp = cookie.timestamp;
    }
    if (!data.email && progress) data.email = progress.email;
    opts.data = JSON.stringify(data);
    if ( data.email || data.hash ) {
      $('.noddyLoading').show();
      $.ajax(opts);
    } else {
      $('.noddin').hide();
      $('.nottin').show();
      noddy.nologin();
    }
  }
}

noddy.afterLogout = function() {}
noddy.logoutSuccess = function() {
  if (noddy.debug) console.log('Logout successful');
  var cookie = noddy.getCookie();
  if (cookie) noddy.removeCookie(noddy.cookie,cookie.domain);
  noddy.apikey = undefined; // just in case one was set
  noddy.user = {logout:'success'};
  $('.noddyLoading').hide();
  $('.noddin').hide();
  $('.nottin').show();
  $('.noddyLogin').show();
  // and what if they want to logout all sessions, not just this one?
  if (typeof noddy.afterLogout === 'function') noddy.afterLogout();
}
noddy.logout = function(e) {
  if (e) e.preventDefault();
  if (noddy.debug) console.log('Logging out');
  $('.noddyLoading').show();
  $('.noddyMessage').html('');
  var opts = {
    type:'POST',
    url: noddy.api + '/accounts/logout',
    cache:false,
    processData:false,
    contentType: 'application/json',
    dataType: 'json',
    success: noddy.logoutSuccess
  }
  var data = {
    email: noddy.user.email,
    url: window.location.protocol + '//' + window.location.hostname
  }
  if (window.location.pathname !== '/') data.url += window.location.pathname;
  var cookie = noddy.getCookie();
  if (cookie) {
    if ( !data.email ) data.email = cookie.email;
    data.fingerprint = cookie.fingerprint;
    data.resume = cookie.resume;
    data.timestamp = cookie.timestamp;
  }
  opts.data = JSON.stringify(data);
  if ( data.email ) $.ajax(opts);
}

noddy.loggedin = function() {
  return noddy.getCookie();
}
noddy.init = function(opts) {
  if (opts) {
    for ( var o in opts ) noddy[o] = opts[o];
  }
  if (noddy.debug) {
    console.log("Login initialising");
    if (opts) console.log(opts);
  }
  if (!$('#noddyEmail').length && typeof noddy.form === 'function') noddy.form();
  noddy.login();
}

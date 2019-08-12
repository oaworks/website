
var details = undefined;
var rec = {};
var runrequest = undefined;

var blacklist = function(e) {
  e.preventDefault();
  var email = $('#admin_email').val();
  $('#admin_email').val("");
  var opts = {
    type:'POST',
    url: api+'/dnr?refuse=false&email=' + email,
    cache:false,
    contentType: 'application/json',
    dataType: 'json'
  }
  $.ajax(opts);
  $("#emailissue").html(email + " blacklisted and removed. Provide a new email address, and/or save this request.").show();
}

var adminsubmitting = false;
var submit = function(e) {
  if (e) e.preventDefault();
  var data = {};
  if ( $('#email').length && $('#email').val() ) data.email = $('#email').val();
  if ( $('#title').length && $('#title').val() ) data.title = $('#title').val();
  if ( $('#doi').length && $('#doi').val() ) data.doi = $('#doi').val();
  if ( $('#story').length && $('#story').val() ) data.story = $('#story').val();
  if (noddy.hasRole('openaccessbutton.admin') && adminsubmitting) {
    if ( $('#name').length ) data.name = $('#name').val();
    if ( $('#status').length ) data.status = $('#status').val();
    if ( $('#author_affiliation').length ) data.author_affiliation = $('#author_affiliation').val();
    if ( $('#rating').length ) data.rating = $('#rating').val();
    if ( $('#url').length ) data.url = $('#url').val();
    if ( $('#test').length ) {
      $('#test').is(':checked') ? data.test = true : data.test = false;
    }
    if ( $('#admin_email').length && $('#admin_email').val() ) data.email = $('#admin_email').val();
    if ( $('#admin_title').length && $('#admin_title').val() ) data.title = $('#admin_title').val();
    if ( $('#admin_journal').length && $('#admin_journal').val() ) data.journal = $('#admin_journal').val();
    if ( $('#admin_doi').length && $('#admin_doi').val() ) data.doi = $('#admin_doi').val();

    if ( $('#admin_access_right').length && $('#admin_access_right').val() ) data.access_right = $('#admin_access_right').val();
    if ( $('#admin_embargo_date').length && $('#admin_embargo_date').val() ) data.embargo_date = $('#admin_embargo_date').val();
    if ( $('#admin_access_conditions').length && $('#admin_access_conditions').val() ) data.access_conditions = $('#admin_access_conditions').val();
    if ( $('#admin_license').length && $('#admin_license').val() ) data.license = $('#admin_license').val();
    if ( $('#admin_received_description').length && $('#admin_received_description').val() ) data.received = {description: $('#admin_received_description').val()};

    if ( $('#admin_story').length && ($('#admin_story').val() || $('#admin_story').val() !== rec.story) ) data.story = $('#admin_story').val();
    if ( $('#admin_notes').length && $('#admin_notes').val() ) data.notes = $('#admin_notes').val();
    adminsubmitting = false;
  }
  var url = api+'/request/'+rec._id;
  var opts = {
    type:'POST',
    url: url,
    cache:false,
    processData:false,
    contentType: 'application/json',
    dataType: 'json',
    success: function(data) {
      $('.saved').show();
      setTimeout(function() {$('.saved').hide(); details(data); }, 1500);
    },
    error: function(data) {
      console.log('Save error');
      console.log(data);
    },
    beforeSend: function (request) { request.setRequestHeader("x-apikey", noddy.apikey); }
  }
  opts.data = JSON.stringify(data);
  $.ajax(opts);
}

var checkemailthensubmit = function(e) {
  if (e) e.preventDefault();
  if ($(this).attr('disabled') === 'true') return false;
  $('.emailissue').html("").hide();
  var tgt = adminsubmitting ? '#admin_email' : '#email';
  if ( $(tgt).length && $(tgt).val() && $(tgt).val().length ) {
    var email = $(tgt).val();
    var opts = {
      type:'GET',
      url: api+'/dnr?validate=true&email=' + encodeURIComponent(email) + '&request=' + rec._id + '&user=' + noddy.user.account._id,
      cache:false,
      contentType: 'application/json',
      dataType: 'json',
      success: function(data) {
        if (data.dnr === false) {
          submit(e);
        } else {
          var issue = 'Sorry, ' + email + ' ';
          if (typeof data.dnr === 'object') {
            issue += 'was added to our block list on ' + data.dnr.created_date.split(' ')[0].split('-').reverse().join('/') + '. We cannot send requests to this email.';
          } else if (data.dnr === 'creator') {
            issue += 'matches the creator of this request, so this cannot be the author email address we should contact.';
          } else if (data.dnr === 'user') {
            issue += "is your email address! We need the author's email. Are you the author? If so, please see below.";
          } else if (data.dnr === 'supporter') {
            issue += 'matches the address of someone who already supports this request. They cannot be a suitable author to contact to request access.';
          } else if (data.dnr === 'invalid') {
            issue += 'is not a valid address.';
            if (data.validation.did_you_mean) issue += ' Did you mean ' + data.validation.did_you_mean + '?';
          } else  if (data.dnr === true) {
            issue += 'is on the blacklist and cannot be used.';
          }
          $(tgt).val("").attr("placeholder",email + " is an unsuitable author email address - please try another");
          $('.emailissue').html(issue).show();
        }
      },
      error: function() {console.log('Check email error, submitting anyway'); submit(e); } // if we can't do the validation for some reason, just submit anyway
    }
    $.ajax(opts);
  } else {
    submit(e);
  }
}

var adminsubmit = function(e) {
  adminsubmitting = true;
  checkemailthensubmit(e);
}

var action = function() {
  var act = $('#action').val();
  if (act) {
    if ($('#adminframe').length) $('#adminframe').hide();
    if (runrequest) {
      $('#admin').hide();
      $('#admin').after('<p style="color:orange;">Working on it, please wait a few seconds for the page to update...</p>');
    }
    $.ajax({
      type:'GET',
      url:api+'/request/' + rec._id + '/admin/' + act,
      beforeSend: function (request) { request.setRequestHeader("x-apikey", noddy.apikey); },
    });
    setTimeout(function() { if (runrequest) { runrequest(); } else { $('#admin').after('<p>Refresh the page to view changes.</p>'); } }, 4000);
  }
}

var deleteitem = function() {
  $.ajax({
    type:'DELETE',
    url:api+'/request/'+rec._id,
    beforeSend: function (request) { request.setRequestHeader("x-apikey", noddy.apikey); },
  });
  $('#admin').html('<p>This request has been deleted. You will be redirected to the requests page.</p>');
  setTimeout(function() { window.location.href = '/request'; }, 2000);
}

var admin = function(record) {
  var dets = '<p style="text-align:right;"><a href="#" id="showadmin" style="color:orange;">Admin</a></p>';
  dets += '<div id="admin" style="display:none;">';
  dets += '<div class="well" style="background-color:orange;">';
  //dets += '<p>Dear admin, please notify when you are moderating in a few clicks at <a href="https://app.timebridge.com/mwm/requests">https://app.timebridge.com/mwm/requests</a></p>';
  if (record.year) dets += '<p>Publication year: ' + record.year + '</p>';
  if (record.sherpa !== undefined) {
    dets += '<p>Sherpa color: ' + (record.sherpa.color === undefined ? 'unknown' : record.sherpa.color) + '</p>';
    try { dets += '<p><a class="btn btn-block btn-action" target="_blank" href="http://www.sherpa.ac.uk/romeo/search.php?issn=' + record.sherpa.journal.issn + '">View journal on Sherpa Romeo</a></p>'; } catch(err) {}
    try {
      dets += '<p>Copyright links:</p>';
      for (var i in record.sherpa.publisher.copyright) {
        dets += '<p><a class="btn btn-action" target="_blank" href="' + record.sherpa.publisher.copyright[i].url + '">' + record.sherpa.publisher.copyright[i].text + '</a></p>';
      }
    } catch(err) {}
    try {
      dets += '<p>Journal conditions:</p>';
      for (var p in record.sherpa.publisher.conditions) {
        dets += '<p>' + record.sherpa.publisher.conditions[p] + '</p>';
      }
    } catch(err) {}

  }
  dets += '<p>Status: <select id="status" class="form-control" style="width:150px;display:inline;">';
  var statuses = ['help','moderate','progress',/*'hold',*/'refused','received','closed'];
  for ( var s in statuses ) {
    dets += '<option value="' + statuses[s] + '"';
    if (record.status === statuses[s]) dets += ' selected="selected"';
    dets += '>' + statuses[s] + '</option>';
  }
  dets += '</select>';
  dets += ' &nbsp;&nbsp;test: <input type="checkbox" id="test"';
  if (record.test === true) dets += ' checked="checked"';
  dets += '>';
  dets += ' &nbsp;&nbsp;Action: <select id="action" class="form-control" style="width:150px;display:inline;">';
  var actions = ['','send_to_author','story_too_bad','not_a_scholarly_article','dead_author','user_testing','broken_link','article_before_2000','author_email_not_found','link_by_author','link_by_admin','successful_upload','reject_upload'];
  if (record.received && record.received.url) actions.push('remove_submitted_url');
  for ( var a in actions ) {
    dets += '<option value="' + actions[a] + '">' + actions[a].replace(/_/g,' ') + '</option>';
  }
  dets += '</select>';
  dets += '</p>';
  if (record.location && record.location.geo && record.location.geo.lat) {
    dets += '<p>Location: ' + record.location.geo.lat + ',' + record.location.geo.lon
    if (record.location.location) dets += ' - ' + record.location.location;
    dets += '</p>';
  }
  dets += '<p>Dear moderator, please click "Save changes" immediately after having filled the form and BEFORE clicking "Send to author".</p>';
  dets += '<p><input type="text" id="name" value="' + (record.name ? record.name : '') + '" placeholder="Author Name" class="form-control"></p>';
  dets += '<p><input type="text" id="author_affiliation" value="' + (record.author_affiliation ? record.author_affiliation : '') + '" placeholder="Author Affiliation" class="form-control"></p>';
  if (record.name) {
    dets += '<p><a target="_blank" href="https://scholar.google.com/citations?view_op=search_authors&hl=en&mauthors=' + record.name.replace(/ /g,'+') + '" class="btn btn-block btn-action">View author Google scholar profile</a></p>';
  }
  if (!record.name && record.author) {
    dets += '<p><a href="#" class="btn btn-block btn-action" id="viewpossibleauthors">View possible author names</a></p>';
    dets += '<div style="display:none;" id="possibleauthors">';
    for ( var a in record.author ) {
      if (record.author[a].family) {
        dets += '<p><a class="selectpossibleauthor" href="#">' + record.author[a].given + ' ' + record.author[a].family + '</a></p>';
      }
    }
    dets += '</div>';
  }
  if (record.email) dets += '<div class="input-group">';
  dets += '<input type="text" id="admin_email" value="' + (record.email ? record.email : '') + '" placeholder="Author Email" class="form-control">';
  if (record.email) dets += '<div class="input-group-btn"><a id="blacklist" href="#" class="btn btn-action">Blacklist</a></div></div>';
  dets += '<p class="emailissue" style="display:none;font-size:0.9em;"></p>';
  dets += '<p style="margin-top:10px;"><input type="text" id="admin_title" class="form-control" placeholder="Title" value="';
  if (record.title) dets += record.title;
  dets += '"></p>';
  dets += '<p style="margin-top:10px;"><input type="text" id="admin_journal" class="form-control" placeholder="Journal" value="';
  if (record.journal) dets += record.journal;
  dets += '"></p>';
  dets += '<p><input type="text" id="admin_doi" class="form-control" placeholder="DOI" value="';
  if (record.doi) dets += record.doi;
  dets += '"></p>';
  
  dets += '<p><input type="text" id="admin_access_right" class="form-control" placeholder="Access right" value="';
  if (record.access_right) dets += record.access_right;
  dets += '"></p>';
  dets += '<p><input type="text" id="admin_embargo_date" class="form-control" placeholder="Embargo date" value="';
  if (record.embargo_date) dets += record.embargo_date;
  dets += '"></p>';
  dets += '<p><input type="text" id="admin_access_conditions" class="form-control" placeholder="Access conditions" value="';
  if (record.access_conditions) dets += record.access_conditions;
  dets += '"></p>';
  dets += '<p><input type="text" id="admin_license" class="form-control" placeholder="License" value="';
  if (record.license) dets += record.license;
  dets += '"></p>';
  dets += '<p><textarea id="admin_received_description" class="form-control" placeholder="Received description">';
  if (record.received && record.received.description) dets += record.received.description;
  dets += '</textarea></p>';

  dets += '<p><textarea id="admin_story" class="form-control" placeholder="Story" style="min-height:100px;">';
  if (record.story) dets += record.story;
  dets += '</textarea></p>';
  dets += '<p>Story rating: <select id="rating" class="form-control" style="width:100px;display:inline;"><option></option>';
  dets += '<option value="0"';
  if (parseInt(record.rating) === 0) dets += ' selected="selected"';
  dets += '>fail</option>';
  dets += '<option value="1"';
  if (parseInt(record.rating) === 1) dets += ' selected="selected"';
  dets += '>pass</option>';
  dets += '</select>';
  dets += '<a class="btn btn-danger pull-right" id="delete" href="#">DELETE</a></p>';
  dets += '<p><input type="submit" id="submitchanges" value="Save changes before sending to author or any other action" class="btn btn-action btn-block"></p>';
  dets += '<p class="saved" style="display:none;">Changes saved, refreshing page.</p>';
  dets += '<p style="margin-top:20px;">';
  if (window.location.href.indexOf('/response/') === -1) {
    dets += '<a class="btn btn-action" href="/response/' + record.receiver + '">View the response page for this request</a> ';
  } else {
    dets += '<a class="btn btn-action" href="/request/' + record._id + '">View the request page for this response</a> ';
  }
  dets += '<a class="btn btn-action pull-right" href="/admin?request=' + record._id + '">Send email via admin UI about this request</a></p>';
  dets += '<p><textarea id="admin_notes" class="form-control" placeholder="Admin notes" style="min-height:200px;">';
  if (record.notes) dets += record.notes;
  dets += '</textarea></p>';
  dets += '</div>';
  dets += '<div id="history"></div>';
  dets += '</div>';
  
  $('body').on('click','#showadmin',function(e) { e.preventDefault(); $('#admin').toggle(); if ($('#adminframe').length) { $('#adminframe').toggle(); } });
  $('body').on('click','#submitchanges',adminsubmit);
  $('body').on('click','#blacklist',blacklist);
  $('body').on('click','#viewpossibleauthors',function(e) { e.preventDefault(); $('#viewpossibleauthors').hide(); $('#possibleauthors').show(); });
  $('body').on('click','.selectpossibleauthor',function(e) { e.preventDefault(); $('#name').val($(this).html()); $('#viewpossibleauthors').show(); $('#possibleauthors').hide(); });
  $('body').on('click','#delete',deleteitem);
  $('body').bind('change','#action',action);
  return dets;
}

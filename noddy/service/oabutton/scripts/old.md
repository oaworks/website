# A log of everything we did in the old API scripts to update and import old requests

## filterold

      var qp = this.queryParams;
      qp.execute = true;
      qp.scrape = true;
      qp.requests = true;
      qp.users = true;
      // and pass in qp scrape to run scrape for email, and qp execute to actually save changes

      var counts = {updated:0,removed:0,requests:0,presentemailremoved:0,scrape:0,newvalidemail:0,users:0,userupdated:0};

      var professions = ['Student','Health professional','Patient','Researcher','Librarian'];
      if (qp.requests) {
        oab_request.find().forEach(function(req) {
          counts.requests += 1;
          if (!req.url || CLapi.internals.service.oab.blacklist(req.url)) {
            counts.removed += 1;
            if (qp.execute) {
              console.log('removing ' + req._id);
              oab_request.remove(req._id);
            }
          } else {
            var update = {};
            if (req.rating) {
              update.rating = parseInt(req.rating) >= 3 ? 1 : 0;
            }
            if (req.user) {
              if (req.user.profession === undefined) {
                update['user.profession'] = 'Other';
              } else if ( professions.indexOf(req.user.profession) === -1 ) {
                if (req.user.profession) {
                  update['user.profession'] = req.user.profession[0].toUpperCase() + req.user.profession.substring(1,req.user.profession.length);
                  if (professions.indexOf(update['user.profession']) === -1) {
                    if (update['user.profession'].toLowerCase() === 'academic') {
                      update['user.profession'] = 'Researcher';
                    } else if (update['user.profession'].toLowerCase() === 'doctor') {
                      update['user.profession'] = 'Health professional';
                    } else {
                      update['user.profession'] = 'Other';
                    }
                  }
                } else {
                  update['user.profession'] = 'Other';
                }
              }
              if (['help','moderate'].indexOf(req.status) !== -1) {
                if ( req.email && ( req.email.indexOf('@') === -1 || req.email.indexOf('.') === -1 || CLapi.internals.service.oab.dnr(req.email) ) ) {
                  counts.presentemailremoved += 1;
                  req.email = undefined;
                  update.email = '';
                }
                if ( !req.email ) {
                  counts.scrape += 1;
                  if (qp.scrape) {
                    try {
                      var s = CLapi.internals.service.oab.scrape(req.url);
                      if ( s.email ) {
                        counts.newvalidemail += 1;
                        update.email = s.email;
                      }
                    } catch(err) {}
                  }
                }
              }
            }
            if (JSON.stringify(update) !== '{}') {
              if (qp.execute) {
                console.log('updating ' + req._id);
                oab_request.update(req._id,{$set:update});
              }
              counts.updated += 1;
            }
          }
        });
      }

      if (qp.users) {
        Meteor.users.find({"roles.openaccessbutton":{$exists:true}}).forEach(function(u) {
          counts.users += 1;
          if (u && u.service && u.service.openaccessbutton && u.service.openaccessbutton.profile) {
            var uup = {};
            if (!u.service.openaccessbutton.profile.profession) {
              uup['service.openaccessbutton.profile.profession'] = 'Other';
            } else if ( professions.indexOf(u.service.openaccessbutton.profile.profession) === -1 ) {
              uup['service.openaccessbutton.profile.profession'] = u.service.openaccessbutton.profile.profession[0].toUpperCase() + u.service.openaccessbutton.profile.profession.substring(1,u.service.openaccessbutton.profile.profession.length);
              if (professions.indexOf(uup['service.openaccessbutton.profile.profession']) === -1) {
                if (uup['service.openaccessbutton.profile.profession'].toLowerCase() === 'academic') {
                  uup['service.openaccessbutton.profile.profession'] = 'Researcher';
                } else if (uup['service.openaccessbutton.profile.profession'].toLowerCase() === 'doctor') {
                  uup['service.openaccessbutton.profile.profession'] = 'Health professional';
                } else {
                  uup['service.openaccessbutton.profile.profession'] = 'Other';
                }
              }
            }
            if (JSON.stringify(uup) !== '{}') {
              counts.userupdated += 1;
              if (qp.execute) {
                console.log('updating user ' + u._id);
                Meteor.users.update(u._id,{$set:uup});






## fixblocked

// old records have these keys, need a script to clean them up and check for nonsense content:
// [u'last_updated', u'author', u'url', u'created_date', u'api_key', u'id', u'doi', u'journal', u'story', u'authoremails', u'title', u'wishlist']
// [u'last_updated', u'author', u'url', u'created_date', u'api_key', u'id', u'doi', u'journal', u'story', u'authoremails', u'title', u'wishlist', u'emails[2]', u'emails[3]', u'emails[1]', u'emails[0]', u'and
// roid', u'location', u'metadata', u'email', u'emails[4]', u'emails[6]', u'emails[5]', u'emails[7]']
// nonsense could be in the url, or in the story, or possibly by author
// for good ones, author > user, authoremails > email. the rest direct match below, or should be ignored

var fs = Meteor.npmRequire('fs');

var oabinput = '/home/cloo/migrates/oabutton/oab_02022016_2311/blocked.json';
var oabjsonout = '/home/cloo/migrates/oabutton/oab_02022016_2311/blocked_fixed.json';
var oabcsvout = '/home/cloo/migrates/oabutton/oab_02022016_2311/blocked_fixed.csv';

var fixblocked = function() {
  var recs = JSON.parse(fs.readFileSync(oabinput));
  var userlocs = {};
  var recs_keys_fixed = [];
  for ( var i in recs.hits.hits ) {
    var rec = recs.hits.hits[i]._source;
    if (rec.metadata === undefined ) rec.metadata = {};
    rec.type = 'article';
    rec.legacy = {legacy:true};
    if (rec.author) {
      if (typeof rec.author === 'string') {
        rec.user = rec.author;
      } else {
        rec.metadata.author = rec.author;
      }
      delete rec.author;
    }
    if (rec.api_key) delete rec.api_key;
    if (rec.id) {
      rec.legacy.id = rec.id;
      delete rec.id;
    }
    if (rec.wishlist) {
      rec.legacy.wishlist = rec.wishlist;
      delete rec.wishlist;
    }
    if (rec.android) {
      rec.legacy.plugin = 'android';
      delete rec.android;
    }
    if (rec.created_date) {
      rec.legacy.created_date = rec.created_date;
      delete rec.created_date;
    }
    if (rec.last_updated) {
      rec.legacy.last_updated = rec.last_updated;
      delete rec.last_updated;
    }
    if (rec.location && userlocs[rec.user] === undefined ) userlocs[rec.user] = rec.location;
    if (rec.title) {
      rec.metadata.title = rec.title;
      delete rec.title;
    }
    if (rec.journal) {
      rec.metadata.journal = {name: rec.journal};
      delete rec.journal;
    }
    if (rec.doi) {
      rec.metadata.identifier = [{type:'doi',id:rec.doi}];
      delete rec.doi;
    }
    if (rec.metadata && rec.metadata.journal && typeof rec.metadata.journal !== 'object') rec.metadata.journal = {name:rec.metadata.journal};
    if (rec.authoremails !== undefined) {
      if (rec.authoremails) rec.email = rec.authoremails;
      delete rec.authoremails;
    }
    if (rec.email !== undefined && typeof rec.email === 'string') rec.email = [rec.email];
    if (rec.email === undefined) rec.email = [];
    if (rec['emails[0]']) {
      if (rec.email.indexOf(rec['emails[0]']) === -1 ) rec.email.push(rec['emails[0]']);
      delete rec['emails[0]'];
    }
    if (rec['emails[1]']) {
      if (rec.email.indexOf(rec['emails[1]']) === -1 ) rec.email.push(rec['emails[1]']);
      delete rec['emails[1]'];
    }
    if (rec['emails[2]']) {
      if (rec.email.indexOf(rec['emails[2]']) === -1 ) rec.email.push(rec['emails[2]']);
      delete rec['emails[2]'];
    }
    if (rec['emails[3]']) {
      if (rec.email.indexOf(rec['emails[3]']) === -1 ) rec.email.push(rec['emails[3]']);
      delete rec['emails[3]'];
    }
    if (rec['emails[4]']) {
      if (rec.email.indexOf(rec['emails[4]']) === -1 ) rec.email.push(rec['emails[4]']);
      delete rec['emails[4]'];
    }
    if (rec['emails[5]']) {
      if (rec.email.indexOf(rec['emails[5]']) === -1 ) rec.email.push(rec['emails[5]']);
      delete rec['emails[5]'];
    }
    if (rec['emails[6]']) {
      if (rec.email.indexOf(rec['emails[6]']) === -1 ) rec.email.push(rec['emails[6]']);
      delete rec['emails[6]'];
    }
    if (rec['emails[7]']) {
      if (rec.email.indexOf(rec['emails[7]']) === -1 ) rec.email.push(rec['emails[7]']);
      delete rec['emails[7]'];
    }
    if (rec.email) {
      rec.legacy.email = rec.email;
      delete rec.email;
    }
    recs_keys_fixed.push(rec);
  }

  var recs_cleaned = [];
  var tests = 0;
  var nouser = 0;
  var foundlocs = 0;
  for ( var k in recs_keys_fixed ) {
    var rc = recs_keys_fixed[k];
    // fixes the location data if it was missing and we had it for this user from another record
    if (!rc.location && userlocs[rc.user]) {
      rc.location = userlocs[rc.user];
      foundlocs += 1;
    }
    // then set as test if obviously is one
    if ( !rc.user ) {
      rc.test = true;
      tests += 1;
    }
    if ( !rc.url ) {
      rc.test = true;
      tests += 1;
    }
    if ( !rc.story ) rc.story = '';
    if (rc.url) {
      if (rc.url.indexOf('chrome') !== -1 || rc.url.indexOf('openaccessbutton') !== -1 || rc.url.indexOf('about:') !== -1) {
        rc.test = true;
        tests += 1;
      }
    }
    if (rc.user && ( rc.user.toLowerCase().indexOf('admin') !== -1 || rc.user.toLowerCase().indexOf('eardley') !== -1 ) ) {
      rc.test = true;
      tests += 1;
    }
    if (!rc.user) nouser += 1;
    recs_cleaned.push(rc);

  }
  console.log('tests ' + tests + ', found locs ' + foundlocs);
  fs.writeFileSync(oabjsonout,JSON.stringify(recs_cleaned,"","  "));
  fs.writeFileSync(oabcsvout,'"user","url","story","test"\n');
  var recordcount = 0;
  for ( var ln in recs_cleaned ) {
    recordcount += 1;
    var tf = recs_cleaned[ln];
    var url = tf.url ? tf.url.replace('"','') : "";
    var story = tf.story ? tf.story.replace('"','').replace('\n','') : "";
    var line = '"' + tf.user + '","' + url + '","' + story + '","';
    if (tf.test) line += 'true';
    line += '"\n';
    fs.appendFileSync(oabcsvout,line);
  }

  return {records: recordcount, tests: tests, located: foundlocs, nouser: nouser};
}




## fixlegacydates

      var counts = {count:0,fixed:0};
      var moment = Meteor.npmRequire('moment');
      var requests = oab_request.find().fetch();
      counts.count = requests.length;
      for ( var r in requests ) {
        var fix = {};
        var res = requests[r];
        if (res.legacy && res.legacy.created_date) {
          counts.fixed += 1;
          res.createdAt = moment(res.legacy.created_date,"YYYY-MM-DD HHmm").valueOf();
          fix.createdAt = res.createdAt;
        }
        fix.created_date = moment(res.createdAt,"x").format("YYYY-MM-DD HHmm");
        if (res.updatedAt) fix.updated_date = moment(res.updatedAt,"x").format("YYYY-MM-DD HHmm");

        oab_request.update(res._id,{$set:fix});




## importold

var getoldblocked = function() {
  var recs = Meteor.http.call('GET','http://oabutton.cottagelabs.com/query/blocked/_search?q=*&size=10000').data;
  //var urlemails = {};
  var userlocs = {};
  var recs_keys_fixed = [];
  for ( var i in recs.hits.hits ) {
    var rec = recs.hits.hits[i]._source;
    if (rec.metadata === undefined ) rec.metadata = {};
    rec.type = 'article';
    rec.legacy = {legacy:true};
    if (rec.author) {
      if (typeof rec.author === 'string') {
        rec.user = rec.author;
      } else {
        rec.metadata.author = [];
        for ( var a in rec.author ) {
          rec.metadata.author.push({name:rec.author[a]});
        }
      }
      delete rec.author;
    }
    if (rec.api_key) delete rec.api_key;
    if (rec.id) {
      rec.legacy.id = rec.id;
      delete rec.id;
    }
    if (rec.wishlist) {
      rec.legacy.wishlist = rec.wishlist;
      delete rec.wishlist;
    }
    if (rec.android) {
      rec.legacy.plugin = 'android';
      delete rec.android;
    }
    if (rec.created_date) {
      rec.legacy.created_date = rec.created_date;
      delete rec.created_date;
    }
    if (rec.last_updated) {
      rec.legacy.last_updated = rec.last_updated;
      delete rec.last_updated;
    }
    if (rec.location && rec.user && userlocs[rec.user] === undefined ) userlocs[rec.user] = rec.location;
    if (rec.title) {
      rec.metadata.title = rec.title;
      delete rec.title;
    }
    if (rec.journal) {
      rec.metadata.journal = {name: rec.journal};
      delete rec.journal;
    }
    if (rec.doi) {
      rec.metadata.identifier = [{type:'doi',id:rec.doi}];
      delete rec.doi;
    }
    if (rec.metadata && rec.metadata.journal && typeof rec.metadata.journal !== 'object') rec.metadata.journal = {name:rec.metadata.journal};
    if (rec.authoremails !== undefined) {
      if (rec.authoremails) rec.email = rec.authoremails;
      delete rec.authoremails;
    }
    if (rec.email !== undefined && typeof rec.email === 'string') rec.email = [rec.email];
    if (rec.email === undefined) rec.email = [];
    if (rec['emails[0]']) { - up to 4
      if (rec.email.indexOf(rec['emails[0]']) === -1 ) rec.email.push(rec['emails[0]']);
      delete rec['emails[0]'];
    }
    if (rec['emails[5]']) delete rec['emails[5]']; - up to 30
    if (rec.email) {
      rec.legacy.email = rec.email;
      delete rec.email;
    }
    //if (rec.url && rec.legacy.email && rec.legacy.email.length > 0) urlemails[rec.url] = rec.legacy.email;
    if (rec.url) {
      if (rec.url.indexOf('chrome') === -1 && rec.url.indexOf('openaccessbutton') === -1 && rec.url.indexOf('about:') === -1) {
        if ( (rec.user && rec.user.toLowerCase().indexOf('admin') === -1 && rec.user.toLowerCase().indexOf('eardley') === -1) || !rec.user ) {
          recs_keys_fixed.push(rec);
        }
      }
    }
  }
  return {total: recs_keys_fixed.length, records: recs_keys_fixed, started: recs.hits.hits.length, locations: userlocs}; //, urlemails: urlemails};
}


var getreallyoldblocked = function() {
  var oabinput = '/home/cloo/migrates/oabutton/oabold/oaevent_old_system_blocked.csv';
  var fs = Meteor.npmRequire('fs');
  var inp = fs.readFileSync(oabinput).toString();
  var recs = CLapi.internals.convert.csv2json(undefined,inp);
  var userlocs = {};
  var records = [];
  for ( var i in recs ) {
    var rec = recs[i];
    rec.type = 'article';
    rec.legacy = {legacy:true};
    if (rec.id !== undefined) {
      rec.legacy.id = rec.id;
      delete rec.id;
    }
    if (rec.metadata === undefined) rec.metadata = {};
    if (rec.story === undefined) rec.story = '';
    if (rec.doi) {
      rec.metadata.identifier = [{type:'doi',id:rec.doi}];
      delete rec.doi;
    }
    if (rec.doi) {
      rec.legacy.email = rec.authoremails;
      delete rec.authoremails;
    }
    if ( rec.user_slug ) {
      rec.user = rec.user_slug;
      delete rec.user_slug;
    }
    if ( rec.accessed ) {
      rec.legacy.created_date = rec.accessed;
      delete rec.accessed;
    }
    if (rec.location) {
      rec.location = {location: rec.location, geo: {}}
    } else {
      rec.location = {geo:{}};
    }
    if ( rec.coords_lat ) {
      rec.location.geo.lat = rec.coords_lat;
      delete rec.coords_lat;
    }
    if ( rec.coords_lng ) {
      rec.location.geo.lon = rec.coords_lng;
      delete rec.coords_lng;
    }
    if (rec.location.geo.lon && rec.user && userlocs[rec.user] === undefined ) userlocs[rec.user] = rec.location;
    if ( rec.description ) {
      var parts = rec.description.split('\r\n');
      rec.metadata.title = parts[0].replace('Title: ','');
      try {
        var authors = parts[1].split(',');
        rec.metadata.author = [];
        for ( var a in authors ) {
          rec.metadata.author.push({name: authors[a]});
        }
      } catch (err) {}
      try {rec.metadata.journal = {name: parts[2].replace('Journal: ','')}; } catch (err) {}
      delete rec.description;
    }
    if (rec.user_name) {
      rec.legacy.username = rec.user_name;
      delete rec.user_name;
    }
    if (rec.user_profession) {
      rec.legacy.user_profession = rec.user_profession;
      delete rec.user_profession;
    }
    if (rec.user_email) {
      rec.legacy.user_email = rec.user_email;
      delete rec.user_email;
    }
    if (rec.url) {
      if (rec.url.indexOf('chrome') === -1 && rec.url.indexOf('openaccessbutton') === -1 && rec.url.indexOf('about:') === -1) {
        if ( (rec.user && rec.user.toLowerCase().indexOf('admin') === -1 && rec.user.toLowerCase().indexOf('eardley') === -1) || !rec.user ) {
          records.push(rec);
        }
      }
    }
  }
  return {total: records.length, records: records, started: recs.length, locations: userlocs};
}

var run = function(save) {
  var chuck = OAB_Blocked.find({"legacy.legacy":true});
  var woodchuck = 0;
  chuck.forEach(function(c) {
    woodchuck += 1;
    if (save) OAB_Blocked.remove(c._id);
  });
  var blocks = [];
  var locations = {};
  var old = getoldblocked();
  //var urlemails = old.urlemails;
  for ( var i in old.records ) blocks.push(old.records[i]);
  for ( var l in old.locations ) locations[l] = old.locations[l];
  var oldold = getreallyoldblocked();
  for ( var ii in oldold.records ) blocks.push(oldold.records[ii]);
  for ( var ll in oldold.locations ) {
    if (locations[ll] === undefined) locations[ll] = oldold.locations[ll];
  }
  // call live system db for a list of more location data by user
  var livelocs = OAB_Blocked.find({}).fetch();
  for ( var lo in livelocs ) {
    var bl = livelocs[lo];
    if (bl.location && bl.username) {
      var tl = bl.location;
      if (tl.geo) {
        if (tl.geo.lat) {
          if (typeof tl.geo.lat === 'string') tl.geo.lat = parseInt(tl.geo.lat);
        }
        if (tl.geo.lon) {
          if (typeof tl.geo.lon === 'string') tl.geo.lon = parseInt(tl.geo.lon);
        }
      }
      locations[bl.username] = tl;
    }
  }
  var clean = 0;
  var foundlocs = 0;
  var newblocks = 0;
  for ( var b in blocks ) {
    var block = blocks[b];
    if ( ( block.location === undefined || block.location.geo === undefined || !block.location.geo.lat ) && locations[block.user] !== undefined) {
      block.location = locations[block.user];
      foundlocs += 1;
    }
    if (block.location && block.location.geo && (!block.location.geo.lat || !block.location.geo.lon) ) delete block.location;
    if (save) OAB_Blocked.insert(block);
  }
  // call a function to get the old wishlist records - for each try to make it meet current request format
  // and match with a urlemail and a current user - if possible, save it as a request
  return {woodchuck:woodchuck, blocks: blocks.length, located: foundlocs, oldstart: old.started, oldtotal: old.total, oldoldstart: oldold.started, oldoldtotal: oldold.total}
}




## importratings

Read ratings from /home/cloo/oabutton_ratings.csv (which came from the google sheet)
If the rating row has a story of at least 3 characters, and the rating field has a parseable
number in it, add the rating to the request record(s) IF one(any) could be find by a story match



## makeaccs

Read /home/cloo/oab_accounts_19052016.json
Look for users matching the email address of all accounts in that file
If no user in system, make a new one with a openaccessbutton service object showing signup:legacy and oldid
If user did exist but was not an OAB user, add hadaccount:already to an oab service object, as above, and add the user to the oab group
Otherwise if account was already there just add odbpreoab:true to the oab service object



## oldblocked

Read csv records from the old old system, and prep them for the new system in a csv dump file
Old ones had keys: 'story', 'doi', 'user_slug', 'description', 'url', 'coords_lng', 'coords_lat', 'location', 'accessed', 'user_name', 'id', 'user_email', 'user_profession'
Imported from:
var oabinput = '/home/cloo/migrates/oabutton/oabold/oaevent_old_system_blocked.csv'
var oabjsonout = '/home/cloo/migrates/oabutton/oabold/blocked.json'
var oabcsvout = '/home/cloo/migrates/oabutton/oabold/blocked.csv'

Added legacy object, with legacy:true value
Removed old IDs, and altered old name/format keys to new
Old user_name, user_profession, and user_email fields may still be in new records



## rename

For each request, look up the user and add the user username and firstname to the request user object if not already known



## reprocess

Get all users and move details into the profile object (this moved users into meteor format)
For all availabilities that did not find anything, check again, if found, update the availability to show discovered
For all requests in old system, if not already a request in new system, create it. If already in new system, add a support record for it

For all old blocked records, create a new request object, and add a legacy key, and set oab_odb_integration to true
If there was no user for the block record, do nothing with the new request object (which lost about 3000 records)
If there was a user, look for a current user account that matches. If no user found, abandon the request
Look for a request same as this already in new system, if not found, create the new request, otherwise create a support



## usernames

Read users from a file called /home/cloo/userdata.csv
And tried to set profile firstnames and lastnames where it was possible
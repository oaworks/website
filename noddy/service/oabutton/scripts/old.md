# A log of everything we did in the old API scripts to update and import old requests

## latest fix

Update from Joe - if there are old requests that have no story, that is OK - import them.
But if they DO have a story, and ARE rated as bad in the story ratings sheet, don't include them. 
Don't import duplicate requests for the same URL - so check that.
If a request does not have a matching user in the current system, still import it by set to anon.

We know there are missing records, which disappeared during a previous update - 
probably when an update from blocks to requests only allowed to keep requests 
we could find a matching user for.

But we have an old blog post that links to 10 
records, all of which should still be relevant, but only 1 of which is in the current 
system - see the issue:

https://github.com/OAButton/discussion/issues/966

In a backup of 18420 old records we do still have all of these requests, with some 
user data, in an older format that does have a legacy object but also still has 
a metadata object, which we no longer use. 17207 have metadata, 15614 have legacy. 
Some of these records could already still be in the current system though.

Also, there are some duplicates in the backup, in the sense that it was a time when there 
was possibly more than one request per URL. We would have filtered that down to just 
the one copy, and counted the others as support counts, but even so, there seems to be 
some missing from the current live data. So, will have to go through the backup 
records, import them to live data where suitable, but also check for dups in the 
live data and in the backup itself, and decide which story to select if there is 
more than one.

So first, check which ones are not in the current system.

Some of these old records do have location data in them. But keep that if present for now. 
A later script can be executed to remove all location data from all records, once this issue 
is fixed.

The keys present in the backup records are:
[u'username', u'profession', u'user', u'user_email', u'url', u'updatedAt', u'createdAt', u'plugin', u'_id', u'type', u'metadata', 
u'story', u'request', u'location', u'status', u'receiver', u'email', u'legacy', u'doi', u'title', 
u'description', u'coords_lng', u'coords_lat', u'test', u'received', u'hold', u'holds', u'count', u'refused']
But received, hold, holds, count, and refused are not present in any that are not tests, so can ignore those.
These keys are present in metadata objects: [u'journal', u'identifier', u'author', u'title', u'url', u'email']
But email is only present once, and is an empty list, so ignore that.
When journal is present it should be an object with "name". But some of them are invalid. 
Throw any that start with "by " or that are "info" or that contain \t or \x, and ignore empty ones, 
and strip whitespace from them all, as some have a lot of leading whitespace. Set suitable 
journal names into rec.journal.
If title is present and has length, set it into rec.title.
If identifier is in metadata, and is a list, and has type:doi, and has id (which it may not) with a value, 
save it to rec.doi.
For authors, if existing, should be a list, and if contains anything, should be objects, each with "name". 
If that is present, check if the name does not have any \x or \u in it. If not, for each one, push the 
author object up to a rec.author list (which will need created if not existing yet).
There is only one url in metadata, and it is a test one, so ignore it.
Description is always empty so delete it.

There are only 9 requests that have the "request" key and are also not either test:true or type:data. 
None of them have good stories, and can be supposed to be duplicates, so if this key is present, 
just skip them.

There are only 9801 of these records that have the story key, and only 6541 where story has a length.

Fix the user data into a proper user object - username, profession, user, user_email
15270 records have a user key. And the amount comes out the same if looking for ones with user_email or username... so only check on the user key
user can be user ID string, or user email string, or username string, or firstname and lastname string (which may have been username at the time) all of which could be from old systems, even the IDs include old and new ID types
user can also sometimes be an object, which looks like the correct current user object e.g. {username: 'BROKI', id: FYrNkyKwkgGXHMaJQ, email: 'diegobroki@hotmail.com'}
but even this should have more info in it if a modern user
modern user object should now have keys id, username, email, affiliation, profession

Will it be necessary to check if all others are URL duplicates of ones already in the system though?

import fs from 'fs'

updates = []
recs = JSON.parse(fs.readFileSync('/home/cloo/backups/oabutton_full_old_old_05032018.json'))
for rec in recs.hits.hits:
  rec = rec._source
  rec.type ?= 'article'
  if rec.type is 'article' and not rec.request? and rec.test isnt true and rec.story and not oab_request.get(rec._id)?
    continue = true
    if rec.email? # what to do if we don't have an email? save it anyway? try to scrape it?
      if rec.email is None
        delete rec.email
      else if rec.email.indexOf('cottagelabs.com') is -1 and rec.email.indexOf('joe@') is -1 and rec.email.indexOf('natalianorori') is -1 and rec.email.indexOf('n/a') is -1 and rec.email.indexOf('None') is -1
        continue = true
      else
        continue = false
    # should we check against the story ratings list?
    # check by the url to see if there is already a matching record in the system or in these backup records?
    if continue
      rec.legacy ?= {}
      rec.legacy.blog_issue_reload = true
      if rec.metadata?
        if rec.metadata.journal?.name?
          if typeof rec.metadata.journal.name is 'string' and rec.metadata.journal.name.length > 1 and rec.metadata.journal.name.indexOf('\t') is -1 and rec.metadata.journal.name.indexOf('\u') is -1 and rec.metadata.journal.name.indexOf('\x') is -1 and rec.metadata.journal.name.indexOf('by ') isnt 0 and rec.metadata.journal.name.indexOf('info') isnt 0
            rec.journal ?= rec.metadata.journal.name.trim()
        if rec.metadata.title? and rec.metadata.title.length > 1
          rec.title ?= rec.metadata.title
        if rec.metadata.identifier? and rec.metadata.identifier.length > 0 and rec.metadata.identifier[0].type? and rec.metadata.identifier[0].type.toLowerCase() is 'doi' and rec.metadata.identifier[0].id?
          rec.doi = rec.metadata.identifier[0].id
        if rec.metadata.author?
          for author in rec.metadata.author
            if author.name? and author.name.indexOf('\x') is -1 and author.name.indexOf('\u') is -1
              rec.author ?= []
              rec.author.push author
        delete rec.metadata
        delete rec.description if rec.description?
        if rec.coords_lat
          rec.location ?= {}
          rec.location.geo ?= {}
          rec.location.geo.lat = rec.coords_lat
          delete rec.coords_lat
        if rec.coords_lng
          rec.location ?= {}
          rec.location.geo ?= {}
          rec.location.geo.lon = rec.coords_lng
          delete rec.coords_lng
        rec.created_date = moment(rec.createdAt, "x").format("YYYY-MM-DD HHmm.ss") if not rec.created_date?
        if rec.user?
          if typeof rec.user is 'string'
            uid = rec.user
            rec.user = {}
          else
            uid = rec.user.id
          user = API.accounts.retrieve uid
          if not user?
            # do we abandon old records with no current user? that is what we did before
          else
            rec.user.email ?= user.emails[0].address
            rec.user.username ?= user.profile?.firstname ? user.username ? user.emails[0].address
            rec.user.firstname ?= user.profile?.firstname
            rec.user.lastname ?= user.profile?.lastname
            rec.user.affiliation ?= user.service?.openaccessbutton?.profile?.affiliation
            rec.user.profession ?= user.service?.openaccessbutton?.profile?.profession
        updates.push rec

# oab_request.import(updates) if updates.length > 0



## filterold

For every request in oab_request, if no URL or URL on blacklist, just delete the 
request from the index. Otherwise update rating to be 1 if rating >= 3, else 0.
If request has user, but no profession, set profession to Other. If it does have 
profession, update it to start with uppercase and the rest lowercase. if it was 
academic change it to Researcher. If doctor change to Health professional. If it 
was not one of ['Student','Health professional','Patient','Researcher','Librarian'] 
set it to Other. If status is help or moderate and email is invalid, remove the email. 
If there is no email, scrape the URL and try to find one. 

For every user in Meteor.users who has roles.openaccessbutton, if user has 
service.openaccessbutton.profile, but it does not contain profession, add profession 
in the same way as above, or if profession exists, modify it as above.



## fixblocked

Go through all old blocked records from 
/home/cloo/migrates/oabutton/oab_02022016_2311/blocked.json

Create rec.metadata object if not existing. Set type as article. Create legacy 
as {legacy: true}. If rec.author, if it is string, set rec.user to it, otherwise 
set rec.metadata.author to it, then delete rec.author. Delete rec.api_key if present. 
If rec.id, set it into rec.legacy.id then delete it. Same with wishlist. If 
rec.android, set rec.legacy.plugin as android, then delete. If created_date and/or 
last_updated, move them into rec.legacy. If rec.location, save it into a user 
locations object. Move rec.title into rec.metadata, if journal move into rec.metadata 
as {name: rec.journal}, if doi move it in as [{type:'doi',id:rec.doi}]. Make sure 
any rec.metadata.journal is an object and not a string. If rec.authoremails move it 
into rec.email. If it is a string, make it a list. For any rec[emails[0]] up to 7, push 
them into rec.email if not already in there (see below how this problem arose from an 
old wrong plugin). Now, move rec.email to rec.legacy.email.

Now for all the recs that had any of the fixes done above, go through them all again. If 
they are missing location, but do have user, and user location is known, put in the user 
location as rec.location. If record does not have user, or not URL, set test:true. If 
story does not exist, set as ''. If URL, if contains chrome or openaccessbutton or about: 
set test:true. If user contains admin or eardley, set test:true. Write all these recs to 
blocked_fixed.json and .csv.



## fixlegacydates

For every request in oab_request, if it has legacy.created_date, add it as createdAt
via moment(res.legacy.created_date,"YYYY-MM-DD HHmm").valueOf() to the main record. 
Then set created_date as moment(res.createdAt,"x").format("YYYY-MM-DD HHmm") and if 
the record has updatedAt, alter it as moment(res.updatedAt,"x").format("YYYY-MM-DD HHmm"). 
Then save the record back into oab_request.



## importold

Go through old blocked (what used to be requests) by querying them from the blocked index.
In each record add a "legacy" key and give it a content of legacy:true. Add a metadata key if 
not present, pointing to an empty object. If record has author and author is string, set user 
to author, else if not string, create rec.metadata.author as a list and for each author push 
{name:author} into rec.metadata.author. Then delete rec.author. Delete rec.api_key if present.
If rec.id exists, put it into rec.legacy.id then delete rec.id. Same with wishlist, created_date, 
last_updated. If rec.android, put it in rec.legacy.plugin and delete. If rec.location and rec.user, 
make an object of user locations separate to all records, and push rec.location of this user into 
user locations object, keyed by rec.user (the user id). For rec.title, journal, move to rec.metadata. 
If rec.metadata.journal is a string change it to {name: rec.metadata.journal}. Move rec.doi into 
rec.metadata.identifier as {type:'doi',id:rec.doi}. If rec.authoremails, move it to rec.email, and make 
sure it is a list. If no authoremails, create rec.email as an empty list. Then tidy up any accidentally 
existing extra emails, which would have looked like keys like rec['emails[0]'] - the index got sent as 
part of the key name, by an old version of the plugin. So if these existed, they would all get pushed 
into rec.email then deleted. rec.email then got moved into rec.legacy.email. If rec.url, and if doesn't contain 
chrome, openaccessbutton, about:, and does have rec.user but does not contain admin or eardley, or does not 
have rec.user at all, push it into a list of fixed recs.

Then go through really old blocked records, which were extracted from 
/home/cloo/migrates/oabutton/oabold/oaevent_old_system_blocked.csv. For each, set type as article, create 
the legacy object with legacy:true, move rec.id if exists into legacy. Create rec.metadata object if not existing.
Set rec.story to '' if not existing. Move rec.doi to rec.metadata as identifier. Move rec.authoremails to rec.legacy.email. 
Move rec.user_slug to rec.user. Move rec.accessed to rec.legacy.created_date. If rec.location, change to 
{location: rec.location, geo: {}}, else set rec.location to {geo:{}}. If rec.coords_lat, push into 
rec.location.geo.lat. Same with rec.coords_lng, but into rec.location.geo.lon. If found a geo.lon and 
have rec.user, and that user location is not in the user locations object, store it in there. 
If rec.description, split it at newline and use the first line as rec.metadata.title. Try splitting 
second line at , into rec.metadata.author. And next line into rec.metadata.journal. Then 
delete rec.description. Move rec.user_name into rec.legacy.username. Same with user_profession and user_email.
If the rec has a url meeting the same standards as above, push it into a list of fixed records.

Now, searched OAB_Blocked for any legacy.legacy: true records. Remove them all. 
Then get all the blocks from the above two paras, and the locations, then go through 
all the block records that were in the system at the time, and if they contained 
a location for a user in the user locations object, use that latest location from 
the block records at the time the script was run. For every block record, add a location 
to it from the users list if it did not already have a location and if we have a location 
for that user in the users location list. Then save the blocked object back to OAB_Blocked.



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
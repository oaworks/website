
import { Random } from 'meteor/random'

###
to create a request the url and type are required, What about story?
{
  url: "url of item request is about",
  type: "article OR data (OR code eventually and possibly other things)",
  story: "the story of why this request / support, if supplied",
  email: "email address of person to contact to request",
  count: "the count of how many people support this request",
  createdAt: "date request was created",
  status: "help OR moderate OR progress OR hold OR refused OR received",
  receiver: "unique ID that the receive endpoint will use to accept one-time submission of content",
  title: "article title",
  doi: "article doi",
  user: {
    id: "user ID of user who created request",
    username: "username of user who created request",
    email: "email of user who created request"
  },
  followup: [
    {
      date: "date of followup",
      email:"email of this request at time of followup"
    }
  ],
  hold: {
    from: "date it was put on hold",
    until: "date until it is on hold to",
    by: "email of who put it on hold"
  },
  holds: [
    {"history": "of hold items, as above"}
  ],
  refused: [
    {
      email: "email address of author who refused to provide content (adding themselves to dnr is implicit refusal too)",
      date: "date the author refused"
    }
  ],
  received: {
    date: "date the item was received",
    from: "email of who it was received from",
    description: "description of provided content, if available".
    url: "url to where it is (remote if provided, or on our system if uploaded)"
  }
}
###
API.service.oab.request = (req,uacc,fast) ->
  dom
  if req.dom
    dom = req.dom
    delete req.dom
  return false if JSON.stringify(req).indexOf('<script') isnt -1
  req.type ?= 'article'
  if req.url? and req.url.indexOf('eu.alma.exlibrisgroup.com') isnt -1
    req.url += (if req.url.indexOf('?') is -1 then '?' else '&') + 'oabLibris=' + Random.id()
    if req.title? and texist = oab_request.find {title:req.title,type:req.type}
      texist.cache = true
      return texist
  else if exists = oab_request.find {url:req.url,type:req.type}
    exists.cache = true
    return exists
  return false if not req.test and API.service.oab.blacklist req.url
  rid = if req._id and oab_request.get(req._id) then req._id else oab_request.insert {url:req.url,type:req.type,_id:req._id}
  user = if uacc then (if typeof uacc is 'string' then API.accounts.retrieve(uacc) else uacc) else undefined
  if not req.user? and user and req.story
    un = user.profile?.firstname ? user.username ? user.emails[0].address
    req.user =
      id: user._id
      username: un
      email: user.emails[0].address
      firstname: user.profile?.firstname
      lastname: user.profile?.lastname
      affiliation: user.service?.openaccessbutton?.profile?.affiliation
      profession: user.service?.openaccessbutton?.profile?.profession
  req.count = if req.story then 1 else 0

  if not fast and (not req.title or not req.email)
    meta = API.service.oab.scrape req.url, dom, req.doi
    if meta?.email?
      for e in meta.email
        isauthor = false
        if meta?.author?
          for a in meta.author
            isauthor = a.family and e.toLowerCase().indexOf(a.family.toLowerCase()) isnt -1
        if isauthor and not API.service.oab.dnr(e) and API.mail.validate(e, API.settings.service?.openaccessbutton?.mail?.pubkey).is_valid
          req.email = e
          break
    req.keywords ?= meta?.keywords ? []
    req.title ?= meta?.title ? ''
    req.doi ?= meta?.doi ? ''
    req.author = meta?.author ? []
    req.journal = meta?.journal ? ''
    req.issn = meta?.issn ? ''
    req.publisher = meta?.publisher ? ''

  req.status = if not req.story or not req.title or not req.email or not req.user? then "help" else "moderate"

  if req.location?.geo
    req.location.geo.lat = Math.round(req.location.geo.lat*1000)/1000 if req.location.geo.lat
    req.location.geo.lon = Math.round(req.location.geo.lon*1000)/1000 if req.location.geo.lon

  req.doi = decodeURIComponent(req.doi) if req.doi
  req.receiver = Random.id()
  req._id = rid
  oab_request.update rid, req
  if req.story
    API.mail.send {
      service: 'openaccessbutton',
      from: 'requests@openaccessbutton.org',
      to: API.settings.service.openaccessbutton.notify.request,
      subject: 'New request created ' + req._id,
      text: (if API.settings.dev then 'https://dev.openaccessbutton.org/request/' else 'https://openaccessbutton.org/request/') + req._id
    }
  return req

API.service.oab.support = (rid,story,uacc) ->
  return false if story and story.indexOf('<script') isnt -1
  r = oab_request.get rid
  if not uacc?
    anons = {url:r.url,rid:r._id,type:r.type,username:'anonymous',story:story}
    anons._id = oab_support.insert anons
    return anons
  else if ((typeof uacc is 'string' and r.user?.id isnt uacc) or r.user?.id isnt uacc?._id ) && not API.service.oab.supports(rid,uacc)?
    oab_request.update rid, {count:r.count + 1}
    user = API.accounts.retrieve(uacc) if typeof uacc is 'string'
    s = {url:r.url,rid:r._id,type:r.type,uid:user._id,username:user.username,email:user.emails[0].address,story:story}
    s.firstname = user.profile?.firstname
    s.lastname = user.profile?.lastname
    s._id = oab_support.insert s
    return s

API.service.oab.supports = (rid,uacc,url) ->
  uacc = uacc._id if typeof uacc is 'object'
  matcher = {}
  if rid and uacc
    matcher = {uid:uacc,rid:rid}
  else if rid
    matcher.rid = rid
  else if uacc and url
    matcher = {uid:uacc,url:url}
  else if uacc
    matcher.uid = uacc
  return oab_support.find matcher

API.service.oab.hold = (rid,days) ->
  today = new Date().getTime()
  date = (Math.floor(today/1000) + (days*86400)) * 1000
  r = oab_request.get rid
  r.holds ?= []
  r.holds.push(r.hold) if r.hold
  r.hold = {from:today,until:date}
  r.status = 'hold'
  oab_request.update rid,{hold:r.hold, holds:r.holds, status:r.status}
  #API.mail.send(); # inform requestee that their request is on hold
  return r

API.service.oab.refuse = (rid,reason) ->
  today = new Date().getTime()
  r = oab_request.get rid
  r.holds ?= []
  r.holds.push(r.hold) if r.hold
  delete r.hold
  r.refused ?= []
  r.refused.push({date:today,email:r.email,reason:reason})
  r.status = 'refused'
  delete r.email
  oab_request.update rid, {hold:'$DELETE',email:'$DELETE',holds:r.holds,refused:r.refused,status:r.status}
  #API.mail.send(); # inform requestee that their request has been refused
  return r

# so far automatic follow up has never been used - it should probably connect to admin rather than emailing directly
# keep this here for now though
API.service.oab.followup = (rid) ->
  MAXEMAILFOLLOWUP = 5 # how many followups to one email address will we do before giving up, and can the followup count be reset or overrided somehow?
  r = oab_request.get rid
  r.followup ?= []
  thisfollows = 0
  for i in r.followup
    thisfollows += 1 if i.email is r.email
  today = new Date().getTime()
  dnr = oab_dnr.find {email:r.email}
  if dnr
    return {status:'error', data:'The email address for this request has been placed on the do-not-request list, and can no longer be contacted'}
  else if r.hold?.until > today
    return {status:'error', data:'This request is currently on hold, so cannot be followed up yet.'}
  else if thisfollows >= MAXEMAILFOLLOWUP
    return {status:'error', data:'This request has already been followed up the maximum number of times.'}
  else
    #API.mail.send() #email the request email contact with the followup request
    r.followup.push {date:today,email:r.email}
    oab_request.update r._id, {followup:r.followup,status:'progress'}
    return r

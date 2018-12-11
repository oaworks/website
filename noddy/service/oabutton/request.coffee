

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
  status: "help OR moderate OR progress OR hold OR refused OR received OR closed",
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
  req.doi = req.url if not req.doi? and req.url? and req.url.indexOf('10.') isnt -1 and req.url.split('10.')[1].indexOf('/') isnt -1
  req.doi = '10.' + req.doi.split('10.')[1] if req.doi? and req.doi.indexOf('10.') isnt 0
  if req.url? and req.url.indexOf('eu.alma.exlibrisgroup.com') isnt -1
    req.url += (if req.url.indexOf('?') is -1 then '?' else '&') + 'oabLibris=' + Random.id()
    if req.title? and typeof req.title is 'string' and req.title.length > 0 and texist = oab_request.find {title:req.title,type:req.type}
      texist.cache = true
      return texist
  else if exists = oab_request.find {url:req.url,type:req.type}
    exists.cache = true
    return exists
  return false if not req.test and API.service.oab.blacklist req.url
  req.doi = decodeURIComponent(req.doi) if req.doi
  rid = if req._id and oab_request.get(req._id) then req._id else oab_request.insert {url:req.url,type:req.type,_id:req._id}
  user = if uacc then (if typeof uacc is 'string' then API.accounts.retrieve(uacc) else uacc) else undefined
  send_confirmation = false
  if not req.user? and user and req.story
    send_confirmation = true
    un = user.profile?.firstname ? user.username ? user.emails[0].address
    req.user =
      id: user._id
      username: un
      email: user.emails[0].address
      firstname: user.profile?.firstname
      lastname: user.profile?.lastname
      affiliation: user.service?.openaccessbutton?.profile?.affiliation
      profession: user.service?.openaccessbutton?.profile?.profession
  req.count ?= if req.story then 1 else 0

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
          if req.author
            for author in req.author
              try
                if req.email.toLowerCase().indexOf(author.family) isnt -1
                  req.author_affiliation = author.affiliation[0].name
                  break
          break
    else if req.author and not req.author_affiliation
      try
        req.author_affiliation = req.author[0].affiliation[0].name # first on the crossref list is the first author so we assume that is the author to contact
    req.keywords ?= meta?.keywords ? []
    req.title ?= meta?.title ? ''
    req.doi ?= meta?.doi ? ''
    req.author = meta?.author ? []
    req.journal = meta?.journal ? ''
    req.issn = meta?.issn ? ''
    req.publisher = meta?.publisher ? ''
    req.year = meta?.year
    if not req.email and req.author_affiliation
      try
        for author in req.author
          if author.affiliation[0].name is req.author_affiliation
            # it would be possible to lookup ORCID here if the author has one in the crossref data, but that would only get us an email for people who make it public
            # previous analysis showed that this is rare. So not doing it yet
            email = API.use.hunter.email {company: req.author_affiliation, first_name: author.family, last_name: author.given}, API.settings.service.openaccessbutton.hunter.api_key
            if email?.email?
              req.email = email.email
              break

  if fast and req.doi and (not req.journal or not req.year or not req.title)
    try
      cr = API.use.crossref.works.doi req.doi
      req.title = cr.title[0]
      req.author ?= cr.author
      req.journal ?= cr['container-title'][0] if cr['container-title']?
      req.issn ?= cr.ISSN[0] if cr.ISSN?
      req.subject ?= cr.subject
      req.publisher ?= cr.publisher
      req.year = cr['published-print']['date-parts'][0][0] if cr['published-print']?['date-parts']? and cr['published-print']['date-parts'].length > 0 and cr['published-print']['date-parts'][0].length > 0
      req.crossref_type = cr.type
      req.year ?= cr.created['date-time'].split('-')[0] if cr.created?['date-time']?

  if req.journal and not req.sherpa? # doing this even on fast cos we may be able to close immediately. If users say too slow now, disable this on fast again
    try
      sherpa = API.use.sherpa.romeo.search {jtitle:req.journal}
      try req.sherpa = {color: sherpa.publishers[0].publisher[0].romeocolour[0]}
      # a problem with sherpa postrestrictions data caused saves to fail, which caused further problems. Disabling this for now. Need to wrangle sherpa data into a better shape
      #try
      #  req.sherpa.journal = sherpa.journals[0].journal[0]
      #  for k of req.sherpa.journal
      #    try
      #      if _.isArray(req.sherpa.journal[k]) and req.sherpa.journal[k].length is 1
      #        req.sherpa.journal[k] = req.sherpa.journal[k][0]
      #try
      #  req.sherpa.publisher = sherpa.publishers[0].publisher[0]
      #  for k of req.sherpa.publisher
      #    try
      #      if _.isArray(req.sherpa.publisher[k]) and req.sherpa.publisher[k].length is 1
      #        req.sherpa.publisher[k] = req.sherpa.publisher[k][0]

  if req.story
    res = oab_request.search 'rating:1 AND story.exact:"' + req.story + '"'
    if res.hits.total
      nres = oab_request.search 'rating:0 AND story.exact:"' + req.story + '"'
      req.rating = 1 if nres.hits.total is 0

  req.status ?= if not req.story or not req.title or not req.email or not req.user? then "help" else "moderate"
  if req.year
    try
      req.year = parseInt(req.year) if typeof req.year is 'string'
      if req.year < 2000
        req.status = 'closed'
        req.closed_on_create = true
        req.closed_on_create_reason = 'pre2000'
    try
      if fast and (new Date()).getFullYear() - req.year > 5 # only doing these on fast means only doing them via UI for now
        req.status = 'closed'
        req.closed_on_create = true
        req.closed_on_create_reason = 'gt5'
  if fast and not req.doi?
    req.status = 'closed'
    req.closed_on_create = true
    req.closed_on_create_reason = 'nodoi'
  if fast and req.crossref_type? and ['journal-article', 'proceedings-article'].indexOf(req.crossref_type) is -1
    req.status = 'closed'
    req.closed_on_create = true
    req.closed_on_create_reason = 'notarticle'
  if req.sherpa?.color? and typeof req.sherpa.color is 'string' and req.sherpa.color.toLowerCase() is 'white'
    req.status = 'closed'
    req.closed_on_create = true
    req.closed_on_create_reason = 'sherpawhite'

  if req.location?.geo
    req.location.geo.lat = Math.round(req.location.geo.lat*1000)/1000 if req.location.geo.lat
    req.location.geo.lon = Math.round(req.location.geo.lon*1000)/1000 if req.location.geo.lon

  req.receiver = Random.id()
  req._id = rid
  if req.title? and typeof req.title is 'string'
    try req.title = req.title.charAt(0).toUpperCase() + req.title.slice(1)
  if req.journal? and typeof req.journal is 'string'
    try req.journal = req.journal.charAt(0).toUpperCase() + req.journal.slice(1)
  oab_request.update rid, req
  if (fast and req.user?.email?) or send_confirmation
    try
      tmpl = API.mail.template 'initiator_confirmation.html'
      sub = API.service.oab.substitute tmpl.content, {_id: req._id, url: req.url, title:(req.title ? req.url) }
      API.mail.send
        service: 'openaccessbutton',
        from: sub.from ? API.settings.service.openaccessbutton.mail.from
        to: req.user.email
        subject: sub.subject ? 'New request created ' + req._id
        html: sub.content
  if req.story
    API.mail.send
      service: 'openaccessbutton'
      from: 'requests@openaccessbutton.org'
      to: API.settings.service.openaccessbutton.notify.request
      subject: 'New request created ' + req._id
      text: (if API.settings.dev then 'https://dev.openaccessbutton.org/request/' else 'https://openaccessbutton.org/request/') + req._id
  return req

API.service.oab.support = (rid,story,uacc) ->
  return false if story and story.indexOf('<script') isnt -1
  r = oab_request.get rid
  if not uacc?
    anons = {url:r.url,rid:r._id,type:r.type,username:'anonymous',story:story}
    anons._id = oab_support.insert anons
    return anons
  else if ((typeof uacc is 'string' and r.user?.id isnt uacc) or r.user?.id isnt uacc?._id ) and not API.service.oab.supports(rid,uacc)?
    oab_request.update rid, {count:r.count + 1}
    uacc = API.accounts.retrieve(uacc) if typeof uacc is 'string'
    s = {url:r.url,rid:r._id,type:r.type,uid:uacc._id,username:uacc.username,email:uacc.emails[0].address,story:story}
    s.firstname = uacc.profile?.firstname
    s.lastname = uacc.profile?.lastname
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

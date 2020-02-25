

import { Random } from 'meteor/random'



API.add 'service/oab/request',
  get:
    roleRequired:'openaccessbutton.user'
    action: () ->
      return {data: 'You have access :)'}
  post:
    authOptional: true
    action: () ->
      req = this.request.body
      req.doi ?= this.queryParams.doi if this.queryParams.doi?
      req.url ?= this.queryParams.url if this.queryParams.url?
      req.test = if this.request.headers.host is 'dev.api.cottagelabs.com' then true else false
      return {data: API.service.oab.request(req,this.user,this.queryParams.fast)}

API.add 'service/oab/request/:rid',
  get:
    authOptional: true
    action: () ->
      if r = oab_request.get this.urlParams.rid
        r.supports = API.service.oab.supports(this.urlParams.rid,this.userId) if this.userId
        return {data: r}
      else
        return 404
  post:
    roleRequired:'openaccessbutton.user',
    action: () ->
      if r = oab_request.get this.urlParams.rid
        n = {}
        if not r.user? and not r.story? and this.request.body.story
          n.story = this.request.body.story
          n.user = id: this.user._id, email: this.user.emails[0].address, username: (this.user.profile?.firstname ? this.user.username ? this.user.emails[0].address)
          n.user.firstname = this.user.profile?.firstname
          n.user.lastname = this.user.profile?.lastname
          n.user.affiliation = this.user.service?.openaccessbutton?.profile?.affiliation
          n.user.profession = this.user.service?.openaccessbutton?.profile?.profession
          n.count = 1 if not r.count? or r.count is 0
        if API.accounts.auth 'openaccessbutton.admin', this.user
          n.test ?= this.request.body.test if this.request.body.test? and this.request.body.test isnt r.test
          n.status ?= this.request.body.status if this.request.body.status? and this.request.body.status isnt r.status
          n.rating ?= this.request.body.rating if this.request.body.rating? and this.request.body.rating isnt r.rating
          n.name ?= this.request.body.name if this.request.body.name? and this.request.body.name isnt r.name
          n.email ?= this.request.body.email if this.request.body.email? and this.request.body.email isnt r.email
          n.author_affiliation ?= this.request.body.author_affiliation if this.request.body.author_affiliation? and this.request.body.author_affiliation isnt r.author_affiliation
          n.story ?= this.request.body.story if this.request.body.story? and this.request.body.story isnt r.story
          n.journal ?= this.request.body.journal if this.request.body.journal? and this.request.body.journal isnt r.journal
          n.notes = this.request.body.notes if this.request.body.notes? and this.request.body.notes isnt r.notes
          n.access_right = this.request.body.access_right if this.request.body.access_right? and this.request.body.access_right isnt r.access_right
          n.embargo_date = this.request.body.embargo_date if this.request.body.embargo_date? and this.request.body.embargo_date isnt r.embargo_date
          n.access_conditions = this.request.body.access_conditions if this.request.body.access_conditions? and this.request.body.access_conditions isnt r.access_conditions
          n.license = this.request.body.license if this.request.body.license? and this.request.body.license isnt r.license
          if this.request.body.received?.description? and (not r.received? or this.request.body.received.description isnt r.received.description)
            n.received = if r.received? then r.received else {}
            n.received.description = this.request.body.received.description
        n.email = this.request.body.email if this.request.body.email? and ( API.accounts.auth('openaccessbutton.admin',this.user) || not r.status? || r.status is 'help' || r.status is 'moderate' || r.status is 'refused' )
        n.story = this.request.body.story if r.user? and this.userId is r.user.id and this.request.body.story? and this.request.body.story isnt r.story
        n.url ?= this.request.body.url if this.request.body.url? and this.request.body.url isnt r.url
        n.title ?= this.request.body.title if this.request.body.title? and this.request.body.title isnt r.title
        n.doi ?= this.request.body.doi if this.request.body.doi? and this.request.body.doi isnt r.doi
        if n.story
          res = oab_request.search 'rating:1 AND story.exact:"' + n.story + '"'
          if res.hits.total
            nres = oab_request.search 'rating:0 AND story.exact:"' + n.story + '"'
            n.rating = 1 if nres.hits.total is 0
        if not n.status?
          if (not r.title and not n.title) || (not r.email and not n.email) || (not r.story and not n.story)
            n.status = 'help' if r.status isnt 'help'
          else if r.status is 'help' and ( (r.title or n.title) and (r.email or n.email) and (r.story or n.story) )
            n.status = 'moderate'
        if n.title? and typeof n.title is 'string'
          try n.title = n.title.charAt(0).toUpperCase() + n.title.slice(1)
        if n.journal? and typeof n.journal is 'string'
          try n.journal = n.journal.charAt(0).toUpperCase() + n.journal.slice(1)
        if not n.doi? and not r.doi? and r.url? and r.url.indexOf('10.') isnt -1 and r.url.split('10.')[1].indexOf('/') isnt -1
          n.doi = '10.' + r.url.split('10.')[1]
          r.doi = n.doi
        if (r.doi or r.url) and not r.title and not n.title
          try
            cr = if r.doi then API.service.oab.metadata(undefined, {doi: r.doi}) else API.service.oab.metadata {url: r.url}
            for c of cr
              n[c] ?= cr[c] if not r[c]?
        r.author_affiliation = n.author_affiliation if n.author_affiliation?
        if n.crossref_type? and n.crossref_type isnt 'journal-article'
          n.status = 'closed'
          n.closed_on_update = true
          n.closed_on_update_reason = 'notarticle'
        if (not r.email and not n.email) and r.author and r.author.length and (r.author[0].affiliation? or r.author_affiliation)
          try
            email = API.use.hunter.email {company: (r.author_affiliation ? r.author[0].affiliation[0].name), first_name: r.author[0].family, last_name: r.author[0].given}, API.settings.service.openaccessbutton.hunter.api_key
            if email?.email?
              n.email = email.email
        oab_request.update(r._id,n) if JSON.stringify(n) isnt '{}'
        if (r.user?.email? or n.user?.email?) and (not r.user or (not r.story? and n.story))
          try
            tmpl = API.mail.template 'initiator_confirmation.html'
            sub = API.service.oab.substitute tmpl.content, {_id: r._id, url: (r.url ? n.url), title:(r.title ? n.title ? r.url) }
            API.mail.send
              service: 'openaccessbutton',
              from: sub.from ? API.settings.service.openaccessbutton.mail.from
              to: n.user?.email ? r.user.email
              subject: sub.subject ? 'New request created ' + r._id
              html: sub.content
        return oab_request.get r._id
      else
        return 404
  delete:
    roleRequired:'openaccessbutton.user'
    action: () ->
      r = oab_request.get this.urlParams.rid
      oab_request.remove(this.urlParams.rid) if API.accounts.auth('openaccessbutton.admin',this.user) or this.userId is r.user.id
      return {}

API.add 'service/oab/request/:rid/admin/:action',
  get:
    roleRequired:'openaccessbutton.admin'
    action: () ->
      API.service.oab.admin this.urlParams.rid,this.urlParams.action
      return {}

API.add 'service/oab/requests', () -> return oab_request.search this

API.add 'service/oab/support/:rid',
  get:
    authOptional: true
    action: () ->
      return API.service.oab.support this.urlParams.rid, this.queryParams.story, this.user
  post:
    authOptional: true
    action: () ->
      return API.service.oab.support this.urlParams.rid, this.request.body.story, this.user

API.add 'service/oab/supports/:rid',
  get:
    roleRequired:'openaccessbutton.user'
    action: () ->
      return API.service.oab.supports this.urlParams.rid, this.user

API.add 'service/oab/supports', () -> return oab_support.search this



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
API.service.oab.request = (req,uacc,fast,notify=true) ->
  dom
  if req.dom
    dom = req.dom
    delete req.dom
  return false if JSON.stringify(req).indexOf('<script') isnt -1
  req.type ?= 'article'
  req.url = req.url[0] if _.isArray req.url
  req.doi = req.url if not req.doi? and req.url? and req.url.indexOf('10.') isnt -1 and req.url.split('10.')[1].indexOf('/') isnt -1
  req.doi = '10.' + req.doi.split('10.')[1].split('?')[0].split('#')[0] if req.doi? and req.doi.indexOf('10.') isnt 0
  req.doi = decodeURIComponent(req.doi) if req.doi
  if req.url? and req.url.indexOf('eu.alma.exlibrisgroup.com') isnt -1
    req.url += (if req.url.indexOf('?') is -1 then '?' else '&') + 'oabLibris=' + Random.id()
    if req.title? and typeof req.title is 'string' and req.title.length > 0 and texist = oab_request.find {title:req.title,type:req.type}
      texist.cache = true
      return texist
  else if req.doi or req.title or req.url
    eq = {type: req.type}
    if req.doi
      eq.doi = req.doi
    else if req.title
      eq.title = req.title
    else
      eq.url = req.url
    if exists = oab_request.find eq
      exists.cache = true
      return exists
  return false if not req.test and API.service.oab.blacklist req.url

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

  if not req.doi or not req.title or not req.email
    try
      cr = API.service.oab.metadata {url: req.url}, {doi: req.doi}
      for c of cr
        if c is 'email'
          for e in cr.email
            isauthor = false
            if cr?.author?
              for a in cr.author
                isauthor = a.family and e.toLowerCase().indexOf(a.family.toLowerCase()) isnt -1
            if isauthor and not API.service.oab.dnr(e) and API.mail.validate(e, API.settings.service?.openaccessbutton?.mail?.pubkey).is_valid
              req.email = e
              break
        else
          req[c] ?= cr[c]
  if _.isArray(req.author) and not req.author_affiliation
    for author in req.author
      try
        if req.email.toLowerCase().indexOf(author.family) isnt -1
          req.author_affiliation = author.affiliation[0].name
          break
  req.keywords ?= []
  req.title ?= ''
  req.doi ?= ''
  req.author = []
  req.journal = ''
  req.issn = ''
  req.publisher = ''
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

  if (req.journal or req.issn) and not req.sherpa? # doing this even on fast cos we may be able to close immediately. If users say too slow now, disable this on fast again
    try req.sherpa = API.use.sherpa.romeo.find(if req.issn then {issn:req.issn} else {title:req.journal})

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
  if fast and not req.doi? and req.status isnt 'closed'
    req.status = 'closed'
    req.closed_on_create = true
    req.closed_on_create_reason = 'nodoi'
  if fast and req.crossref_type? and req.crossref_type isnt 'journal-article' and req.status isnt 'closed'
    req.status = 'closed'
    req.closed_on_create = true
    req.closed_on_create_reason = 'notarticle'
  if req.sherpa?.color? and typeof req.sherpa.color is 'string' and req.sherpa.color.toLowerCase() is 'white' and req.status isnt 'closed'
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
  if req.story # and notify
    # for now still send if not notify, but remove Natalia (Joe requested it this way, so he still gets them on bulk creates, but Natalia does not)
    addrs = API.settings.service.openaccessbutton.notify.request
    if not notify and typeof addrs isnt 'string' and 'natalianorori@gmail.com' in addrs
      addrs.splice(addrs.indexOf('natalianorori@gmail.com'),1)
    API.mail.send
      service: 'openaccessbutton'
      from: 'requests@openaccessbutton.org'
      to: addrs
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


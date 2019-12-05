
API.service ?= {}
API.service.oab ?= {}

# these are global so can be accessed on other oabutton files
@oab_support = new API.collection {index:"oab",type:"support"}
@oab_catalogue = new API.collection {index:"oab",type:"catalogue",history:true}
@oab_request = new API.collection {index:"oab",type:"request",history:true}
@oab_find = new API.collection {index:"oab",type:"find"}
@oab_ill = new API.collection {index:"oab",type:"ill"}
@oab_dnr = new API.collection {index:"oab",type:"oab_dnr"}



API.add 'service/oab', 
  get: () -> return {data: 'The Open Access Button API.'}
  post:
    roleRequired:'openaccessbutton.user'
    action: () ->
      return {data: 'You are authenticated'}

API.add 'service/oab/blacklist',
  get: () -> return {data:API.service.oab.blacklist(undefined,undefined,this.queryParams.stale)}

API.add 'service/oab/templates',
  get: () -> return API.service.oab.template(this.queryParams.template,this.queryParams.refresh)

API.add 'service/oab/substitute',
  post: () -> return API.service.oab.substitute this.request.body.content,this.request.body.vars,this.request.body.markdown

API.add 'service/oab/mail',
  post:
    roleRequired:'openaccessbutton.admin'
    action: () -> return API.service.oab.mail this.request.body

API.add 'service/oab/validate',
  post: () ->
    # TODO add a way to pick up the institution that the email address has to be valid for, for shareyourpaper and possibly other uses later
    # probably use the uid to get the user account, which should be the account of the institution configuring the embed, which probably 
    # needs to list valid domains their user email addresses could be under. Then only valid the valid address that is also in those domains
    if not this.queryParams.uid or not this.queryParams.email or not API.accounts.retrieve this.queryParams.uid
      return undefined
    else
      v = API.mail.validate(this.queryParams.email, API.settings.service.openaccessbutton.mail.pubkey)
      return if v.is_valid then true else if v.did_you_mean then v.did_you_mean else false

API.add 'service/oab/dnr',
  get:
    authOptional: true
    action: () ->
      return API.service.oab.dnr() if not this.queryParams.email? and this.user and API.accounts.auth 'openaccessbutton.admin', this.user
      d = {}
      d.dnr = API.service.oab.dnr this.queryParams.email
      if not d.dnr and this.queryParams.user
        u = API.accounts.retrieve this.queryParams.user
        d.dnr = 'user' if u.emails[0].address is this.queryParams.email
      if not d.dnr and this.queryParams.request
        r = oab_request.get this.queryParams.request
        d.dnr = 'creator' if r.user.email is this.queryParams.email
        if not d.dnr
          d.dnr = 'supporter' if oab_support.find {rid:this.queryParams.request, email:this.queryParams.email}
      if not d.dnr and this.queryParams.validate
        d.validation = API.mail.validate this.queryParams.email, API.settings.service?.openaccessbutton?.mail?.pubkey
        d.dnr = 'invalid' if not d.validation.is_valid
      return d
  post: () ->
    e = this.queryParams.email ? this.request.body.email
    refuse = if not this.queryParams.refuse? or this.queryParams.refuse in ['false',false] then false else true
    return if e then API.service.oab.dnr(e,true,refuse) else 400
  delete:
    authRequired: 'openaccessbutton.admin'
    action: () ->
      oab_dnr.remove({email:this.queryParams.email}) if this.queryParams.email
      return {}

API.add 'service/oab/bug',
  post: () ->
    whoto = ['help@openaccessbutton.org']
    try
      if this.request.body?.form is 'wrong'
        whoto.push 'requests@openaccessbutton.org'
    API.mail.send {
      service: 'openaccessbutton',
      from: 'help@openaccessbutton.org',
      to: whoto,
      subject: 'Feedback form submission',
      text: JSON.stringify(this.request.body,undefined,2)
    }
    return {
      statusCode: 302,
      headers: {
        'Content-Type': 'text/plain',
        'Location': (if API.settings.dev then 'https://dev.openaccessbutton.org' else 'https://openaccessbutton.org') + '/bug#defaultthanks'
      },
      body: 'Location: ' + (if API.settings.dev then 'https://dev.openaccessbutton.org' else 'https://openaccessbutton.org') + '/bug#defaultthanks'
    }

API.add 'service/oab/history', () -> return oab_request.history this

API.add 'service/oab/users',
  get:
    roleRequired:'openaccessbutton.admin'
    action: () -> 
      res = Users.search this.queryParams, {restrict:[{exists:{field:'roles.openaccessbutton'}}]}
      try
        for r in res.hits.hits
          if not r._source.email?
            r._source.email = r._source.emails[0].address
      return res
  post:
    roleRequired:'openaccessbutton.admin'
    action: () -> 
      res = Users.search this.bodyParams, {restrict:[{exists:{field:'roles.openaccessbutton'}}]}
      try
        for r in res.hits.hits
          if not res.hits.hits[r]._source.email?
            res.hits.hits[r]._source.email = res.hits.hits[r]._source.emails[0].address
      return res

API.add 'service/oab/status', get: () -> return API.service.oab.status()
API.add 'service/oab/stats', get: () -> return {} # plaeholder for possible later stats stuff, for now just to allow getting the emails
API.add 'service/oab/stats/emails', 
  post: 
    roleRequired:'openaccessbutton.admin'
    action: () -> 
      res = {}
      for uid in this.request.body
        try res[uid] = API.accounts.retrieve(uid).emails[0].address
      return res




API.service.oab.status = () ->
  return
    requests: oab_request.count()
    test: oab_request.count undefined, {test:true}
    help: oab_request.count undefined, {status:'help'}
    moderate: oab_request.count undefined, {status:'moderate'}
    progress: oab_request.count undefined, {status:'progress'}
    hold: oab_request.count undefined, {status:'hold'}
    refused: oab_request.count undefined, {status:'refused'}
    received: oab_request.count undefined, {status:'received'}
    supports: oab_support.count()
    availabilities: oab_availability.count()
    users: Users.count undefined, {exists:{field:"roles.openaccessbutton"}}
    requested: oab_request.count 'user.id', {exists:{field:'user.id'}}

API.service.oab.blacklist = (url,stale=360000) ->
  API.log msg: 'Checking OAB blacklist', url: url
  stale = 0 if stale is false
  return false if url? and (url.length < 4 or url.indexOf('.') is -1)
  bl = API.use.google.sheets.feed API.settings.service.openaccessbutton?.google?.sheets?.blacklist, stale
  blacklist = []
  blacklist.push(i.url) for i in bl
  if url
    for b in blacklist
      return true if url.indexOf(b) isnt -1
    return false
  else
    return blacklist

API.service.oab.dnr = (email,add,refuse) ->
  return oab_dnr.search('*')?.hits?.hits if not email? and not add?
  ondnr = oab_dnr.find {email:email}
  if add and not ondnr
    oab_dnr.insert {email:email}
    # also set any requests where this author is the email address to refused - can't use the address!
    if refuse
      oab_request.each {email:email}, (req) -> API.service.oab.refuse req._id, 'Author DNRd their email address'
    else
      oab_request.each {email:email}, (req) ->
        if req.status in ['help','moderate','progress']
          oab_request.update r._id, {email:'',status:'help'}
  return ondnr? or add is true

API.service.oab.template = (template,refresh) ->
  if refresh or mail_template.count(undefined,{service:'openaccessbutton'}) is 0
    mail_template.remove {service:'openaccessbutton'}
    ghurl = API.settings.service.openaccessbutton?.templates_url
    m = API.tdm.extract
      url:ghurl
      matchers:['/href="/OAButton/website/blob/develop/emails/(.*?[.].*?)">/gi']
      start:'<table class="files'
      end:'</table'
    fls = []
    fls.push(fm.result[1]) for fm in m.matches
    flurl = ghurl.replace('github.com','raw.githubusercontent.com').replace('/tree','')
    for f in fls
      if f isnt 'archive'
        content = HTTP.call('GET',flurl + '/' + f).content
        API.mail.template undefined,{filename:f,service:'openaccessbutton',content:content}
    return API.mail.template {service:'openaccessbutton'}
  else if template
    return API.mail.template template
  else
    return API.mail.template {service:'openaccessbutton'}

API.service.oab.vars = (vars) ->
  vars = JSON.parse JSON.stringify vars # need this in case a request is passed in as vars and later edited
  if vars?.user
    u = API.accounts.retrieve vars.user.id
    if u
      vars.profession = u.service?.openaccessbutton?.profile?.profession ? 'person'
      vars.profession = 'person' if vars.profession.toLowerCase() is 'other'
      vars.affiliation = u.service?.openaccessbutton?.profile?.affiliation ? ''
    vars.userid = vars.user.id
    vars.fullname = u?.profile?.name ? ''
    if not vars.fullname and u?.profile?.firstname
      vars.fullname = u.profile.firstname
      vars.fullname += ' ' + u.profile.lastname if u.profile.lastname
    vars.username = vars.user.username ? vars.fullname
    vars.useremail = vars.user.email
  vars.profession ?= 'person'
  vars.fullname ?= 'a user'
  vars.name ?= 'colleague'
  return vars

API.service.oab.substitute = (content,vars,markdown) ->
  vars = API.service.oab.vars vars
  if API.settings.dev
    content = content.replace(/https:\/\/openaccessbutton.org/g,'https://dev.openaccessbutton.org')
    content = content.replace(/https:\/\/api.openaccessbutton.org/g,'https://dev.api.cottagelabs.com/service/oab')
  return API.mail.substitute content, vars, markdown

API.service.oab.mail = (opts={}) ->
  opts.service = 'openaccessbutton'
  opts.subject ?= 'Hello from Open Access Button'
  opts.from ?= API.settings.service.openaccessbutton?.requests_from

  if opts.bcc is 'ALL'
    opts.bcc = []
    Users.each {"roles.openaccessbutton":"*"}, (user) -> opts.bcc.push user.emails[0].address

  return API.mail.send opts

API.service.oab.admin = (rid,action) ->
  r = oab_request.get rid
  vars = API.service.oab.vars r
  usermail
  if r.user?.id
    u = API.accounts.retrieve r.user.id
    usermail = u.emails[0].address
  update = {}
  requestors = []
  requestors.push(usermail) if usermail
  oab_support.each {rid:rid}, (s) -> requestors.push(s.email) if s.email and s.email not in requestors
  if action is 'reject_upload'
    update.status = 'moderate'
    API.service.oab.mail({vars:vars,template:{filename:'author_thanks_article_rejection.html'},to:r.email})
  else if action is 'successful_upload'
    update.status = 'received'
    API.service.oab.mail({vars:vars,template:{filename:'requesters_request_success.html'},to:requestors}) if requestors.length
    API.service.oab.mail({vars:vars,template:{filename:'author_thanks_article.html'},to:r.email})
  else if action is 'send_to_author'
    update.status = 'progress'
    update.rating = 1 if r.story
    API.service.oab.mail({vars:vars,template:{filename:'requesters_request_inprogress.html'},to:requestors}) if requestors.length
    if r.type is 'article'
      if r.email
        if r.story
          API.service.oab.mail({vars:vars,template:{filename:'author_request_article_v2.html'},to:r.email})
        else
          API.service.oab.mail({vars:vars,template:{filename:'author_request_article_v2_nostory.html'},to:r.email})
    else if r.email
      API.service.oab.mail({vars:vars,template:{filename:'author_request_data_v2.html'},to:r.email})
  else if action is 'story_too_bad'
    update.status = 'help'
    update.rating = 0
    API.service.oab.mail({vars:vars,template:{filename:'initiator_poorstory.html'},to:requestors}) if requestors.length
    API.service.oab.mail({vars:vars,template:{filename:'author_request_article_v2_nostory.html'},to:r.email}) if r.email
  else if action is 'not_a_scholarly_article'
    update.status = 'closed'
    API.service.oab.mail({vars:vars,template:{filename:'initiator_invalid.html'},to:usermail}) if usermail
  else if action is 'dead_author'
    update.status = 'closed'
    API.service.oab.mail({vars:vars,template:{filename:'requesters_request_failed_authordeath.html'},to:requestors}) if requestors.length
  else if action is 'user_testing'
    update.test = true
    update.status = 'closed'
    update.rating = 0 if r.story
    API.service.oab.mail({vars:vars,template:{filename:'initiator_testing.html'},to:usermail}) if usermail
  else if action is 'broken_link' and usermail
    API.service.oab.mail({vars:vars,template:{filename:'initiator_brokenlink.html'},to:usermail})
    update.status = 'closed'
  else if action is 'remove_submitted_url'
    update.status = 'moderate'
    update.received = false
  else if action is 'article_before_2000'
    API.service.oab.mail({vars:vars,template:{filename:'article_before_2000.html'},to:requestors}) if requestors.length
    update.status = 'closed'
  else if action is 'author_email_not_found'
    API.service.oab.mail({vars:vars,template:{filename:'author_email_not_found.html'},to:requestors}) if requestors.length
    update.status = 'closed'
  else if action is 'link_by_author'
    API.service.oab.mail({vars:vars,template:{filename:'authors_thanks_article.html'},to:r.email}) if r.email
    API.service.oab.mail({vars:vars,template:{filename:'requestors_request_success_article.html'},to:requestors}) if requestors.length
    update.status = 'received'
  else if action is 'link_by_admin'
    API.service.oab.mail({vars:vars,template:{filename:'requestors_request_success_article.html'},to:requestors}) if requestors.length
    update.status = 'received'
  oab_request.update(rid,update) if JSON.stringify(update) isnt '{}'


# LIVE: https://docs.google.com/spreadsheets/d/1Te9zcQtBLq2Vx81JUE9R42fjptFGXY6jybXBCt85dcs/edit#gid=0
# Develop: https://docs.google.com/spreadsheets/d/1AaY7hS0D9jtLgVsGO4cJuLn_-CzNQg0yCreC3PP3UU0/edit#gid=0

API.service.oab.redirect = (url) ->
  API.log msg: 'Checking OAB open list', url: url
  url = API.http.resolve url # will return undefined if the url doesn't resolve at all
  if url
    return false if API.service.oab.blacklist(url) is true # ignore anything on the usual URL blacklist
    list = API.use.google.sheets.feed API.settings.service.openaccessbutton?.google?.sheets?.redirect, 360000
    for listing in list
      if listing.redirect and url.replace('http://','').replace('https://','').split('#')[0] is listing.redirect.replace('http://','').replace('https://','').split('#')[0]
        # we have an exact alternative for this url
        return listing.redirect
      else if typeof url is 'string' and url.indexOf(listing.domain.replace('http://','').replace('https://','').split('/')[0]) isnt -1
        url = url.replace('http://','https://') if listing.domain.indexOf('https://') is 0
        listing.domain = listing.domain.replace('http://','https://') if url.indexOf('https://') is 0
        if (listing.fulltext and listing.splash and listing.identifier) or listing.element
          source = url
          if listing.fulltext
            # switch the url by comparing the fulltext and splash examples, and converting the url in the same way
            parts = listing.splash.split listing.identifier
            if url.indexOf(parts[0]) is 0 # can only successfully replace if the incoming url starts with the same as the start of the splash url
              diff = url.replace parts[0], ''
              diff = diff.replace(parts[1],'') if parts.length > 1
              url = listing.fulltext.replace listing.identifier, diff
          else if listing.element and url.indexOf('.pdf') is -1
            try
              content = API.http.puppeteer url
              url = content.toLowerCase().split(listing.element.toLowerCase())[1].split('"')[0].split("'")[0].split('>')[0]
          return false if (not url? or url.length < 6 or url is source) and listing.blacklist is "yes"
          # fulltext or element can possibly give us a url which then redirects to a login wall
          # so we have to check the given url against the whole sheet listing again for the login wall
          # so this allows the rest of the listing to be checked before returning - MAKE SURE loginwall fragments are at the end of the sheet
          resv = API.http.resolve url # resolve it again to make sure whatever we have now is accessible
          url = resv if typeof resv is 'string'
        else if listing.loginwall and url.indexOf(listing.loginwall.replace('http://','').replace('https://','')) isnt -1
          # this url is on the login wall of the repo in question, so it is no use
          return false
        else if listing.blacklist is "yes"
          return false
  if typeof url is 'string'
    # some URLs can be confirmed as resolvable but we also hit a captcha response and end up serving that to the user
    # we want to avoid that, so when such URLs appear to be found here, just return true instead, which will cause 
    # us to accept the original URL
    # we introduced this because of issue https://github.com/OAButton/discussion/issues/1257
    # and for example https://www.tandfonline.com/doi/pdf/10.1080/17521740701702115?needAccess=true
    # ends up as https://www.tandfonline.com/action/captchaChallenge?redirectUri=%2Fdoi%2Fpdf%2F10.1080%2F17521740701702115%3FneedAccess%3Dtrue
    for avoid in ['captcha','challenge']
      return undefined if url.toLowerCase().indexOf(avoid) isnt -1
  return url


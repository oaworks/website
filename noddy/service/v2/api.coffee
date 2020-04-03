
import moment from 'moment'

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
  get: () -> return {data:API.service.oab.blacklist(this.queryParams.url,this.queryParams.stale)}

API.add 'service/oab/templates',
  get: () -> return API.service.oab.template(this.queryParams.template,this.queryParams.refresh)

API.add 'service/oab/substitute',
  post: () -> return API.service.oab.substitute this.request.body.content,this.request.body.vars,this.request.body.markdown

API.add 'service/oab/mail',
  post:
    roleRequired:'openaccessbutton.admin'
    action: () -> return API.service.oab.mail this.request.body

API.add 'service/oab/validate',
  post: 
    authOptional:true
    action: () ->
      if (this.queryParams.uid or this.userId) and API.accounts.retrieve(this.queryParams.uid ? this.userId)
        return API.service.oab.validate this.queryParams.email, this.queryParams.domained
      else
        return undefined

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
    roleRequired: 'openaccessbutton.admin'
    action: () ->
      oab_dnr.remove({email:this.queryParams.email}) if this.queryParams.email
      return {}

API.add 'service/oab/bug',
  post: () ->
    if (this.request.body?.contact? and this.request.body.contact.length) or (this.request.body?.email? and API.service.oab.validate(this.request.body.email) isnt true)
      return ''
    else
      whoto = ['help@openaccessbutton.org']
      text = ''
      for k of this.request.body
        text += k + ': ' + JSON.stringify(this.request.body[k],undefined,2) + '\n\n'
      subject = '[OAB forms]'
      if this.request.body?.form is 'uninstall' # wrong bug general other
        subject += ' Uninstall notice'
      else if this.request.body?.form is 'wrong'
        subject += ' Wrong article'
      else if this.request.body?.form is 'bug'
        subject += ' Bug'
      else if this.request.body?.form is 'general'
        subject += ' General'
      else
        subject += ' Other'
      subject += ' ' + Date.now()
      try
        if this.request.body?.form is 'wrong'
          whoto.push 'requests@openaccessbutton.org'
      API.mail.send {
        service: 'openaccessbutton',
        from: 'help@openaccessbutton.org',
        to: whoto,
        subject: subject,
        text: text
      }
      return {
        statusCode: 302,
        headers: {
          'Content-Type': 'text/plain',
          'Location': (if API.settings.dev then 'https://dev.openaccessbutton.org' else 'https://openaccessbutton.org') + '/feedback#defaultthanks'
        },
        body: 'Location: ' + (if API.settings.dev then 'https://dev.openaccessbutton.org' else 'https://openaccessbutton.org') + '/feedback#defaultthanks'
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

API.add 'service/oab/redirect', get: () -> return API.service.oab.redirect this.queryParams.url, this.queryParams.refresh?

API.add 'service/oab/status', get: () -> return API.service.oab.status()
API.add 'service/oab/stats', get: () -> return API.service.oab.stats this.queryParams.tool
API.add 'service/oab/stats/emails', 
  post: 
    roleRequired:'openaccessbutton.admin'
    action: () -> 
      res = {}
      for uid in this.request.body
        try res[uid] = API.accounts.retrieve(uid).emails[0].address
      return res




API.service.oab.status = () ->
  return # simple queries to get basic status - use stats below for more complex feedback
    requests: oab_request.count()
    stories: oab_request.count undefined, 'story:*'
    test: oab_request.count undefined, {test:true}
    help: oab_request.count undefined, {status:'help'}
    moderate: oab_request.count undefined, {status:'moderate'}
    progress: oab_request.count undefined, {status:'progress'}
    hold: oab_request.count undefined, {status:'hold'}
    refused: oab_request.count undefined, {status:'refused'}
    received: oab_request.count undefined, {status:'received'}
    supports: oab_support.count()
    finds: oab_find.count()
    found: oab_find.count undefined, 'url:*'
    users: Users.count undefined, {exists:{field:"roles.openaccessbutton"}}
    requested: oab_request.count 'user.id', {exists:{field:"user.id"}}

API.service.oab.stats = (tool) ->
  tool = undefined if tool? and tool not in ['embedoa','illiad','clio']
  q = if tool is 'embedoa' then 'plugin:'+tool else if tool? then 'from:'+tool else undefined
  res = status: API.service.oab.status(), requests: {}
  if q?
    res.status.finds = oab_find.count undefined, q
    res.status.found = oab_find.count undefined, q + ' AND url:*'
    res.status.stories = oab_request.count undefined, q + ' AND story:*'

  twoyearsago = Date.now() - (31536000000*2)
  rgs = {requests: {date_histogram: {field: "createdAt", interval: "week"}}}
  rgs.requests2yrs = {aggs: {vals: {date_histogram: {field: "createdAt", interval: "week"}}}, filter: {range: {createdAt: {gt: twoyearsago }}}}
  rgs.stories2yrs = {aggs: {vals: {date_histogram: {field: "createdAt", interval: "week"}}}, filter: {bool: {must: [{exists: {field: 'story'}}, {range: {createdAt: {gt: twoyearsago }}}]}}}
  rgs.received2yrs = {aggs: {vals: {date_histogram: {field: "received.date", interval: "week"}}}, filter: {bool: {must: [{term: {status: 'received'}}, {range: {createdAt: {gt: twoyearsago }}}]}}}
  #ra = oab_request.search q, {size: 0, aggregations: rgs}
  #res.requests.requests = ra.aggregations.requests.buckets
  #res.requests.requests2yrs = ra.aggregations.requests2yrs.vals.buckets
  #res.requests.stories2yrs = ra.aggregations.stories2yrs.vals.buckets
  #res.requests.received2yrs = ra.aggregations.received2yrs.vals.buckets

  # query finds
  tmwk = moment().startOf('week').valueOf() # timestamp up to a week ago
  tm1 = moment().startOf('month').valueOf() # timestamp at start of the current month
  tm3 = moment().subtract(3,'months').valueOf() # timestamp 3 months ago
  aggs =
    users: {terms: {field: "from.exact", size: 10000}, aggs: {firsts: {terms: {field: "created_date", size: 1, order: {_term: "asc"}}}}}
    finds: {date_histogram: {field: "createdAt", interval: "week"}}
    emails: {cardinality : {field: "email.exact"}}
    tm1: {filter: {range: {createdAt: {gt: tm1}}}, aggs: {tm1v: {cardinality: {field: "email.exact" }}}}
    tm3: {filter: {range: {createdAt: {gt: tm3, lte: tm1 }}}, aggs: {tm3v: {cardinality: {field: "email.exact" }}}}
  facets =
    plugin: { terms: { field: "plugin.exact", size: 500}}
    plugin_week: { terms: { field: "plugin.exact", size: 500 }, facet_filter: {range: {createdAt: {gt: tmwk }}}}
    plugin_month: { terms: { field: "plugin.exact", size: 500 }, facet_filter: {range: {createdAt: {gt: tm1 }}}}
    plugin_threemonth: { terms: { field: "plugin.exact", size: 500 }, facet_filter: {range: {createdAt: {gt: tm3 }}}}
    plugin_june18: { terms: { field: "plugin.exact", size: 500 }, facet_filter: {range: {createdAt: {gt: 1527811200000 }}}}
    email: { terms: { field: "email.exact", size: 1 } }
    embeds: { terms: { field: "embedded.exact", size: 500 } }
    from_week: { terms: { field: "from.exact", size: 500 }, facet_filter: {range: {createdAt: {gt: tmwk  }}}}
    from_month: { terms: { field: "from.exact", size: 500 }, facet_filter: {range: {createdAt: {gt: tm1 }}}}
    from_threemonth: { terms: { field: "from.exact", size: 500 }, facet_filter: {range: {createdAt: {gt: tm3 }}}}
    from_june18: { terms: { field: "from.exact", size: 500 }, facet_filter: {range: {createdAt: {gt: 1527811200000 }}}}
  finds = oab_find.search q, { size: 0, aggs: aggs, facets: facets}
  res.find = {total: finds.hits.total, users: {}}
  try
    for u in finds.aggregations.users.buckets
      res.find.users[u.key] = count: u.doc_count, first: u.firsts.buckets[0].key_as_string.split(' ')[0].split('-').reverse().join('/')
  try res.find.finds = finds.aggregations.finds.buckets
  try res.find.emails = finds.aggregations.emails.value
  try res.find.tm1 = finds.aggregations.tm1.tm1v.value
  try res.find.tm3 = finds.aggregations.tm3.tm3v.value
  try res.find.plugin = finds.facets.plugin.terms
  try res.find.plugin_week = finds.facets.plugin_week.terms
  try res.find.plugin_month = finds.facets.plugin_month.terms
  try res.find.plugin_threemonth = finds.facets.plugin_threemonth.terms
  try res.find.plugin_june18 = finds.facets.plugin_june18.terms
  try res.find.email = finds.facets.email.terms
  try res.find.anonymous = finds.facets.email.missing
  try res.find.embeds = finds.facets.embeds.terms
  try res.find.from_week = finds.facets.from_week.terms
  try res.find.from_month = finds.facets.from_month.terms
  try res.find.from_threemonth = finds.facets.from_threemonth.terms
  try res.find.from_june18 = finds.facets.from_june18.terms

  res.plugins = {api:{all:finds.facets.plugin.missing, week:finds.facets.plugin_week.missing, month:finds.facets.plugin_month.missing, threemonth:finds.facets.plugin_threemonth.missing, june18:finds.facets.plugin_june18.missing}}

  if not tool? # get pings
    pingcounts = {alltime:{},week:{},month:{},threemonth:{},june18:{}}
    for h in pings.search('service:openaccessbutton AND action:*', {newest: false, size: 100000}).hits.hits
      hr = h._source
      for nm in _.keys pingcounts
        if nm is 'alltime' or (nm is 'week' and hr.createdAt > tmwk) or (nm is 'month' and hr.createdAt > tm1) or (nm is 'threemonth' and hr.createdAt > tm3) or (nm is 'june18' and hr.createdAt > 1527811200000)
          pingcounts[nm][hr.action] = (pingcounts[nm][hr.action] ? 0) + 1
    sorts = []
    for kv of pingcounts.alltime
      sp = action: kv
      sp[nm] = (pingcounts[nm][kv] ? 0) for nm in _.keys pingcounts
      sorts.push sp
    res.pings = sorts.sort((a, b) -> return a.alltime - b.alltime)

  if not tool? or tool is 'embedoa' # stats on embedoa
    eggs = {users: {terms: {field: "from.exact", size: 10000}}}
    eggs.users.aggs = {firsts: {terms: {field:"created_date", size: 1, order: {_term: "asc"}}}}
    eggs.users.aggs.oa = {filter: {bool: {must: [{exists: {field: "url"}}]}}, aggs: {from: {terms: {field: "from.exact"}}}}
    eggs.users.aggs.embeds = {terms: {field: "embedded.exact", size: 100}}
    eres = oab_find.search {plugin: 'widget'}, {size: 0, aggs: eggs}
    # TODO finish formatting the embedoa results into the necessary stats
    res.embedoa = {}
    try
      for u in eres.aggregations.users.buckets
        res.embedoa[u.key] = count: u.doc_count
        try res.embedoa[u.key].first = u.firsts.buckets[0].key_as_string.split(' ')[0].split('-').reverse().join('/')
        try res.embedoa[u.key].oa = u.oa.doc_count # check this
        res.embedoa[u.key].embeds = []
        for em in u.embeds.buckets
          tk = em.key.split('?')[0].split('#')[0]
          res.embedoa[u.key].embeds.push(tk) if tk not in res.embedoa[u.key].embeds

  if not tool? # ills
    iggs = {users: {terms: {field: "from.exact", size: 10000}}}
    iggs.users.aggs = {firsts: {terms: {field:"created_date", size: 1, order: {_term: "asc"}}}}
    iggs.users.aggs.oa = {filter: {bool: {must: [{exists: {field: "url"}}]}}, aggs: {from: {terms: {field: "from.exact"}}}}
    iggs.users.aggs.subs = {filter: {query: {query_string: {query: "ill.subscription.url:*"}}}, aggs: {from: {terms: {field: "from.exact"}}}}
    iggs.users.aggs.wrong = {filter: {term: {wrong: true}}, aggs: {from: {terms: {field: "from.exact"}}}}
    iggs.users.aggs.embeds = {terms: {field: "embedded.exact", size: 100}}
    illfinds = oab_find.search {plugin: 'instantill'}, {size: 0, aggs: iggs}
    res.ill = {}
    try
      for u in illfinds.aggregations.users.buckets
        res.ill[u.key] = count: u.doc_count
        try res.ill[u.key].first = u.firsts.buckets[0].key_as_string.split(' ')[0].split('-').reverse().join('/')
        try res.ill[u.key].oa = u.oa.doc_count
        try res.ill[u.key].subs = u.subs.doc_count
        try res.ill[u.key].wrong = u.wrong.doc_count
        res.ill[u.key].embeds = []
        for em in u.embeds.buckets
          tk = em.key.split('?')[0].split('#')[0]
          res.ill[u.key].embeds.push(tk) if tk not in res.ill[u.key].embeds
    igs = {users: {terms: {field: "from.exact", size: 10000}}}
    igs.issn = {filter: {query: {query_string: {query: "metadata.title:* AND metadata.journal:* AND metadata.year:* AND metadata.issn:*"}}}, aggs: {users: {terms: {field: "from.exact", size: 10000}}}}
    igs.forwarded = {filter: {term: {forwarded: true}}, aggs: {users: {terms: {field: "from.exact", size: 10000}}}}
    ills = oab_ill.search undefined, {size: 0, aggs: igs}
    try
      for u in ills.aggregations.users.buckets
        res.ill[u.key] ?= {}
        res.ill[u.key].ill = u.doc_count
    try res.ill[u.key].withissn = u.doc_count for u in ills.aggregations.issn.users.buckets
    try res.ill[u.key].forwarded = u.doc_count for u in ills.aggregations.forwarded.users.buckets

  return res

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

API.service.oab.validate = (email, domain) ->
  bad = ['eric@talkwithcustomer.com']
  if typeof email isnt 'string' or email.indexOf(',') isnt -1 or email in bad
    return false
  else
    v = API.mail.validate email, API.settings.service.openaccessbutton.mail.pubkey
    if v.is_valid
      if domain and domain not in ['qZooaHWRz9NLFNcgR','eZwJ83xp3oZDaec86']
        iacc = API.accounts.retrieve domain
        return 'baddomain' if not iacc?
        eml = false #iacc.email ? iacc.emails[0].address # may also later have a config where the allowed domains can be listed but for now just match the domain of the account holder - only in the case where shareyourpaper config exists
        dc = false
        try
          dc = API.service.oab.deposit.config iacc
          #eml = dc.adminemail if dc.adminemail? # don't bother defaulting to the admin email
          dc.email_domains = dc.email_domains.split(',') if dc.email_domains? and typeof dc.email_domains is 'string'
        if dc isnt false and dc.email_domains? and _.isArray(dc.email_domains) and dc.email_domains.length > 0
          for ed in dc.email_domains
            if email.toLowerCase().indexOf(ed.toLowerCase()) > 0
              return true
          return 'baddomain'
        else
          if typeof eml is 'string' and eml.toLowerCase().indexOf(email.split('@')[1].split('.')[0].toLowerCase()) is -1
            return 'baddomain'
          else
            return true
      else
        return true
    else if v.did_you_mean
      return v.did_you_mean
    else
      return false
  
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

API.service.oab.redirect = (url,refresh=false) ->
  API.log msg: 'Checking OAB open list', url: url
  url = API.http.resolve url, refresh # will return undefined if the url doesn't resolve at all
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


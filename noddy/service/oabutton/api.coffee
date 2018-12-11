
import moment from 'moment'

# these are global so can be accessed on other oabutton files
@oab_support = new API.collection {index:"oab",type:"support"}
@oab_availability = new API.collection {index:"oab",type:"availability"}
@oab_request = new API.collection {index:"oab",type:"request",history:true}

# the normal declaration of API.service.oab is in admin.coffee, because it gets loaded before this api.coffee file

API.add 'service/oab',
  get: () ->
    return {data: 'The Open Access Button API.'}
  post:
    roleRequired:'openaccessbutton.user'
    action: () ->
      return {data: 'You are authenticated'}

_avail =
  authOptional: true
  action: () ->
    opts = if not _.isEmpty(this.request.body) then this.request.body else this.queryParams
    opts.refresh ?= this.queryParams.refresh
    opts.from ?= this.queryParams.from
    opts.plugin ?= this.queryParams.plugin
    opts.all ?= this.queryParams.all
    opts.titles ?= this.queryParams.titles
    ident = opts.doi
    ident ?= opts.url
    ident ?= 'pmid' + opts.pmid if opts.pmid
    ident ?= 'pmc' + opts.pmc.toLowerCase().replace('pmc','') if opts.pmc
    ident ?= 'TITLE:' + opts.title if opts.title
    ident ?= 'CITATION:' + opts.citation if opts.citation
    opts.url = ident
    # should maybe put auth on the ability to pass in library and libraries...
    opts.libraries = opts.libraries.split(',') if opts.libraries
    opts.sources = opts.sources.split(',') if opts.sources
    if this.user?
      opts.uid = this.userId
      opts.username = this.user.username
      opts.email = this.user.emails[0].address
    return if not opts.test and API.service.oab.blacklist(opts.url) then 400 else {data:API.service.oab.find(opts)}
API.add 'service/oab/find', get:_avail, post:_avail
API.add 'service/oab/availability', get:_avail, post:_avail # exists for legacy reasons

API.add 'service/oab/resolve',
  get: () ->
    return API.service.oab.resolve this.queryParams,undefined,this.queryParams.sources?.split(','),this.queryParams.all,this.queryParams.titles,this.queryParams.journal

API.add 'service/oab/ill/:library',
  post: () ->
    opts = this.request.body;
    opts.library = this.urlParams.library;
    return API.service.oab.ill opts

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
        others = oab_request.search({url:r.url})
        if others?
          for o in others.hits.hits
            r.other = o._source._id if o._source._id isnt r._id and o._source.type isnt r.type
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
        if r.doi and not r.title and not n.title
          try
            cr = API.use.crossref.works.doi r.doi
            n.title = cr.title[0]
            n.author ?= cr.author if not r.author?
            n.journal ?= cr['container-title'][0] if cr['container-title']? and not r.journal?
            n.issn ?= cr.ISSN[0] if cr.ISSN? and not r.issn?
            n.subject ?= cr.subject if not r.subject?
            n.publisher ?= cr.publisher if not r.publisher?
            n.year = cr['published-print']['date-parts'][0][0] if not r.year? and cr['published-print']?['date-parts']? and cr['published-print']['date-parts'].length > 0 and cr['published-print']['date-parts'][0].length > 0
            n.crossref_type = cr.type if not r.crossref_type?
            n.year ?= cr.created['date-time'].split('-')[0] if not r.year? and cr.created?['date-time']?
        r.author_affiliation = n.author_affiliation if n.author_affiliation?
        if n.crossref_type? and ['journal-article', 'proceedings-article'].indexOf(n.crossref_type) is -1
          n.status = 'closed'
          n.closed_on_update = true
          n.closed_on_update_reason = 'notarticle'
        if (not r.email and not n.email) and r.author and r.author.length and (r.author[0].affiliation? or r.author_affiliation)
          try
            email = API.use.hunter.email {company: (r.author_affiliation ? r.author[0].affiliation[0].name), first_name: r.author[0].family, last_name: r.author[0].given}, API.settings.service.openaccessbutton.hunter.api_key
            if email?.email?
              n.email = email.email
        oab_request.update(r._id,n) if JSON.stringify(n) isnt '{}'
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

API.add 'service/oab/supports',
  get: () -> return oab_support.search this.queryParams
  post: () -> return oab_support.search this.bodyParams

API.add 'service/oab/availabilities',
  csv: true
  post: 'get'
  get: () -> return oab_availability.search this.queryParams ? this.bodyParams

API.add 'service/oab/requests',
  csv: true
  post: 'get'
  get: () -> return oab_request.search this.queryParams ? this.bodyParams

API.add 'service/oab/history',
  get: () -> return oab_request.history this.queryParams
  post: () -> return oab_request.history this.bodyParams

API.add 'service/oab/users',
  get:
    roleRequired:'openaccessbutton.admin'
    action: () -> return Users.search this.queryParams, {restrict:[{exists:{field:'roles.openaccessbutton'}}]}
  post:
    roleRequired:'openaccessbutton.admin'
    action: () -> return Users.search this.bodyParams, {restrict:[{exists:{field:'roles.openaccessbutton'}}]}

API.add 'service/oab/scrape',
  get:
    #roleRequired:'openaccessbutton.user'
    action: () -> return {data:API.service.oab.scrape(this.queryParams.url,this.queryParams.content,this.queryParams.doi)}

API.add 'service/oab/redirect',
  get: () -> return API.service.oab.redirect this.queryParams.url

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

API.add 'service/oab/receive/:rid',
  get: () -> return if r = oab_request.find({receiver:this.urlParams.rid}) then r else 404
  post:
    authOptional: true
    action: () ->
      if r = oab_request.find {receiver:this.urlParams.rid}
        admin = this.bodyParams.admin and this.userId and API.accounts.auth('openaccessbutton.admin',this.user)
        return API.service.oab.receive this.urlParams.rid, this.request.files, this.bodyParams.url, this.bodyParams.title, this.bodyParams.description, this.bodyParams.firstname, this.bodyParams.lastname, undefined, admin
      else
        return 404

API.add 'service/oab/redeposit/:rid',
  post:
    roleRequired: 'openaccessbutton.admin'
    action: () -> return API.service.oab.redeposit this.urlParams.rid

API.add 'service/oab/receive/:rid/:holdrefuse',
  get: () ->
    if r = oab_request.find {receiver:this.urlParams.rid}
      if this.urlParams.holdrefuse is 'refuse'
        API.service.oab.refuse r._id, this.queryParams.reason
      else
        if isNaN(parseInt(this.urlParams.holdrefuse))
          return 400
        else
          API.service.oab.hold r._id, parseInt(this.urlParams.holdrefuse)
      return true
    else
      return 404

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
    refuse = if this.queryParams.refuse in ['false',false] then false else true
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

API.add 'service/oab/import',
  post:
    roleRequired: 'openaccessbutton.admin', # later could be opened to other oab users, with some sort of quota / limit
    action: () ->
      try
        records = this.request.body
        resp = {found:0,updated:0,missing:[]}
        updates = []
        for p in this.request.body
          if p._id
            rq = oab_request.get p._id
            if rq
              resp.found += 1
              update = {}
              for up of p
                if (not p[up]? or p[up]) and p[up] not in ['createdAt','created_date','plugin','from','embedded','names','count','receiver']
                  if up.indexOf('refused.') is 0 and up isnt 'refused.date' and (not rq[up]? or rq[up].length isnt p[up].split(',').length)
                    rq.refused ?= []
                    added = false
                    for eml in p[up].split(',')
                      eml = eml.trim()
                      add = true
                      for ref in rq.refused
                        add = ref.email isnt eml
                      if add
                        added = true
                        rq.refused.push {email: eml, date: Date.now()}
                    if added
                      update.refused = rq.refused
                  else if up.indexOf('received.') is 0 and ( not rq.received? or rq.received[up.split('.')[1]] isnt p[up] )
                    rq.received ?= {}
                    rq.received[up.split('.')[1]] = p[up]
                    update.received = rq.received
                  else if up.indexOf('followup.') is 0 and up isnt 'followup.date' and p['followup.count'] isnt rq.followup?.count
                    rq.followup ?= {}
                    rq.followup.count = p['followup.count']
                    rq.followup.date ?= []
                    rq.followup.date.push moment(Date.now(), "x").format "YYYYMMDD"
                    update.followup = rq.followup
                  else if up is 'sherpa.color' and ( not rq.sherpa? or rq.sherpa.color isnt p[up] )
                    rq.sherpa ?= {}
                    rq.sherpa.color = p[up]
                    update.sherpa = rq.sherpa
                  else if up.indexOf('user.') is -1 and rq[up] isnt p[up]
                    rq[up] = p[up]
                    update[up] = rq[up]
              if not _.isEmpty update
                try
                  rq._bulk_import ?= {}
                  rq._bulk_import[Date.now()] = JSON.stringify update
                rq.updatedAt = Date.now()
                rq.updated_date = moment(rq.updatedAt, "x").format "YYYY-MM-DD HHmm.ss"
                updates.push rq
                resp.updated += 1
            else
              resp.missing.push p._id
        if updates.length
          resp.imports = oab_request.import(updates)
        return resp
      catch err
        return {status:'error'}

API.add 'service/oab/export/:what',
  get:
    roleRequired: 'openaccessbutton.admin',
    action: () ->
      results = []
      fields = if this.urlParams.what is 'changes' then ['_id','createdAt','created_date','action'] else if this.urlParams.what is 'request' then ['_id','created_date','type','count','status','title','url','doi','journal','publisher','sherpa.color','name','names','email','author_affiliation','user.username','user.email','user.firstname','user.lastname','story','rating','receiver','followup.count','followup.date','refused.email','refused.date','received.date','received.from','received.description','received.url','received.admin','received.cron','received.notfromauthor','notes','plugin','from','embedded'] else []
      match = {}
      match.range = {createdAt: {}} if this.queryParams.from or this.queryParams.to
      match.range.createdAt.gte = this.queryParams.from if this.queryParams.from
      match.range.createdAt.lte = parseInt(this.queryParams.to) + 86400000 if this.queryParams.to
      if this.urlParams.what is 'dnr' or this.urlParams.what is 'mail' or this.urlParams.what is 'request'
        results = if this.urlParams.what is 'dnr' then oab_dnr.fetch(match, true) else if this.urlParams.what is 'request' then oab_request.fetch(match, true) else mail_progress.fetch match, true
        for r of results
          if this.urlParams.what isnt 'request'
            for f of results[r]
              fields.push(f) if fields.indexOf(f) is -1
          else
            results[r].names = []
            if results[r].author?
              for a in results[r].author
                if a.family
                  results[r].names.push a.given + ' ' + a.family
      else if this.urlParams.what is 'changes'
        res = oab_request.fetch_history match, true
        for r in res
          m = {
            action: r.action,
            _id: r.document,
            createdAt: r.createdAt,
            created_date: r.created_date
          }
          if r.action
            for mr of r[r.action]
              fields.push(mr) if fields.indexOf(mr) is -1
              m[mr] = r[r.action][mr]
          if r.string
            fields.push('string') if fields.indexOf('string') is -1
            m.string = r.string
          results.push m
      csv = API.convert.json2csv {fields:fields}, undefined, results

      this.response.writeHead(200, {
        'Content-disposition': "attachment; filename=export_"+this.urlParams.what+".csv",
        'Content-type': 'text/csv; charset=UTF-8',
        'Content-Encoding': 'UTF-8'
      })
      this.response.end(csv)

API.add 'service/oab/terms/:type/:key', get: () -> return API.es.terms 'oab', this.urlParams.type, this.urlParams.key
API.add 'service/oab/min/:type/:key', get: () -> return API.es.min 'oab', this.urlParams.type, this.urlParams.key
API.add 'service/oab/max/:type/:key', get: () -> return API.es.max 'oab', this.urlParams.type, this.urlParams.key
API.add 'service/oab/range/:type/:key', get: () -> return API.es.range 'oab', this.urlParams.type, this.urlParams.key
API.add 'service/oab/keys/:type', get: () -> return API.es.keys 'oab', this.urlParams.type

API.add 'service/oab/job',
  get:
    action: () ->
      jobs = job_job.search({service:'openaccessbutton'},{size:1000,newest:true}).hits.hits
      for j of jobs
        jobs[j] = jobs[j]._source
        ju = API.accounts.retrieve jobs[j].user
        jobs[j].email = ju?.emails[0].address
        jobs[j].processes = if jobs[j].processes? then jobs[j].processes.length else 0
      return jobs
  post:
    roleRequired: 'openaccessbutton.user'
    action: () ->
      processes = this.request.body.processes ? this.request.body
      for p in processes
        p.plugin = this.request.body.plugin ? 'bulk'
        p.libraries = this.request.body.libraries if this.request.body.libraries?
        p.sources = this.request.body.sources if this.request.body.sources?
        p.all = this.request.body.all ?= false
        p.refresh = 0 if this.request.body.refresh
        p.titles = this.request.body.titles ?= true
      job = API.job.create {refresh:this.request.body.refresh, complete:'API.service.oab.job_complete', user:this.userId, service:'openaccessbutton', function:'API.service.oab.find', name:(this.request.body.name ? "oab_availability"), processes:processes}
      API.service.oab.job_started job
      return job

API.add 'service/oab/job/generate/:start/:end',
  post:
    roleRequired: 'openaccessbutton.admin'
    action: () ->
      start = moment(this.urlParams.start, "DDMMYYYY").valueOf()
      end = moment(this.urlParams.end, "DDMMYYYY").endOf('day').valueOf()
      processes = oab_request.find 'NOT status.exact:received AND createdAt:>' + start + ' AND createdAt:<' + end
      if processes.length
        procs = []
        for p in processes
          pro = {url:p.url}
          pro.libraries = this.request.body.libraries if this.request.body.libraries?
          pro.sources = this.request.body.sources if this.request.body.sources?
          procs.push(pro)
        name = 'sys_requests_' + this.urlParams.start + '_' + this.urlParams.end
        jid = API.job.create {complete:'API.service.oab.job_complete', user:this.userId, service:'openaccessbutton', function:'API.service.oab.find', name:name, processes:procs}
        return {job:jid, count:processes.length}
      else
        return {count:0}

API.add 'service/oab/job/:jid/progress', get: () -> return API.job.progress this.urlParams.jid

API.add 'service/oab/job/:jid/reload',
  get:
    roleRequired: 'openaccessbutton.admin'
    action: () ->
      return API.job.reload this.urlParams.jid

API.add 'service/oab/job/:jid/remove',
  get:
    roleRequired: 'openaccessbutton.admin'
    action: () ->
      return API.job.remove this.urlParams.jid

API.add 'service/oab/job/:jid/request',
  get:
    roleRequired: 'openaccessbutton.admin'
    action: () ->
      results = API.job.results this.urlParams.jid
      identifiers = []
      for r in results
        if r.availability.length is 0 and r.requests.length is 0
          rq = {}
          if r.match
            if r.match.indexOf('TITLE:') is 0
              rq.title = r.match.replace('TITLE:','')
            else if r.match.indexOf('CITATION:') isnt 0
              rq.url = r.match
          if r.meta and r.meta.article
            if r.meta.article.doi
              rq.doi = r.meta.article.doi
              rq.url ?= 'https://doi.org/' + r.meta.article.doi
            rq.title ?= r.meta.article.title
          if rq.url
            rq.story = this.queryParams.story ? ''
            created = API.service.oab.request rq, this.userId
            identifiers.push(created) if created
      return identifiers

API.add 'service/oab/job/:jid/results', get: () -> return API.job.results this.urlParams.jid
API.add 'service/oab/job/:jid/results.json', get: () -> return API.job.results this.urlParams.jid
API.add 'service/oab/job/:jid/results.csv',
  get: () ->
    res = API.job.results this.urlParams.jid, true
    inputs = []
    csv = '"MATCH",'
    csv += '"BING","REVERSED",' if API.settings.dev
    csv += '"AVAILABLE","SOURCE","REQUEST","TITLE","DOI"'
    liborder = []
    sources = []
    extras = []
    if res.length and res[0].args?
      jargs = JSON.parse res[0].args
      if jargs.libraries?
        for l in jargs.libraries
          liborder.push l
          csv += ',"' + l.toUpperCase() + '"'
      if jargs.sources
        sources = jargs.sources
        for s in sources
          csv += ',"' + s.toUpperCase() + '"'
      for er in res
        if er.args?
          erargs = JSON.parse er.args
          for k of erargs
            extras.push(k) if k.toLowerCase() not in ['refresh','library','libraries','sources','plugin','all','titles'] and k not in extras
      if extras.length
        exhd = ''
        exhd += '"' + ex + '",' for ex in extras
        csv = exhd + csv

    for r in res
      row = if r.string then JSON.parse(r.string) else r._raw_result['API.service.oab.find']
      csv += '\n'
      if r.args?
        ea = JSON.parse r.args
        for extra in extras
          csv += '"' + (if ea[extra]? then ea[extra] else '') + '",'
      csv += '"' + (if row.match then row.match.replace('TITLE:','').replace(/"/g,'') + '","' else '","')
      if API.settings.dev
        csv += (if row.meta?.article?.bing then 'Yes' else 'No') + '","'
        csv += (if row.meta?.article?.reversed then 'Yes' else 'No') + '","'
      av = 'No'
      if row.availability?
        for a in row.availability
          av = a.url.replace(/"/g,'') if a.type is 'article'
      csv += av + '","'
      csv += row.meta.article.source if av isnt 'No' and row.meta?.article?.source
      csv += '","'
      rq = ''
      if row.requests
        for re in row.requests
          if re.type is 'article'
            rq = 'https://' + (if API.settings.dev then 'dev.' else '') + 'openaccessbutton.org/request/' + re._id
      csv += rq + '","'
      csv += row.meta.article.title.replace(/"/g,'').replace(/[^\x00-\x7F]/g, "") if row.meta?.article?.title?
      csv += '","'
      csv += row.meta.article.doi if row.meta?.article?.doi
      csv += '"'
      if row.libraries
        for lib in liborder
          csv += ',"'
          js = false
          if lib?.journal?.library
            js = true
            csv += 'Journal subscribed'
          rp = false
          if lib?.repository
            rp = true
            csv += '; ' if js
            csv += 'In repository'
          ll = false
          if lib?.local?.length
            ll = true
            csv += '; ' if js or rp
            csv += 'In library'
          csv += 'Not available' if not js and not rp and not ll
          csv += '"'
      for src in sources
        csv += ',"'
        csv += row.meta.article.found[src] if row.meta?.article?.found?[src]?
        csv += '"'

    job = job_job.get this.urlParams.jid
    name = if job.name then job.name.split('.')[0].replace(/ /g,'_') + '_results' else 'results'
    this.response.writeHead 200,
      'Content-disposition': "attachment; filename="+name+".csv"
      'Content-type': 'text/csv; charset=UTF-8'
      'Content-Encoding': 'UTF-8'
    this.response.end csv


API.add 'service/oab/status', get: () -> return API.service.oab.status()


API.add 'service/oab/embed/:rid', # is this still needed?
  get: () ->
    rid = this.urlParams.rid
    b = oab_request.get rid
    if b
      title = b.title ? b.url
      template = '<div style="width:800px;padding:0;margin:0;"> \
  <div style="padding:0;margin:0;float:left;width:150px;height:200px;background-color:white;border:2px solid #398bc5;;"> \
    <img src="//openaccessbutton.org/static/icon_OAB.png" style="height:100%;width:100%;"> \
  </div> \
  <div style="padding:0;margin:0;float:left;width:400px;height:200px;background-color:#398bc5;;"> \
    <div style="height:166px;"> \
      <p style="margin:2px;color:white;font-size:30px;text-align:center;"> \
        <a target="_blank" href="https://openaccessbutton.org/request/' + rid + '" style="color:white;font-family:Sans-Serif;"> \
          Open Access Button \
        </a> \
      </p> \
      <p style="margin:2px;color:white;font-size:16px;text-align:center;font-family:Sans-Serif;"> \
        Request for content related to the article <br> \
        <a target="_blank" id="oab_article" href="https://openaccessbutton.org/request/' + rid + '" style="font-style:italic;color:white;font-family:Sans-Serif;"> \
        ' + title + '</a> \
      </p> \
    </div> \
    <div style="height:30px;background-color:#f04717;"> \
      <p style="text-align:center;font-size:16px;margin-right:2px;padding-top:1px;"> \
        <a target="_blank" style="color:white;font-family:Sans-Serif;" href="https://openaccessbutton.org/request/' + rid + '"> \
          ADD YOUR SUPPORT \
        </a> \
      </p> \
    </div> \
  </div> \
  <div style="padding:0;margin:0;float:left;width:200px;height:200px;background-color:#212f3f;"> \
    <h1 style="text-align:center;font-size:50px;color:#f04717;font-family:Sans-Serif;" id="oab_counter"> \
    ' + b.count + '</h1> \
    <p style="text-align:center;color:white;font-size:14px;font-family:Sans-Serif;"> \
      people have been unable to access this content, and support this request \
    </p> \
  </div> \
  <div style="width:100%;clear:both;"></div> \
</div>';
      return {statusCode: 200, body: {status: 'success', data: template}}
    else
      return {statusCode: 404, body: {status: 'error', data:'404 not found'}}

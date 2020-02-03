
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
                  if up.indexOf('refused.') is 0
                    if up isnt 'refused.date' and (not rq[up]? or rq[up].length isnt p[up].split(',').length)
                      update.refused = rq.refused ? []
                      for eml in p[up].split(',')
                        eml = eml.trim()
                        add = true
                        for ref in rq.refused
                          add = ref.email isnt eml
                        if add
                          update.refused.push {email: eml, date: Date.now()}
                  else if up.indexOf('received.') is 0
                    if not rq.received? or rq.received[up.split('.')[1]] isnt p[up]
                      update.received = rq.received ? {}
                      update.received[up.split('.')[1]] = p[up]
                  else if up.indexOf('followup.') is 0
                    if up isnt 'followup.date' and p['followup.count'] isnt rq.followup?.count
                      update.followup = rq.followup ? {}
                      update.followup.count = p['followup.count']
                      update.followup.date ?= []
                      update.followup.date.push moment(Date.now(), "x").format "YYYYMMDD"
                  else if up is 'sherpa.color'
                    if not rq.sherpa? or rq.sherpa.color isnt p[up]
                      update.sherpa = rq.sherpa ? {}
                      update.sherpa.color = p[up]
                  else if up.indexOf('user.') is 0
                    if not rq.user? or rq.user[up.split('.')[1]] isnt p[up]
                      update.user = rq.user ? {}
                      update.user[up.split('.')[1]] = p[up]
                  else if rq[up] isnt p[up]
                    update[up] = p[up]
              if not _.isEmpty update
                try
                  update._bulk_import = rq._bulk_import ? {}
                  update._bulk_import[Date.now()] = JSON.stringify update
                update._id = rq._id
                updates.push update
                resp.updated += 1
                if this.queryParams.notify_users
                  try
                    emails = []
                    if rq.user?
                      if rq.user.email?
                        emails.push rq.user.email
                      else if rq.user.id?
                        try
                          u = API.accounts.retrieve rq.user.id
                          emails.push u.emails[0].address
                    try
                      oab_support.each {rid:rq._id}, (s) -> emails.push(s.email) if s.email and s.email not in emails
                    API.service.oab.mail({vars:API.service.oab.vars(rq), template:{filename:'requesters_request_inprogress.html'}, to:emails}) if emails.length
            else
              resp.missing.push p._id
        if updates.length
          resp.updates = oab_request.bulk updates, 'update'
        return resp
      catch err
        return {status:'error'}

API.add 'service/oab/export/:what',
  get:
    roleRequired: 'openaccessbutton.admin',
    action: () ->
      results = []
      fields = []
      if this.urlParams.what is 'changes'
        fields = ['_id','createdAt','created_date','action']
      else if this.urlParams.what is 'request'
        fields = ['_id','created_date','type','count','status','title','url','doi','journal','issn','publisher','published','sherpa.color','name','names','email','author_affiliation','user.username','user.email','user.firstname','user.lastname','user.profession','user.affiliation','story','rating','receiver','followup.count','followup.date','refused.email','refused.date','received.date','received.from','received.description','received.url','received.admin','received.cron','received.notfromauthor','notes','plugin','from','embedded','access_right','embargo_date','access_conditions','license']
      else if this.urlParams.what is 'account'
        fields = ['_id','createdAt','emails.0.address','profile.name','profile.firstname','profile.lastname','service.openaccessbutton.profile.affiliation','service.openaccessbutton.profile.profession','roles.openaccessbutton','username']
      match = {}
      match.range = {createdAt: {}} if this.queryParams.from or this.queryParams.to
      match.range.createdAt.gte = this.queryParams.from if this.queryParams.from
      match.range.createdAt.lte = parseInt(this.queryParams.to) + 86400000 if this.queryParams.to #make searches for a day include that day
      match.range.createdAt.lte += 86400000 if match.range?.createdAt?.lte? and match.range.createdAt.lte > Date.now() # make searches for today definitely cover all of today
      if this.queryParams.filter and this.queryParams.value
        qps = this.queryParams.value.split(',')
        if qps.length > 1
          match.should = []
          for val in qps
            mt = {term: {}}
            mt.term[this.queryParams.filter] = val
            match.should.push mt
        else
          match.term = {}
          match.term[this.queryParams.filter] = this.queryParams.value
      if this.queryParams.stories
          match.must = [{query: {query_string: {query: 'story:*'}}}]

      # ADD A MATCH TO ADD THE OAB ROLE FILTER IF WHAT IS ACCOUNT
      if this.urlParams.what is 'dnr' or this.urlParams.what is 'mail' or this.urlParams.what is 'request'
        results = if this.urlParams.what is 'dnr' then oab_dnr.fetch(match, true) else if this.urlParams.what is 'request' then oab_request.fetch(match, true) else if this.urlParams.what is 'account' then Users.fetch(match,true) else mail_progress.fetch match, true
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
      csv = API.convert.json2csv results, {fields:fields}

      this.response.writeHead(200, {
        'Content-disposition': "attachment; filename=export_"+this.urlParams.what+".csv",
        'Content-type': 'text/csv; charset=UTF-8',
        'Content-Encoding': 'UTF-8'
      })
      this.response.end(csv)

API.add 'service/oab/terms/:type/:key', 
  get: () -> 
    if this.urlParams.type is 'account'
      return Users.terms this.urlParams.key, 'roles.openaccessbutton:*'
    else
      return API.es.terms 'oab', this.urlParams.type, this.urlParams.key, undefined, undefined, false
API.add 'service/oab/min/:type/:key', get: () -> return API.es.min 'oab', this.urlParams.type, this.urlParams.key
API.add 'service/oab/max/:type/:key', get: () -> return API.es.max 'oab', this.urlParams.type, this.urlParams.key
API.add 'service/oab/keys/:type', get: () -> return API.es.keys 'oab', this.urlParams.type
API.add 'service/oab/range/:type/:key', 
  get: () ->
    if this.urlParams.type is 'account'
      return Users.range this.urlParams.key, 'roles.openaccessbutton:*'
    else
      return API.es.range 'oab', this.urlParams.type, this.urlParams.key

API.add 'service/oab/job',
  get:
    action: () ->
      jobs = job_job.search({service:'openaccessbutton'},{_source:{exclude:['processes']},size:1000,newest:true}).hits.hits
      for j of jobs
        jobs[j] = jobs[j]._source
        ju = API.accounts.retrieve jobs[j].user
        jobs[j].email = ju?.emails[0].address
        jobs[j].processes = jobs[j].count
      return jobs
  post:
    roleRequired: 'openaccessbutton.user'
    action: () ->
      maxallowedlength = 15000
      checklength = this.request.body.processes?.length ? this.request.body.length
      if checklength > maxallowedlength
        return 413
      else
        processes = this.request.body.processes ? this.request.body
        for p in processes
          p.plugin = this.request.body.plugin ? 'bulk'
          p.libraries = this.request.body.libraries if this.request.body.libraries?
          p.sources = this.request.body.sources if this.request.body.sources?
          p.all = this.request.body.all ?= false
          p.refresh = 0 if this.request.body.refresh
          p.titles = this.request.body.titles ?= true
          p.bing = this.request.body.bing if this.request.body.bing?
        job = API.job.create {refresh:this.request.body.refresh, complete:'API.service.oab.job_complete', user:this.userId, service:'openaccessbutton', function:'API.service.oab.availability', name:(this.request.body.name ? "oab_find"), processes:processes}
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
        jid = API.job.create {complete:'API.service.oab.job_complete', user:this.userId, service:'openaccessbutton', function:'API.service.oab.availability', name:name, processes:procs}
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
            created = API.service.oab.request rq, this.userId, undefined, false
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
      row = if r.string then JSON.parse(r.string) else if r._raw_result['API.service.oab.find']? then r._raw_result['API.service.oab.find'] else r._raw_result['API.service.oab.availability']
      if row.data?
        for ky of row.data
          row[ky] = row.data[ky]
        delete row.data
      if not row.meta?
        row = API.service.oab.availability undefined, row
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



API.service.oab.job_started = (job) ->
  tmpl = API.mail.template 'bulk_start.html'
  eml = job.email ? API.accounts.retrieve(job.user)?.emails[0].address
  if tmpl
    sub = API.service.oab.substitute tmpl.content, {_id: job._id, useremail: eml, jobname: job.name ? job._id}
    API.mail.send
      service: 'openaccessbutton'
      html: sub.content
      subject: sub.subject
      from: sub.from ? API.settings.service.openaccessbutton.mail.from
      to: eml
  else
    API.mail.send
      service: 'openaccessbutton'
      from: 'help@openaccessbutton.org'
      to: eml
      subject: 'Sheet upload confirmation'
      text: 'Thanks! \n\nYour sheet has been uploaded to Open Access Button. You will hear from us again once processing is complete.\n\nThe Open Access Button Team'

API.service.oab.job_complete = (job) ->
  if not job.email and job.user
    usr = API.accounts.retrieve job.user
    job.email = usr.emails[0].address
  tmpl = API.mail.template 'bulk_complete.html'
  sub = API.service.oab.substitute tmpl.content, {_id: job._id, useremail: job.email, jobname: job.name ? job._id}
  API.mail.send
    service: 'openaccessbutton'
    html: sub.content
    subject: sub.subject
    from: sub.from ? API.settings.service.openaccessbutton.mail.from
    to: job.email


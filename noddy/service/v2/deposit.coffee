
import moment from 'moment'

API.add 'service/oab/deposit',
  get: 
    authOptional: true
    action: () -> 
      return API.service.oab.deposit undefined, this.queryParams
  post: 
    authOptional: true
    action: () -> 
      return API.service.oab.deposit undefined, this.bodyParams, this.request.files

API.add 'service/oab/deposit/:did',
  get: 
    authOptional: true
    action: () -> 
      return API.service.oab.deposit this.urlParams.did, this.queryParams
  post: 
    authOptional: true
    action: () -> 
      return API.service.oab.deposit this.urlParams.did, this.bodyParams, this.request.files

API.add 'service/oab/deposits',
  get:
    authOptional: true
    action: () ->
      restrict = if this.userId or this.queryParams.uid then [{term:{'deposit.from':this.queryParams.uid ? this.userId}}] else [{exists:{field:'deposit.type'}}]
      delete this.queryParams.uid if this.queryParams.uid?
      return oab_catalogue.search this.queryParams, {restrict:restrict}
  post:
    authOptional: true
    action: () ->
      restrict = if this.userId or this.queryParams.uid then [{term:{'deposit.from':this.queryParams.uid ? this.userId}}] else [{exists:{field:'deposit.type'}}]
      delete this.queryParams.uid if this.queryParams.uid?
      return oab_catalogue.search this.bodyParams, {restrict:restrict}

API.add 'service/oab/deposit/config',
  get: 
    authOptional: true
    action: () ->
      try
        return API.service.oab.deposit.config this.queryParams.uid ? this.user._id
      return 404
  post: 
    authRequired: 'openaccessbutton.user'
    action: () ->
      opts = this.request.body ? {}
      for o of this.queryParams
        opts[o] = this.queryParams[o]
      if opts.uid and API.accounts.auth 'openaccessbutton.admin', this.user
        user = API.accounts.retrieve opts.uid
        delete opts.uid
      else
        user = this.user
      return API.service.oab.deposit.config user, opts

# for legacy
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

# for legacy
API.add 'service/oab/receive/:rid/:holdrefuse',
  get: () ->
    if r = oab_request.find {receiver:this.urlParams.rid}
      if this.urlParams.holdrefuse is 'refuse'
        if this.queryParams.email is r.email
          API.service.oab.refuse r._id, this.queryParams.reason
        else
          return 401
      else
        if isNaN(parseInt(this.urlParams.holdrefuse))
          return 400
        else
          API.service.oab.hold r._id, parseInt(this.urlParams.holdrefuse)
      return true
    else
      return 404




API.service.oab.deposit = (d,options={},files) ->
  if typeof d is 'string' # a catalogue ID
    d = oab_catalogue.get d
  else
    d = oab_catalogue.finder(options.metadata) if options.metadata
    if not d?
      fnd = API.service.oab.find d ? options.metadata ? options # this will create a catalogue record out of whatever is provided, and also checks to see if thing is available already
      d = oab_catalogue.get fnd.catalogue
  return 400 if not d?
  
  d.deposit ?= []
  dep = {createdAt: Date.now()}
  dep.created_date = moment(dep.createdAt, "x").format "YYYY-MM-DD HHmm.ss"
  dep.pilot = options.pilot if options.pilot # are pilot and live going to be needed for shareyourpaper?
  dep.live = options.pilot if options.live
  dep.filename = files[0].filename if files? and files.length
  dep.email = options.email if options.email
  # later will test file and permissions and deposit to zenodo if possible
  if options.from
    dep.from = options.from
    dep.type = if options.redeposit then 'redeposit' else if files? and files.length then 'forward' else 'dark'
  else
    dep.type = 'review'
  d.deposit.push dep
  oab_catalogue.update d._id, deposit: d.deposit

  tos = API.settings.service.openaccessbutton.notify.deposit ? ['mark@cottagelabs.com','joe@righttoresearch.org']
  if options.from
    iacc = API.accounts.retrieve options.from
    tos.push iacc.email ? iacc.emails[0].address # the institutional user may set a config value to use as the contact email address but for now it is the account address

  text = 'This is an example email that we will send to an institution for ' + dep.type + ' deposit\n\n'
  text += 'File called ' +  files[0].filename + ' should be attached.\n\n' if files? and files.length
  text += 'Author email to contact: \n' + options.email + '\n\n' if options.email 
  text += 'There is already an open URL for this article at \n' + options.redeposit + '\n\n' if typeof options.redeposit is 'string'
  text += 'METADATA:\n' + JSON.stringify(d.metadata,undefined,2) + '\n\nPERMISSIONS:\n' + JSON.stringify(d.permissions,undefined,2)

  API.service.oab.mail
    from: 'deposits@openaccessbutton.org'
    to: tos
    subject: dep.type + ' deposit'
    text: text
    attachments: (if files? then [{filename: files[0].filename, content: files[0].data}] else undefined)
    #vars: vars # later this may become a template call
    #template: {filename: ''}

  # eventually this could also close any open requests for the same item, but that has not been prioritised to be done yet
  return d

API.service.oab.deposit.config = (user, config) ->
  user = Users.get(user) if typeof user is 'string'
  if config?
    update = {}
    for k in [] # the fields allowed in deposit config will be listed here
      update[k] = config[k] if config[k]?
    if JSON.stringify(update) isnt '{}'
      if not user.service.openaccessbutton.deposit?
        Users.update user._id, {'service.openaccessbutton.deposit': {config: update}}
      else
        Users.update user._id, {'service.openaccessbutton.deposit.config': update}
      user = Users.get user._id
  try
    rs = user.service.openaccessbutton.deposit.config ? {}
    try rs.adminemail = if user.email then user.email else user.emails[0].address
    return rs
  catch
    return {}

# for legacy - remove once refactored request and OAB receive
API.service.oab.receive = (rid,files,url,title,description,firstname,lastname,cron,admin) ->
  r = oab_request.find {receiver:rid}
  description ?= r.description if typeof r.description is 'string'
  description ?= r.received.description if r.received? and typeof r.received.description is 'string'
  if not r
    return 404
  else if (r.received?.url or r.received?.zenodo) and not admin
    return 400
  else
    today = new Date().getTime()
    r.received ?= {}
    r.received.date ?= today
    r.received.from ?= r.email
    r.received.description ?= description
    r.received.validated ?= false
    r.received.admin = admin
    r.received.cron = cron
    up = {}
    if url?
      r.received.url = url
    else
      if files? and files.length > 0
        up.content = files[0].data
        up.name = files[0].filename
      up.publish = API.settings.service.openaccessbutton?.zenodo?.publish or r.received.admin
      creators = []
      if r.names
        try
          r.names = r.names.replace(/\[/g,'').replace(/\]/g,'').split(',') if typeof r.names is 'string'
          for n in r.names
            creators.push {name: n}
      if creators.length is 0
        creators = [{name:(if lastname or firstname then '' else 'Unknown')}]
        creators[0].name = lastname if lastname
        creators[0].name += (if lastname then ', ' else '') + firstname if firstname
        creators[0].name = r.name if creators[0].name is 'Unknown' and r.name
        if creators[0].name is 'Unknown' and r.author
          try
            for a in r.author
              if a.family and ( creators[0].name is 'Unknown' or r.email.toLowerCase().indexOf(a.family.toLowerCase()) isnt -1 )
                creators[0].name = a.family
                creators[0].name += (if a.family then ', ' else '') + a.given if a.given
      # http://developers.zenodo.org/#representation
      # journal_volume and journal_issue are acceptable too but we don't routinely collect those
      # access_right can be open embargoed restricted closed
      # if embargoed can also provide embargo_date
      # can provide access_conditions which is a string sentence explaining what conditions we will allow access for
      # license can be a string specifying the license type for open or embargoed content, using opendefinition license tags like cc-by
      meta =
        title: title ? (if r.title then r.title else (if r.url.indexOf('h') isnt 0 and r.url.indexOf('1') isnt 0 then r.url else 'Unknown')),
        description: description ? "Deposited from Open Access Button",
        creators: creators,
        doi: r.doi,
        keywords: r.keywords,
        version: 'AAM',
        journal_title: r.journal
      if API.settings.service.openaccessbutton?.zenodo?.prereserve_doi and not r.doi?
        meta.prereserve_doi = true # do this differently as sending false may still have been causing zenodo to give us a doi...
      try meta['access_right'] = r['access_right'] if typeof r['access_right'] is 'string' and r['access_right'] in ['open','embargoed','restricted','closed']
      try meta['embargo_date'] = r['embargo_date'] if r['embargo_date']? and meta['access_right'] is 'embargoed'
      try meta['access_conditions'] = r['access_conditions'] if typeof r['access_conditions'] is 'string'
      try meta.license = r.license if typeof r.license is 'string'
      try meta['publication_date'] = r.published if r.published? and typeof r.published is 'string' and r.length is 10
      z = API.use.zenodo.deposition.create meta, up, API.settings.service.openaccessbutton?.zenodo?.token
      r.received.zenodo = 'https://zenodo.org/record/' + z.id if z.id
      r.received.zenodo_doi = z.metadata.prereserve_doi.doi if z.metadata?.prereserve_doi?.doi?
        
    oab_request.update r._id, {hold:'$DELETE',received:r.received,status:(if up.publish is false and not r.received.url? then 'moderate' else 'received')}
    API.service.oab.admin(r._id,'successful_upload') if up.publish
    API.mail.send
      service: 'openaccessbutton'
      from: 'requests@openaccessbutton.org'
      to: API.settings.service.openaccessbutton.notify.receive
      subject: 'Request ' + r._id + ' received' + (if r.received.url? then ' - URL provided' else (if up.publish then ' - file published on Zenodo' else ' - zenodo publish required'))
      text: (if API.settings.dev then 'https://dev.openaccessbutton.org/request/' else 'https://openaccessbutton.org/request/') + r._id
    return {data: r}

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


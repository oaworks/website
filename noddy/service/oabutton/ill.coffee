

# ill development is on hold - keep this as is for now

API.service.oab.library = (opts) ->
  library = {institution:opts.library,primo:{}}
  meta = {}
  if opts.url.indexOf('TITLE:') is 0 and opts.url.indexOf('CITATION:') is 0
    check = API.use.crossref.reverse(opts.url.replace('CITATION:',''))
    if check.data?.doi
      meta = API.service.oab.scrape('https://doi.org/' + check.data.doi)
    else if opts.url.indexOf('TITLE:') is 0
      meta.title = opts.url.replace('TITLE:','')
  else
    meta = API.service.oab.scrape opts.url, opts.dom
  if meta.title
    library.title = meta.title
    tqr = 'title,exact,'+meta.title.replace(/ /g,'+')
    lib = API.use.exlibris.primo tqr, undefined, undefined, opts.library
    if lib.data?.length > 0
      library.primo.title = {query:tqr,result:lib.data}
      library.local = []
      for l in lib.data
        if l.library and l.type isnt 'video'
          library.local.push lib.data[l]
          library.repository ?= l
  if meta.journal
    # exlibris may only tell us they have access to the journal, not every article. So if not found do a check for journal availability
    library.journal = {title:meta.journal}
    jqr = 'rtype,exact,journal&query=swstitle,begins_with,'+meta.journal.replace(/ /g,'+')+'&sortField=stitle'
    jrnls = API.use.exlibris.primo jqr, undefined, 50, opts.library
    if jrnls.data?.length
      library.primo.journal = {query:jqr,result:jrnls.data}
      for jrnl in jrnls.data
        inj = library.journal.title.split(' [')[0].toLowerCase().replace(/[^a-z]/g,''); # York results had [Electronic resource] in the titles, so split there
        rnj = jrnl.title.split(' [')[0].toLowerCase().replace(/[^a-z]/g,'');
        if rnj.indexOf(inj) is 0 and rnj.length < inj.length+3 # and jrnl.library
          if jrnl.library
            library.journal = jrnl
          else
            library.journal.library = true
          break
  return library

API.service.oab.libraries = (opts) ->
  libs = {}
  for l in opts.libraries
    opts.library = opts.libraries[l]
    libs[opts.library] = API.service.oab.library opts
  return libs

API.service.oab.ill = {}

API.service.oab.ill.start = (opts={}) ->
  # opts should include a key called metadata at this point containing all metadata known about the object
  # but if not, and if needed for the below stages, it is looked up again using the ill.metadata function below
  opts.metadata ?= {}
  meta = API.service.oab.ill.metadata opts.metadata, opts
  for m of meta
    opts.metadata[m] ?= meta[m]
    
  if opts.library is 'imperial'
    # TODO for now we are just going to send an email when a user creates an ILL
    # until we have a script endpoint at the library to hit
    # library POST URL: https://www.imperial.ac.uk/library/dynamic/oabutton/oabutton3.php
    if not opts.forwarded
      API.mail.send {
        service: 'openaccessbutton',
        from: 'requests@openaccessbutton.org',
        to: ['mark@cottagelabs.com','joe@righttoresearch.org','s.barron@imperial.ac.uk'],
        subject: 'EXAMPLE ILL TRIGGER',
        text: JSON.stringify(opts,undefined,2)
      }
      API.service.oab.mail({template:{filename:'imperial_confirmation_example.txt'},to:opts.id})
      HTTP.call('POST','https://www.imperial.ac.uk/library/dynamic/oabutton/oabutton3.php',{data:opts})
    return oab_ill.insert opts

  else if opts.from?
    user = API.accounts.retrieve opts.from
    if user?
      vars = {}
      vars.name = user.profile?.firstname ? 'librarian'
      vars.details = ''
      for o of opts
        if o is 'metadata'
          for m of opts[o]
            if opts[o][m]
              vars[m] = opts[o][m]
              if m is 'author'
                authors = '<p>Authors:<br>'
                first = true
                for a in opts[o][m]
                  if first
                    first = false
                  else
                    authors += ', '
                  authors += a.family + ' ' + a.given
                vars.details += authors + '</p>'
              else if ['started','ended','took'].indexOf(m) is -1
                vars.details += '<p>' + m + ':<br>' + opts[o][m] + '</p>'
        else if opts[o]
          vars[o] = opts[o]
          #vars.details += '<p>' + o + ':<br>' + opts[o] + '</p>'
      vars.illid = oab_ill.insert opts
      vars.details += '<p>Open access button ILL ID:<br>' + vars.illid + '</p>';
      eml = if user.service?.openaccessbutton?.ill?.config?.email and user.service?.openaccessbutton?.ill?.config?.email.length then user.service?.openaccessbutton?.ill?.config?.email else if user.email then user.email else user.emails[0].address

      if not opts.forwarded
        API.service.oab.mail({vars: vars, template: {filename:'instantill_create.html'}, to: eml, from: "InstantILL <InstantILL@openaccessbutton.org>", subject: "ILL request " + vars.illid})
      
      # send msg to mark and joe for testing (can be removed later)
      txt = vars.details
      delete vars.details
      txt += '<br><br>' + JSON.stringify(vars,undefined,2)
      API.mail.send {
        service: 'openaccessbutton',
        from: 'InstantILL <InstantILL@openaccessbutton.org>',
        to: ['mark@cottagelabs.com','joe@righttoresearch.org'],
        subject: 'ILL CREATED',
        html: txt,
        text: txt
      }
      
      return vars.illid
    else
      return 401
  else
    return 404

API.service.oab.ill.config = (user, config) ->
  # need to set a config on live for the IUPUI user ajrfnwswdr4my8kgd
  # the URL params they need are like
  # https://ill.ulib.iupui.edu/ILLiad/IUP/illiad.dll?Action=10&Form=30&sid=OABILL&genre=InstantILL&aulast=Sapon-Shevin&aufirst=Mara&issn=10478248&title=Journal+of+Educational+Foundations&atitle=Cooperative+Learning%3A+Liberatory+Praxis+or+Hamburger+Helper&volume=5&part=&issue=3&spage=5&epage=&date=1991-07-01&pmid
  # and their openurl config https://docs.google.com/spreadsheets/d/1wGQp7MofLh40JJK32Rp9di7pEkbwOpQ0ioigbqsufU0/edit#gid=806496802
  # tested it and set values as below defaults, but also noted that it has year and month boxes, but these do not correspond to year and month params, or date params
  if config?
    update = {}
    for k in ['ill_redirect_base_url','ill_redirect_params','method','title','doi','pmid','pmcid','author','journal','issn','volume','issue','page','published','year','terms','book','other','cost','time','email']
      update[k] = config[k] if config[k]?
    if not user.service.openaccessbutton.ill?
      Users.update user._id, {'service.openaccessbutton.ill': {config: update}}
    else
      Users.update user._id, {'service.openaccessbutton.ill.config': update}
    return true
  else
    try
      user = Users.get(user) if typeof user is 'string'
      return user.service.openaccessbutton.ill.config ? {}
    catch
      return {}

API.service.oab.ill.openurl = (uid, meta={}) ->
  config = API.service.oab.ill.config uid
  config ?= {}
  # add iupui / openURL defaults to config
  defaults =
    title: 'atitle' # this is what iupui needs (title is also acceptable, but would clash with using title for journal title, which we set below, as iupui do that
    doi: 'rft_id' # don't know yet what this should be
    #pmid: 'pmid' # same as iupui ill url format
    pmcid: 'pmcid' # don't know yet what this should be
    #aufirst: 'aufirst' # this is what iupui needs
    #aulast: 'aulast' # this is what iupui needs
    author: 'aulast' # author should actually be au, but aulast works even if contains the whole author, using aufirst just concatenates
    journal: 'title' # this is what iupui needs
    #issn: 'issn' # same as iupui ill url format
    #volume: 'volume' # same as iupui ill url format
    #issue: 'issue' # same as iupui ill url format
    #spage: 'spage' # this is what iupui needs
    #epage: 'epage' # this is what iupui needs
    page: 'pages' # iupui uses the spage and epage for start and end pages, but pages is allowed in openurl, check if this will work for iupui
    published: 'date' # this is what iupui needs, but in format 1991-07-01 - date format may be a problem
    year: 'rft.year' # this is what IUPUI uses
    # IUPUI also has a month field, but there is nothing to match to that
  for d of defaults
    config[d] = defaults[d] if not config[d]
  if not config?.ill_redirect_base_url
    return ''
  else
    url = config.ill_redirect_base_url
    url += if url.indexOf('?') is -1 then '?' else '&'
    url += config.ill_redirect_params.replace('?','') + '&' if config.ill_redirect_params
    for k of meta
      v = false
      if k is 'author'
        # need to check if config has aufirst and aulast or something similar, then need to use those instead, 
        # if we have author name parts
        try
          if typeof meta.author is 'string'
            v = meta.author
          else if _.isArray meta.author
            v = ''
            for author in meta.author
              v += ', ' if v.length
              if typeof author is 'string'
                v += author
              else if author.family
                v += author.family + if author.given then ', ' + author.given else ''
          else
            if meta.author.family
              v = meta.author.family + if meta.author.given then ', ' + meta.author.given else ''
            else
              v = JSON.stringify meta.author
      else if k not in ['started','ended','took','terms','book','other','cost','time','email']
        v = meta[k]
      if v
        url += (if config[k] then config[k] else k) + '=' + v + '&'
    return url
    
API.service.oab.ill.terms = (uid) ->
  config = API.service.oab.ill.config uid
  return config.terms
  
API.service.oab.ill.metadata = (metadata={}, opts={}) ->
  metadata.started ?= Date.now()
  # metadata is whatever we already happened to find when doing availability or other checks
  # opts is whatever was passed to the "find" check such as the plugin type (only instantill in this case), use ID, embedded location, etc
  # build a more complete picture of item metadata for ILLs, from any sources possible
  # we want as many of DOI, title, pmid, pmcid, journal, issn, author(s), publication date (full, not just year, where possible), volume, issue, page
  # need to look them up here and possibly also try to add them in with earlier find stages, anywhere that they may already be present in something we looked up anyway

  want = ['title','doi','pmid','pmcid','author','journal','issn','volume','issue','page','published','year']
  _got = () ->
    for w in want
      if not metadata[w]
        return false
    return true

  metadata.q ?= opts.q if opts.q
  metadata.doi ?= opts.doi if opts.doi
  metadata.title ?= opts.title if opts.title
  metadata.title ?= opts.citation if opts.citation
  metadata.pmid ?= opts.pmid if opts.pmid
  metadata.pmid ?= opts.pmcid if opts.pmcid
  if metadata.q
    metadata.url ?= metadata.q
    delete metadata.q
  if metadata.id
    metadata.url ?= metadata.id
    delete metadata.id
  if metadata.citation
    metadata.title ?= metadata.citation
    delete metadata.citation
  if metadata.url
    if metadata.url.indexOf('10.') is 0
      metadata.doi ?= metadata.url
      metadata.url = 'https://doi.org/' + metadata.url
    else if metadata.url.toLowerCase().indexOf('pmc') is 0
      metadata.pmcid ?= metadata.url.toLowerCase().replace('pmc','')
      metadata.url = 'http://europepmc.org/articles/PMC' + metadata.pmcid
    else if metadata.url.length < 10 and metadata.url.indexOf('.') is -1 and not isNaN(parseInt(metadata.url))
      metadata.pmid ?= metadata.url
      metadata.url = 'https://www.ncbi.nlm.nih.gov/pubmed/' + metadata.pmid
    else if not metadata.title? and metadata.url.indexOf('http') isnt 0 and metadata.url.toLowerCase().indexOf('citation:') isnt 0
      metadata.title = metadata.url
    delete metadata.url if metadata.url.indexOf('http') isnt 0 or metadata.url.indexOf('.') is -1
  delete metadata.doi if metadata.doi and metadata.doi.indexOf('10.') isnt 0

  if not _got() and not metadata.doi and not opts.scraped and metadata.url
    s = API.service.oab.scrape metadata.url
    try
      for w in want
        metadata[w] ?= s[w]
    
  if not _got() and metadata.doi
    cr = API.service.oab.crossref metadata.doi
    try
      for w in want
        metadata[w] ?= cr[w]

  epmc = false
  if not _got() and (metadata.doi or metadata.pmid or metadata.pmcid or metadata.title)
    eids = []
    eids.push(metadata.doi) if metadata.doi
    eids.push(metadata.pmid) if metadata.pmid
    eids.push(metadata.pmcid) if metadata.pmcid
    eids.push(metadata.title) if metadata.title
    for eid in eids
      epmc = API.service.oab.europepmc(eid) if epmc is false or not _.keys(epmc).length
    try
      for w in want
        metadata[w] ?= epmc[w]

  if not _got() and metadata.title? and not opts.reversed?
    cit = API.service.oab.citation metadata
    try
      for w in want
        metadata[w] ?= cit[w]

  # do not use this for now as pmid and pmcid are not critical yet
  '''if not _got() and epmc is false and not metadata.pmid and not metadata.pmcid and (metadata.doi or metadata.title)
    epmc = API.service.oab.europepmc metadata.doi ? metadata.title
    epmc = API.service.oab.europepmc(metadata.title) if metadata.title and (epmc is false or not _.keys(epmc).length)
    try
      for w in want
        metadata[w] ?= epmc[w]'''

  want = _.without want, 'pmcid', 'pmid' # there is no other way we will find these after the above is done

  if not _got() and metadata.doi
    dr = API.service.oab.resolve metadata, undefined, ['core','openaire','doaj'], true, false, true, true, true
    try
      for w in want
        metadata[w] ?= dr[w]
    
  if not _got() and metadata.title?
    pretitledoi = metadata.doi
    delete metadata.doi
    tr = API.service.oab.resolve metadata, undefined, ['core','openaire','doaj'], true, true, true, true, true
    metadata.doi = pretitledoi
    try
      for w in want
        metadata[w] ?= tr[w]

  for k of metadata
    if k not in want and k not in ['pmid','pmcid'] and k not in ['started','ended','took']
      delete metadata[k]
  metadata.ended ?= Date.now()
  metadata.took ?= metadata.ended - metadata.started
  return metadata
  
API.service.oab.ill.progress = () ->
  # TODO need a function that can lookup ILL progress from the library systems some how
  return
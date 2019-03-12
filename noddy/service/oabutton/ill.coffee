

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
      vars.details = '' # this should build an html chunk that lists all the necessary values... for now just dump them all in
      for o of opts
        if o is 'metadata'
          for m of opts[o]
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
            else if opts[o][m]
              vars.details += '<p>' + m + ':<br>' + opts[o][m] + '</p>'
        else if opts[o]
          vars[o] = opts[o]
          vars.details += '<p>' + o + ':<br>' + opts[o] + '</p>'
      vars.illid = oab_ill.insert opts
      API.service.oab.mail({vars: vars, template: {filename:'instantill_create.html'}, to: user.emails[0].address, from: "InstantILL@openaccessbutton.org", subject: "ILL request " + vars.illid})
      API.mail.send {
        service: 'openaccessbutton',
        from: 'instantill@openaccessbutton.org',
        to: ['mark@cottagelabs.com','joe@righttoresearch.org'],
        subject: 'ILL CREATED',
        text: JSON.stringify(vars,undefined,2)
      }
      return vars.illid
    else
      return 401
  else
    return 404

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
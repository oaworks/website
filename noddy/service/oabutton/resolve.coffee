

import request from 'request'

API.service.oab.citation = (meta) ->
  if not meta.title and meta.url
    meta.url = meta.url.replace('CITATION:','').replace('TITLE:','').trim()
    if meta.url.indexOf('{') is 0 or meta.url.indexOf('[') is 0 # look for dumped citation styles
      try
        ji = JSON.parse meta.url
        if ji.title
          meta.title = ji.title
        else
          for i in ji
            meta.title = i.title if i.title and not meta.title
    else
      meta.url = if meta.url.indexOf('title') isnt -1 then meta.url.split('title')[1].trim() else meta.url.trim()
      ti
      if meta.url.indexOf('|') isnt -1
        ti = meta.url.split('|')[0].trim()
      else if meta.url.indexOf('}') isnt -1
        ti = meta.url.split('}')[0].trim()
      else if meta.url.indexOf('"') isnt -1 || meta.url.indexOf('"') isnt -1
        w
        p = 0
        if meta.url.indexOf('"') isnt -1
          w = '"'
          p = meta.url.indexOf('"')
        w = "'" if meta.url.indexOf("'") isnt -1 and meta.url.indexOf("'") < p
        parts = meta.url.split w
        for pp in parts
          tp = pp.toLowerCase().replace(/(<([^>]+)>)/g,'').replace(/[^a-z0-9]/g,' ').trim()
          ti = tp if tp.length > 5
      if ti
        meta.title = ti.replace(/(<([^>]+)>)/g,'').trim()

  meta.title = meta.title.replace('CITATION:','').replace('TITLE:','') if meta.title?
  check = API.use.crossref.reverse(meta.title ? meta.url)
  if check.data and check.data.doi
    meta.doi = check.data.doi
    meta.title = check.data.title
    meta.journal = check.data?['container-title']?[0]

  return meta

API.service.oab.resolve = (meta,content,sources,all=false,titles=true,journal=true) ->
  API.log msg: 'Resolving academic content', meta: meta, sources: sources, level: 'debug'
  sources ?= ['oabutton','eupmc','oadoi','base','dissemin','share','core','openaire','figshare','doaj']
  # all source get checked by default (but oabutton availability overrides to not botehr with base and dissemin as covered by oadoi)
  # NOTE crossref does also get used to lookup DOIs from title/citation if necessary, but this is not considered a source in this context
  meta = {url:meta} if typeof meta is 'string'
  meta.all = if all is false then false else all?
  meta.sources = sources
  meta.found = {}
  meta.checked = {identifiers:[],titles:[]}
  meta.original = meta.url

  if not meta.pmid
    lurl = meta.url.toLowerCase()
    if lurl.indexOf('pubmed/') isnt -1
      meta.pmid = lurl.substring((lurl.indexOf('pubmed/')+7)).split('/')[0].split('#')[0].split('?')[0]
    else if lurl.indexOf('pubmedid=') isnt -1
      meta.pmid = lurl.substring((lurl.indexOf('pubmedid=')+9)).split('/')[0].split('#')[0].split('?')[0]
    else if lurl.replace('pmid','').length <= 8 and not isNaN(parseInt(lurl.replace('pmid','')))
      meta.pmid = lurl.replace('pmid','')
    meta.url = 'https://www.ncbi.nlm.nih.gov/pubmed/' + meta.pmid if meta.pmid

  if not meta.pmc
    lurl = meta.url.toLowerCase()
    if lurl.indexOf('/pmc') isnt -1
      meta.pmc = lurl.substring((lurl.indexOf('/pmc')+4)).split('/')[0].split('#')[0].split('?')[0]
    else if lurl.indexOf('pmc') is 0
      meta.pmc = lurl.replace('pmc','')
    meta.url = 'http://europepmc.org/articles/PMC' + meta.pmc.toLowerCase().replace('pmc','') if meta.pmc

  if not meta.doi and (meta.url.indexOf('10.') is 0 or meta.url.indexOf('doi.org') isnt -1)
    meta.doi = '10.' + meta.url.split('10.')[1]
    meta.url = 'https://doi.org/' + meta.doi if meta.doi

  if 'oabutton' in sources
    oabr = oab_request.find {type:'article',url:meta.url,status:'received'}
    meta.checked.identifiers.push 'oabutton'
    if oabr
      meta.source ?= 'oabutton'
      meta.title = oabr.title
      meta.journal = oabr.journal
      meta.url = oabr.received.url ? oabr.received.zenodo ? oabr.received.osf
      meta.found.oabutton = meta.url
      return meta if not all # we can end here, oab already had it

  if not meta.doi and meta.url.indexOf('http') isnt 0 and meta.url.indexOf('10.') isnt 0 and meta.url.toLowerCase().indexOf('pmc') isnt 0 and meta.url.length > 8
    meta = API.service.oab.citation meta

  if (meta.pmid or meta.pmc) and 'eupmc' in sources
    try
      API.log msg: 'Resolve checking with EUPMC for PMC/PMID', level: 'debug'
      res = if meta.pmc then API.use.europepmc.pmc(meta.pmc) else API.use.europepmc.pmid(meta.pmid)
      meta.checked.identifiers.push 'eupmc'
      meta.title ?= res?.title
      meta.journal = res?.journal?.title?.split('(')[0].trim()
      meta.doi ?= res?.doi
      if res?.url
        meta.source ?= 'eupmc'
        meta.url = if res.redirect then res.redirect else res.url
        meta.found.eupmc = res.url
        return meta if not all and res.redirect isnt false

  if not meta.doi and meta.url.indexOf('http') is 0 and not meta.pmid and not meta.pmc
    # no point resolving for URL if we already had these, the splash pages would not contain a DOI if the eupmc API did not have it
    API.log 'Resolving URL for content'
    # this can be SLOW, avoid at all costs - but is better to do this and maybe get a DOI than to search for titles?
    content ?= API.http.phantom meta.url
    # TODO could check content for <meta name="citation_fulltext_html_url" content="" />
    # If it is not the current page, is it worth resolving to it? If it is accessible, can it be taken as the open URL?
    scraped = API.service.oab.scrape(meta.url, content)
    for ks of scraped
      meta[ks] = scraped[ks] if not meta[ks]?

  meta.url = undefined if meta.url is meta.original

  if meta.doi
    API.log 'Resolving for DOI', doi: meta.doi
    for src in sources
      if src isnt 'oabutton' and (src isnt 'eupmc' or (not meta.pmid and not meta.pmc)) # because we try eupmc directly earlier if these are present, so don't run again
        try
          # will only work for use endpoints that provide a doi method
          res = if src is 'doaj' then API.use[src].articles.doi(meta.doi) else API.use[src].doi meta.doi
          meta.checked.identifiers.push src
          if res?.url
            meta.found[src] = res.url
            meta.url = if res.redirect then res.redirect else res.url
            meta.title ?= res.title ? res.dctitle ? res.bibjson?.title ? res.metadata?['oaf:result']?.title?.$
            meta.source = src
            meta.licence ?= res.best_oa_location?.license
            meta.journal = res.journal?.title?.split('(')[0].trim()
            return meta if not all and res.redirect isnt false

  if titles
    if not meta.title and meta.doi
      try
        res = API.use.crossref.works.doi meta.doi
        if res.data?.DOI is meta.doi and res.data.title
          meta.title = res.data.title[0].toLowerCase().replace(/(<([^>]+)>)/g,'').replace(/[^a-z0-9 ]/g,' ')

    # we can get a 404 for an article behind a loginwall if the service does not do splash pages,
    # and then we can accidentally get the article that exists called "404 not found". So we just don't
    # run checks for titles that start with 404
    # See https://github.com/OAButton/discussion/issues/931
    # this is the article: http://research.sabanciuniv.edu/34037/
    meta.title = undefined if meta.title and meta.title.indexOf('404 ') is 0
    if meta.title
      meta.titles = true
      API.log 'Resolving for title', title: meta.title
      for src in sources
        if src isnt 'oabutton'
          try
            # will only work for use endpoints that provide a title method
            res = if src is 'doaj' then API.use[src].articles.title(meta.title) else API.use[src].title meta.title
            meta.checked.titles.push src
            if res?.url
              meta.source = src
              meta.url = if res.redirect then res.redirect else res.url
              meta.found[src] = res.url
              return meta if not all and res.redirect isnt false

  if not meta.url and journal and meta.journal and 'doaj' in sources # can check DOAJ for journal
    try
      res = API.use.doaj.journals.search 'bibjson.journal.title:"'+meta.journal+'"'
      meta.checked.titles.push 'doaj'
      if res?.results?.length > 0
        for ju in res.results[0].bibjson.link
          if not meta.url and ju.type is 'homepage'
            meta.url = ju.url
            meta.source = "doaj"
            meta.journal_url = true
            meta.found.doaj = meta.url
            break

  return meta


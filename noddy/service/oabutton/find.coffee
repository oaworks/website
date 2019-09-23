
import { Random } from 'meteor/random'

###
{
  availability: [
    {
      type: 'article',
      url: <URL TO OBJECT - PROB A REDIRECT URL VIA OUR SYSTEM FOR STAT COUNT>
    }
  ],
  # will only list requests of types that are not yet available
  requests:[
    {
      type:'data',
      _id: 1234567890,
      usupport: true/false,
      ucreated: true/false
    },
    ...
  ]
}
###
API.service.oab.find = (opts={url:undefined,type:undefined}) ->
  opts.type ?= 'article'
  opts.sources ?= ['oabutton','eupmc','oadoi','openaire','figshare','doaj'] # removed core sep 2019
  opts.refresh ?= 30 # default refresh. If true then we won't even use successful previous lookups, otherwise if number only use failed lookups within refresh days
  opts.refresh = 0 if opts.refresh is true
  if typeof opts.refresh isnt 'number'
    try
      n = parseInt opts.refresh
      opts.refresh = if isNaN(n) then 0 else n
    catch
      opts.refresh = 0
  opts.url ?= opts.q if opts.q
  opts.url ?= opts.id if opts.id

  opts.doi = opts.doi.replace('doi:','').replace('DOI:','') if opts.doi?
  opts.id = opts.id.replace('doi:','').replace('DOI:','') if opts.id? and opts.id.toLowerCase().indexOf('doi:') is 0
  opts.url = opts.url.replace('doi:','').replace('DOI:','') if opts.url? and opts.url.toLowerCase().indexOf('doi:') is 0
  opts.pmid = opts.pmid.replace('pmid:','').replace('PMID:','') if opts.pmid? and opts.pmid.toLowerCase().indexOf('pmid:') is 0
  opts.pmcid = opts.pmcid.replace('pmcid:','').replace('PMCID:','') if opts.pmcid? and opts.pmcid.toLowerCase().indexOf('pmcid:') is 0
  opts.pmcid = opts.pmcid.replace('pubmedid:','').replace('PUBMEDID:','') if opts.pmcid? and opts.pmcid.toLowerCase().indexOf('pubmedid:') is 0

  if opts.url
    if opts.url.indexOf('10.') is 0
      opts.doi = opts.url
      opts.url = 'https://doi.org/' + opts.url
    else if opts.url.toLowerCase().indexOf('pmc') is 0
      opts.pmcid ?= opts.url.toLowerCase().replace('pmc','')
      opts.url = 'http://europepmc.org/articles/PMC' + opts.pmcid
    else if opts.url.length < 10 and opts.url.indexOf('.') is -1 and not isNaN(parseInt(opts.url))
      opts.pmid ?= opts.url
      opts.url = 'https://www.ncbi.nlm.nih.gov/pubmed/' + opts.pmid
    else if not opts.title? and opts.url.indexOf('http') isnt 0 and opts.url.toLowerCase().indexOf('citation:') isnt 0
      opts.title = opts.url.replace('TITLE:','')
  if not opts.url
    opts.url = 'CITATION:'+opts.citation if opts.citation
    opts.url = 'TITLE:'+opts.title if opts.title
    opts.url = 'https://www.ncbi.nlm.nih.gov/pubmed/' + opts.pmid if opts.pmid
    opts.url = 'http://europepmc.org/articles/PMC' + opts.pmc.toLowerCase().replace('pmc','') if opts.pmc
    opts.url = 'http://europepmc.org/articles/PMC' + opts.pmcid.toLowerCase().replace('pmc','') if opts.pmcid
    opts.url = 'https://doi.org/' + (if opts.doi.indexOf('doi.org/') isnt -1 then opts.doi.split('doi.org/')[1] else opts.doi) if opts.doi
  return {} if not opts.url?
  return {} if opts.short isnt true and opts.url.toLowerCase().indexOf('http') is -1 and opts.url.indexOf('10.') is -1 and opts.url.indexOf('/') is -1 and isNaN(parseInt(opts.url.toLowerCase().replace('pmc',''))) and opts.url.length < 10

  opts.bing ?= opts.plugin in ['widget','oasheet'] or opts.from in ['illiad','clio'] or opts.url.indexOf('alma.exlibrisgroup.com') isnt -1

  # ret.accepts is not currently properly handled - it is leftover from when we merged articles and data, and had an idea to do software and other types too
  # for now it should stay, so that the plugin can know how to handle them if necessary, but it just stays at accepting articles
  # unless there is an availability or a request found, in which case it is just set to empty list
  ret = {match:opts.url,availability:[],requests:[],accepts:[{type:'article'}],meta:{article:{},data:{}}}
  ret.library = API.service.oab.library(opts) if opts.library
  ret.libraries = API.service.oab.libraries(opts) if opts.libraries
  already = []

  if opts.url.indexOf('alma.exlibrisgroup.com') isnt -1 or opts.url.indexOf('/exlibristest') isnt -1
    # switch exlibris URLs for titles, which the scraper knows how to extract
    scraped = API.service.oab.scrape(undefined, opts.dom)
    opts.url = scraped.title # becayse the exlibris url would always be the same, we switch it out
    opts.title = scraped.title
    opts.exlibris = true
    ret.match = scraped.title
    ret.exlibris = true

  opts.discovered = {article:false,data:false}
  opts.source = {article:false,data:false}
  if opts.type is 'article'
    finder = '('
    finder += 'url:"' + opts.url + '"' if opts.url?
    if opts.doi?
      finder += ' OR ' if finder isnt '('
      finder += 'doi:"' + opts.doi + '"'
    if opts.pmcid?
      finder += ' OR ' if finder isnt '('
      finder += 'pmcid:"' + opts.pmcid + '"'
    if opts.pmid?
      finder += ' OR ' if finder isnt '('
      finder += 'pmid:"' + opts.pmid + '"'
    if opts.title?
      finder += ' OR ' if finder isnt '('
      finder += 'title:"' + opts.title + '"'
    finder += ')'
    if opts.refresh isnt 0 and 'oabutton' in opts.sources
      avail = oab_availability.find finder + ' AND discovered.article:* AND NOT discovered.article:false AND NOT source.article:core', true # don't re-use core ones, sep 2019
      if avail?.discovered?.article and ret.meta.article.redirect = API.service.oab.redirect(avail.discovered.article)
        ret.meta.article.url = avail.discovered.article
        ret.meta.article.source = avail.source?.article
        ret.meta.cache = true
        opts.cache = true
        ret.meta.refresh = opts.refresh # if we have a discovered article that is not since blacklisted we always reuse it - this is just for info
    d = new Date()
    if not ret.meta.article.url and ('oabutton' not in opts.sources or opts.refresh is 0 or not oab_availability.find finder + ' AND createdAt:>' + d.setDate(d.getDate() - opts.refresh), true )
      opts.resolve = true
      ret.meta.article = API.service.oab.resolve opts.url, opts.dom, opts.sources, opts.all, opts.titles, opts.journal, opts.bing
      ret.match = 'https://doi.org/' + ret.meta.article.doi if ret.meta.article.doi and ret.match.indexOf('http') isnt 0
    try opts.bing = ret.meta.article.bing
    try opts.capped = ret.meta.article.capped
    try opts.reversed = ret.meta.article.reversed
    try opts.scraped = ret.meta.article.scraped
    if ret.meta.article.url and ret.meta.article.source and ret.meta.article.redirect isnt false and not ret.meta.article.journal_url
      opts.source.article = ret.meta.article.source
      opts.title ?= ret.meta.article.title
      opts.doi ?= ret.meta.article.doi
      opts.checked = ret.meta.article.checked
      opts.discovered.article = if typeof ret.meta.article.redirect is 'string' then ret.meta.article.redirect else ret.meta.article.url
      ret.availability.push {type:'article',url:opts.discovered.article}
      ret.accepts = []
      already.push 'article'
    if opts.plugin is 'instantill'
      meta = API.service.oab.ill.metadata ret.meta.article,  opts
      for m of meta
        ret.meta.article[m] ?= meta[m]
      try
        if opts.from?
          ret.ill ?= {}
          ret.ill.openurl = API.service.oab.ill.openurl opts.from, ret.meta.article
          ret.ill.terms = API.service.oab.ill.terms opts.from
      try
        if opts.from?
          ret.ill ?= {}
          ret.ill.subscription = API.service.oab.ill.subscription opts.from, ret.meta.article, opts.all, opts.refresh
      try opts.ill = {subscription: {url: ret.ill.subscription.url}} # so that availabilities have ill info for stats...

  #opts.url = 'https://doi.org/' + ret.meta.article.doi if opts.url.indexOf('http') isnt 0 and ret.meta.article.doi
  # so far we are only doing availability checks for articles, so only need to check requests for data types or articles that were not found yet
  if (opts.type isnt 'article' or 'article' not in already) and request = oab_request.find finder + ' AND type:' + opts.type
    rq =
      type: request.type
      _id: request._id
    rq.ucreated = if opts.uid and request.user?.id is opts.uid then true else false
    rq.usupport = if opts.uid then API.service.oab.supports(request._id, opts.uid)? else false
    ret.requests.push rq
    ret.accepts = []
    already.push request.type

  #delete opts.dom if not API.settings.dev
  oab_availability.insert(opts) if not opts.nosave # save even if was a cache hit, to track usage of the endpoint
  return ret



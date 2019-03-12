

# https://jcheminf.springeropen.com/articles/10.1186/1758-2946-3-47 (the OBSTM article, open, on jcheminf, findable by CORE and BASE)
# http://www.sciencedirect.com/science/article/pii/S0735109712600734 (open on elsevier, not findable by CORE or BASE)
# http://journals.plos.org/plosone/article?id=info%3Adoi%2F10.1371%2Fjournal.pone.0159909 (open, on PLOS, findable by BASE)
# http://www.tandfonline.com/doi/abs/10.1080/09505431.2014.928678 (closed, not findable by CORE or BASE)

API.service.oab.crossref = (cr) ->
  # takes a crossref record and converts it into the metadata that OAB wants from it
  res = {}
  try
    cr = API.use.crossref.works.doi(cr) if typeof cr is 'string'
    try res.title = cr.title[0]
    try res.doi = cr.DOI ? cr.doi # just in case
    try res.crossref_type = cr.type
    try res.author = cr.author
    try res.journal = cr['container-title'][0]
    try res.issue = cr.issue
    try meta.volume = cr.volume
    try meta.page = cr.page.toString()
    try res.issn = cr.ISSN[0]
    try res.subject = cr.subject # not sure if this is present in crossref... check anyway
    try res.publisher = cr.publisher
    try res.year = cr['published-print']['date-parts'][0][0]
    try res.year ?= cr.created['date-time'].split('-')[0]
    try res.published = if cr['published-online']?['date-parts'] and cr['published-online']['date-parts'][0].length is 3 then cr['published-online']['date-parts'][0].join('-') else if cr['published-print']?['date-parts'] and cr['published-print']?['date-parts'][0].length is 3 then cr['published-print']['date-parts'][0].join('-') else undefined
  return res

API.service.oab.europepmc = (cr) ->
  # takes a europepmc record and converts it into the metadata that OAB wants from it
  res = {}
  try
    if typeof cr is 'string'
      if cr.indexOf('/') isnt -1
        rs = API.use.europepmc.doi cr
      else
        rs = API.use.europepmc.pmc cr
      if rs?
        rs.pmcid ?= cr
        cr = rs
      else
        rp = API.use.europepmc.pmid cr
        if rp?
          cr = rp
        else
          cr = API.use.europepmc.title cr
    try res.pmcid = cr.pmcid if cr.pmcid
    try res.title = cr.title
    try res.doi = cr.doi
    try res.pmid = cr.pmid
    # can set the pmc ID from anywhere?
    try
      res.author = cr.authorList.author
      for a in res.author
        a.given = a.firstName
        a.family = a.lastName
        a.affiliation = [{name: a.affiliation}] if a.affiliation
    try res.journal = cr.journalInfo.journal.title
    try res.issue = cr.journalInfo.issue
    try res.volume = cr.journalInfo.volume
    try res.page = cr.pageInfo.toString()
    try res.issn = cr.journalInfo.journal.issn
    try res.subject = cr.subject # not sure if epmc has subject
    #try res.publisher = cr.publisher #epmc does not appear to have publisher
    try res.year = cr.journalInfo.yearOfPublication
    try res.year ?= cr.journalInfo.printPublicationDate.split('-')[0]
    try 
      res.published = if cr.journalInfo.printPublicationDate.indexOf('-') isnt -1 then cr.journalInfo.printPublicationDate else if cr.electronicPublicationDate then cr.electronicPublicationDate else undefined
      try
        if res.published.split('-').length isnt 3
          delete res.published
  return res
  
API.service.oab.scrape = (url,content,doi) ->
  meta = {url:url,doi:doi}
  try
    content ?= API.http.puppeteer url
    content = undefined if typeof content is 'number'

  if url and not meta.doi # quick check to get a DOI if at the end of a URL, as they often are
    mr = new RegExp(/\/(10\.[^ &#]+\/[^ &#]+)$/)
    ud = mr.exec(decodeURIComponent(url))
    meta.doi = ud[1] if ud and ud.length > 1 and 9 < ud[1].length and ud[1].length < 45

  if not meta.doi and content
    try
      cl = content.toLowerCase()
      if cl.indexOf('dc.identifier') isnt -1
        cl = cl.split('dc.identifier')[1].split('content')[1]
        cl = cl.split('"')[1] if cl.indexOf('"') isnt -1
        cl = cl.split("'")[1] if cl.indexOf("'") isnt -1
        meta.doi = cl if cl.indexOf('10.') is 0 and cl.indexOf('/') isnt -1

  if not meta.doi and content
    try
      cl = content.toLowerCase()
      if cl.indexOf('citation_doi') isnt -1
        cl = cl.split('citation_doi')[1].split('content')[1]
        cl = cl.split('"')[1] if cl.indexOf('"') isnt -1
        cl = cl.split("'")[1] if cl.indexOf("'") isnt -1
        meta.doi = cl if cl.indexOf('10.') is 0 and cl.indexOf('/') isnt -1

  if not meta.doi and content
    try
      d = API.tdm.extract
        content:content
        matchers:['/doi[^>;]*?(?:=|:)[^>;]*?(10[.].*?\/.*?)("|\')/gi','/dx[.]doi[.]org/(10[.].*?/.*?)("| \')/gi']
      for n in d.matches
        if not meta.doi and 9 < d.matches[n].result[1].length and d.matches[n].result[1].length < 45
          meta.doi = d.matches[n].result[1]
          meta.doi = meta.doi.substring(0,meta.doi.length-1) if meta.doi.endsWith('.')

  if content and not meta.title
    content = content.toLowerCase()
    if content.indexOf('requestdisplaytitle') isnt -1
      meta.title = content.split('requestdisplaytitle').pop().split('>')[1].split('<')[0].trim().replace(/"/g,'')
    else if content.indexOf('dc.title') isnt -1
      meta.title = content.split('dc.title')[1].replace(/'/g,'"').split('content=')[1].split('"')[1].trim().replace(/"/g,'')
    else if content.indexOf('eprints.title') isnt -1
      meta.title = content.split('eprints.title')[1].replace(/'/g,'"').split('content=')[1].split('"')[1].trim().replace(/"/g,'')
    else if content.indexOf('og:title') isnt -1
      meta.title = content.split('og:title')[1].split('content')[1].split('=')[1].replace('/>','>').split('>')[0].trim().replace(/"/g,'')
      meta.title = meta.title.substring(1,meta.title.length-1) if meta.title.startsWith("'")
    else if content.indexOf('"citation_title" ') isnt -1
      meta.title = content.split('"citation_title" ')[1].replace(/ = /,'=').split('content="')[1].split('"')[0].trim().replace(/"/g,'')
    else if content.indexOf('<title') isnt -1
      meta.title = content.split('<title')[1].split('>')[1].split('</title')[0].trim().replace(/"/g,'')

  if meta.doi
    try
      cr = API.service.oab.crossref meta.doi
      for c of cr
        meta[c] ?= cr[c]

  if not meta.year
    try
      k = API.tdm.extract({
        content:content,
        matchers:[
          '/meta[^>;"\']*?name[^>;"\']*?= *?(?:"|\')citation_date(?:"|\')[^>;"\']*?content[^>;"\']*?= *?(?:"|\')(.*?)(?:"|\')/gi',
          '/meta[^>;"\']*?name[^>;"\']*?= *?(?:"|\')dc.date(?:"|\')[^>;"\']*?content[^>;"\']*?= *?(?:"|\')(.*?)(?:"|\')/gi',
          '/meta[^>;"\']*?name[^>;"\']*?= *?(?:"|\')prism.publicationDate(?:"|\')[^>;"\']*?content[^>;"\']*?= *?(?:"|\')(.*?)(?:"|\')/gi'
        ],
        start:'<head',
        end:'</head'
      })
      mk = k.matches[0].result[1]
      mkp = mk.split('-')
      if mkp.length is 1
        meta.year = mkp[0]
      else
        for my in mkp
          if my.length > 2
            meta.year = my
    
  if not meta.keywords
    try
      k = API.tdm.extract
        content:content
        matchers:['/meta[^>;"\']*?name[^>;"\']*?= *?(?:"|\')keywords(?:"|\')[^>;"\']*?content[^>;"\']*?= *?(?:"|\')(.*?)(?:"|\')/gi']
        start:'<head'
        end:'</head'
      kk = k.matches[0].result[1]
      if kk.indexOf(';') isnt -1
        kk = kk.replace(/; /g,';').replace(/ ;/g,';')
        meta.keywords = kk.split(';')
      else
        kk = kk.replace(/, /g,',').replace(/ ,/g,',')
        meta.keywords = kk.split(',')

  if not meta.email
    mls = []
    try
      m = API.tdm.extract
        content:content
        matchers:['/mailto:([^ \'">{}/]*?@[^ \'"{}<>]*?[.][a-z.]{2,}?)/gi','/(?: |>|"|\')([^ \'">{}/]*?@[^ \'"{}<>]*?[.][a-z.]{2,}?)(?: |<|"|\')/gi']
      for i in m.matches
        mm = i.result[1].replace('mailto:','')
        mm = mm.substring(0,mm.length-1) if mm.endsWith('.')
        mls.push(mm) if mls.indexOf(mm) is -1
    mls.sort ((a, b) -> return b.length - a.length)
    mstr = ''
    meta.email = []
    for me in mls
      meta.email.push(me) if mstr.indexOf(me) is -1
      mstr += me

  if meta.title? and typeof meta.title is 'string'
    try meta.title = meta.title.charAt(0).toUpperCase() + meta.title.slice(1)
  if meta.journal? and typeof meta.journal is 'string'
    try meta.journal = meta.journal.charAt(0).toUpperCase() + meta.journal.slice(1)

  return meta



API.add 'service/oab/scrape',
  get:
    #roleRequired:'openaccessbutton.user'
    action: () -> return API.service.oab.scrape this.queryParams.url, this.queryParams.content, this.queryParams.doi

# https://jcheminf.springeropen.com/articles/10.1186/1758-2946-3-47 (the OBSTM article, open, on jcheminf, findable by CORE and BASE)
# http://www.sciencedirect.com/science/article/pii/S0735109712600734 (open on elsevier, not findable by CORE or BASE)
# http://journals.plos.org/plosone/article?id=info%3Adoi%2F10.1371%2Fjournal.pone.0159909 (open, on PLOS, findable by BASE)
# http://www.tandfonline.com/doi/abs/10.1080/09505431.2014.928678 (closed, not findable by CORE or BASE)
API.service.oab.scrape = (url, content, doi) ->
  meta = {url:url,doi:doi}
  if url? and not content? and url.indexOf('.pdf') isnt -1
    try content = API.convert.pdf2txt url
  try content ?= API.http.puppeteer url
  content = undefined if typeof content is 'number'

  if url and not meta.doi # quick check to get a DOI if at the end of a URL, as they often are
    mr = new RegExp(/\/(10\.[^ &#]+\/[^ &#]+)$/)
    ud = mr.exec(decodeURIComponent(url))
    meta.doi = ud[1] if ud and ud.length > 1 and 9 < ud[1].length and ud[1].length < 45

  if content.indexOf('<') isnt 0 and content.length > 6000
    content = content.substring(0,6000)  # we only check the first three or so pages of content (3000 chars per page estimates 500 words per page)
  else if content.length > 50000
    content = content.substring(0,50000) # but for apparently html or xml sorts of content, take more to get through all metadata
    
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

  if not meta.doi and content # look for a doi in the first 600 words
    cnts = 0
    for str in content.split(' ')
      cnts += 1
      if cnts < 600
        str = str.replace(/ /g,'').replace('doi:','')
        str = str.split('doi.org')[1] if str.indexOf('doi.org') isnt -1
        str = str.replace('/','') if str.indexOf('/') is 0
        str = str.trim()
        if str.indexOf('10.') is 0 and str.indexOf('/') isnt -1 # don't use a regex
          meta.doi = str
          break
      
  if not meta.doi and content
    try
      d = API.tdm.extract
        content:content
        matchers:['/doi[^>;]*?(?:=|:)[^>;]*?(10[.].*?\/.*?)("|\')/gi','/doi[.]org/(10[.].*?/.*?)("| \')/gi']
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
  meta.title = meta.title.split('|')[0].trim() if meta.title and meta.title.indexOf('|') isnt -1

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

  return meta


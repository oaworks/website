
import crypto from 'crypto'

API.add 'service/oab/permissions', 
  get: () ->
    return API.service.oab.permissions this.queryParams, this.queryParams.content, this.queryParams.url
  post: () ->
    return API.service.oab.permissions this.queryParams, this.request.files ? this.request.body

API.add 'service/oab/permissions/:doi/:doi2', get: () -> return API.service.oab.permissions doi: this.urlParams.doi + '/' + this.urlParams.doi2

API.service.oab.permissions = (meta={}, file, url) ->
  # https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3206455
  # https://static.cottagelabs.com/obstm.pdf
  # could add a cache to this, or save in its own index, so can retrieve without doing GET every time
  # or check the catalogue for this record, see if we already have the permissions
  
  perms = permitted: false, files: []

  if typeof file is 'string'
    file = data: file
  if _.isArray file
    file = if file.length then file[0] else undefined
  if not file? and url?
    file = {}
    file.data = if url.indexOf('.pdf') isnt -1 then HTTP.call('GET',url,{timeout:20000,npmRequestOptions:{encoding:null}}).content else API.http.puppeteer url
    file.name = if url.substr(url.lastIndexOf('/')+1).indexOf('.') isnt -1 then url.substr(url.lastIndexOf('/')+1) else undefined

  f = {}
  if file?
    try f.name = file.name
    try f.type = if file.name? and file.name.indexOf('.') isnt -1 then file.name.substr(file.name.lastIndexOf('.')+1) else 'html'
    if f.type is 'pdf'
      try content = API.convert.pdf2txt file.data
    if not content? and f.type? and API.convert[f.type+'2txt']?
      try content = API.convert[f.type+'2txt'] file.data
    if not content? and typeof file.data is 'string'
      if file.data.indexOf('<html') is 0
        try content = API.convert.html2txt file.data
      else if file.data.indexOf('<xml') is 0
        try content = API.convert.xml2txt file.data
    try content ?= API.convert.file2txt file.data
    try content ?= file.data
    try content = content.toString()

  metad = false
  if not meta.doi?
    metad = true
    meta = API.service.oab.metadata meta, content

  if meta.doi?
    try perms.ricks = HTTP.call('GET','https://rickscafe-api.herokuapp.com/permissions/doi/' + meta.doi).data.authoritative_permission.application
    perms.permitted = perms.ricks? and (perms.ricks.can_post_now is true or (perms.ricks.can_post_now_conditions.versions_archivable and ('postprint' in perms.ricks.can_post_now_conditions.versions_archivable or 'publisher pdf' in perms.ricks.can_post_now_conditions.versions_archivable)))
    '''In application the fields there should map to parts of the information we need like deposit statement, embargo, licence, 
    what versions are allowed, etc. Slotting those in should feel familar from the prep work with did with Zenodo & the request 
    data format that we were previously filling manually.'''
  if not perms.ricks? and not (meta.issn? or meta.journal?) and not metad?
    # if we already had doi and did find it in ricks, it would not have been worth doing a metadata lookup.
    # but if we did not find it in ricks and had not yet looked for metadata, try now if we don't have enough for sherpa
    meta = API.service.oab.metadata meta, content
  if meta.issn? or meta.journal? #) and (not perms.ricks? or perms.permitted isnt true)
    try perms.sherpa = API.use.sherpa.romeo.find(if meta.issn then {issn:meta.issn} else {title:meta.journal})
    perms.permitted ?= perms.sherpa?.color in ['green','yellow','blue'] # green or blue can accept anything, yellow can accept preprint

  if not content?
    f.error = 'Could not extract any content'
  else
    _clean = (str) -> return str.toLowerCase().replace(/[^a-z0-9\/\. ]+/g, "").replace(/\s\s+/g, ' ').trim()

    lowercontentsmall = _clean(if content.length < 800000 then content else content.substring(0,400000) + content.substring(content.length-400000,content.length))
    lowercontentstart = if lowercontentsmall.length < 100000 then lowercontentsmall else lowercontentsmall.substring(0,100000)

    f.name ?= meta.title
    f.checksum = crypto.createHash('md5').update(content, 'utf8').digest('base64')

    f.expected = {} # check if the file meets our expectations
    f.expected.words = content.split(' ').length # will need to be at least 500 words
    f.expected.doi = meta.doi and lowercontentstart.indexOf(_clean meta.doi) isnt -1 # should have the doi in it near the front
    f.expected.title = meta.title and API.service.oab.ftitle(lowercontentstart).indexOf(API.service.oab.ftitle meta.title) isnt -1
    if meta.author?
      try
        authorsfound = 0
        f.expected.author = false
        # get the surnames out if possible, or author name strings, and find at least one in the doc if there are three or less, or find at least two otherwise
        meta.author = {name: meta.author} if typeof meta.author is 'string'
        meta.author = [meta.author] if not _.isArray meta.author
        for a in meta.author
          if f.expected.author is true
            break
          else
            try
              an = a.last ? a.lastname ? a.family ? a.surname ? a.name
              for ap in an.split(',')[0].split(' ')
                if ap.length > 2 and lowercontentsmall.indexOf(_clean ap) isnt -1
                  authorsfound += 1
                  if (meta.author.length < 3 and authorsfound is 1) or (meta.author.length > 2 and authorsfound is 2)
                    f.expected.author = true
                    break
    if f.type?
      for tp in ['doc','tex','pdf','htm','xml','wpd','wks','wps','txt','rtf','odf','odt','page']
        if f.type.indexOf(tp) isnt -1
          f.expected.type = true
          break

    f.version = checked: 0
    try
      # https://docs.google.com/spreadsheets/d/1XA29lqVPCJ2FQ6siLywahxBTLFaDCZKaN5qUeoTuApg/edit#gid=0
      for l in API.use.google.sheets.feed '1XA29lqVPCJ2FQ6siLywahxBTLFaDCZKaN5qUeoTuApg'
        try
          f.version.checked += 1
          tgt = if l.wheretosearch is 'title' then _clean(meta.title ? f.name ? '') else lowercontentsmall
          if (l.howtosearch is 'string' and tgt.indexOf(_clean l.whattosearch) isnt -1) or tgt.match(/l.whattosearch/gi) isnt null
            f.version.indicated = l.whatitindicates
            f.version.by = l.howtosearch + ' ' + l.whattosearch
            f.version.in = l.wheretosearch
            break
          
    try f.version.pdf = f.type is 'pdf' # set to true if file appears to be a pdf - non-pdfs are acceptable by default
  
    try f.lantern = API.service.lantern.licence undefined, undefined, lowercontentsmall # check lantern for licence info

    f.acceptable = false
    if f.expected.words > 500 and (f.expected.doi or f.expected.title or f.expected.author) and f.expected.type
      if not f.version.pdf
        f.acceptable = true
        f.acceptance = 'File is not a PDF, therefore is acceptable'
      else if perms.permitted
        if perms.ricks?.can_post_now
          f.acceptable = true
          f.acceptance = 'Rick says this article can be posted now'
        else if perms.ricks?.can_post_now_conditions?.versions_archivable? # the version we can tell it is appears to meet what Rick says can be posted
          if f.version.indicated?
            if f.version.indicated in perms.ricks.can_post_now_conditions.versions_archivable
              f.acceptable = true
              f.acceptance = 'We believe this is a ' + a + ' version and Rick says such versions can be shared now'
            else
              f.unacceptable = 'We believe this file is a ' + f.version.indicated + ' but Rick does not list that as an archivable type'
          else
            f.unacceptable = 'Rick indicates postprints or publisher PDFs are archivable but we cannot confirm what version this is'
        
        if not f.acceptable and perms.sherpa?
          if perms.sherpa.color in ['green','blue']
            f.acceptable = true
            f.acceptance = 'Sherpa color is ' + perms.sherpa.color + ' so any file is acceptable'
          else if perms.sherpa?.color is 'yellow'
            if f.version.indicated? and f.version.indicated isnt 'publisher pdf'
              f.acceptable = true
              f.acceptance = 'Sherpa color is ' + perms.sherpa.color + ' which allows anything except publisher PDF and we can confirm this is a ' + f.version.indicated
            else
              f.unacceptable = 'Sherpa color is ' + perms.sherpa.color + ' which allows anything expect publisher PDF but ' + (if f.version.indicated? then ' we believe this is a ' + f.version.indicated else ' we were unable to confirm the version, so there is a risk this could be a publisher PDF')

      if not f.acceptable and f.lantern?.licence? and f.lantern.licence.toLowerCase().indexOf('cc') is 0
        f.acceptable = true
        f.acceptance = 'Lantern indicates this file contains a ' + f.lantern.licence + ' licence statement which confirms this article can be archived'
        delete f.unacceptable
      f.unacceptable = 'File is a pdf amd we cannot confirm via Rick or Sherpa or Lantern if it is an acceptable version or not' if not f.acceptable
    else
      f.unacceptable = if f.expected.words < 500 then 'File is less than 500 words, does not appear to be a full article' else if not f.expected.type then 'File is of unexpected type ' + f.type else if not meta.doi and not meta.title then 'Insufficient metadata to validate file' else 'File does not contain expected metadata such as DOI or title'
  
    # if file is not expected type, get confirmation of type from submitting user
    # if file is not acceptable, initiate a human review, and a way to record the result of tha review and get the file back again

  perms.files.push(f) if not _.isEmpty f
  # add/update this article in the catalogue?
  perms.metadata = meta
  return perms





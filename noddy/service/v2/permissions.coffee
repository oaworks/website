
import crypto from 'crypto'
import moment from 'moment'

API.add 'service/oab/permissions', 
  get: () ->
    return API.service.oab.permissions this.queryParams, this.queryParams.content, this.queryParams.url, this.queryParams.confirmed, this.queryParams.verbose
  post: () ->
    return API.service.oab.permissions this.queryParams, this.request.files ? this.request.body, undefined, this.queryParams.confirmed ? this.bodyParams?.confirmed, this.queryParams.verbose ? this.bodyParams?.verbose

API.add 'service/oab/permissions/:doi/:doi2', get: () -> return API.service.oab.permissions doi: this.urlParams.doi + '/' + this.urlParams.doi2

API.service.oab.permissions = (meta={}, file, url, confirmed, verbose) ->
  # example files / URLs
  # https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3206455
  # https://static.cottagelabs.com/obstm.pdf

  # dev and live demo accounts that always return a fixed answer
  if meta.doi? and meta.doi.indexOf('10.1234/oab-syp-') is 0 #and (meta.from is 'qZooaHWRz9NLFNcgR' or uid is 'eZwJ83xp3oZDaec86')
    return {
      demo: true, 
      permitted: if meta.doi is '10.1234/oab-syp-aam' then true else false, 
      permits: if meta.doi is '10.1234/oab-syp-aam' then "postprint" else undefined,
      file: {
        acceptable: true, acceptance: "Demo acceptance", version: "postprint", licence: "cc-by", match: true, name: "example.pdf", type: "pdf", checksum: "example-checksum"
      }
    }

  types = ['doc','tex','pdf','htm','xml','wpd','wks','wps','txt','rtf','odf','odt','page']
  
  perms = meta.permissions ? {permitted: false, permits: undefined, embargo: undefined, statement: undefined, file: undefined}
  meta = meta.metadata if meta.metadata? # if passed a catalogue object

  if typeof file is 'string'
    file = data: file
  if _.isArray file
    file = if file.length then file[0] else undefined
  if not file? and url?
    file = API.http.getFile url

  f = {acceptable: undefined, acceptance: undefined, unacceptable: undefined, version: 'unknown', licence: undefined, match: undefined}
  if file?
    file.name ?= file.filename
    try f.name = file.name
    try f.type = if file.name? and file.name.indexOf('.') isnt -1 then file.name.substr(file.name.lastIndexOf('.')+1) else 'html'
    if file.data
      if f.type is 'pdf'
        try content = API.convert.pdf2txt file.data
      if not content? and f.type? and API.convert[f.type+'2txt']?
        try content = API.convert[f.type+'2txt'] file.data
      if not content?
        content = API.convert.file2txt file.data, {name: file.name}
      if not content?
        fd = file.data
        if typeof file.data isnt 'string'
          try fd = file.data.toString()
        try
          if fd.indexOf('<html') is 0
            content = API.convert.html2txt fd
          else if file.data.indexOf('<xml') is 0
            content = API.convert.xml2txt fd
      try content ?= file.data
      try content = content.toString()

  metad = false
  if not meta.doi?
    metad = true
    meta = API.service.oab.metadata meta, content

  if meta.doi? and not perms.ricks?
    try perms.ricks = HTTP.call('GET','https://rickscafe-api.herokuapp.com/permissions/doi/' + meta.doi).data.authoritative_permission.application
    #perms.permitted = perms.ricks? and (perms.ricks.can_archive is true or (perms.ricks.can_archive_conditions?.versions_archivable and ('postprint' in perms.ricks.can_archive_conditions.versions_archivable or 'publisher pdf' in perms.ricks.can_archive_conditions.versions_archivable)))
    perms.permitted = perms.ricks?.can_archive_conditions?.versions_archivable and ('postprint' in perms.ricks.can_archive_conditions.versions_archivable or 'publisher pdf' in perms.ricks.can_archive_conditions.versions_archivable)
    perms.statement = perms.ricks.can_archive_conditions.deposit_statement_required_calculated if typeof perms.ricks?.can_archive_conditions?.deposit_statement_required_calculated is 'string' and perms.ricks?.can_archive_conditions?.deposit_statement_required_calculated.indexOf('cc-') isnt 0
    try
      if perms.permitted
        perms.permits = if 'publisher pdf' in perms.ricks.can_archive_conditions.versions_archivable then 'publisher pdf' else if 'postprint' in perms.ricks.can_archive_conditions.versions_archivable then 'postprint' else 'preprint'
    try
      for k of perms.ricks
        if k.indexOf('embargo') isnt -1 and perms.ricks[k] and perms.permits is k.split('_embargo')[0].replace('_','').replace('publisherpdf','publisher pdf')
          em = moment(perms.ricks[k])
          if em.isAfter(moment())
            perms.embargo = em.format "YYYY-MM-DD"
            break
  if not perms.sherpa?
    if not (meta.issn? or meta.journal?) and not metad
      metad = true
      meta = API.service.oab.metadata meta, content
    if meta.issn? or meta.journal?
      try perms.sherpa = API.use.sherpa.romeo.find(if meta.issn then {issn:meta.issn} else {title:meta.journal})
      perms.permitted ?= perms.sherpa?.color in ['green','yellow','blue']
      try
        if perms.permitted
          perms.permits ?= if perms.sherpa.color is 'yellow' then 'preprint' else 'postprint'
      try
        for c in perms.sherpa.publisher.conditions
          if c.toLowerCase().indexOf('embargo') isnt -1
            parts = c.toLowerCase().replace(/-/g,' ').split()
            months = 0
            for p in parts
              if not isNaN parseInt p
                months = parseInt p
                break
            months = months * 12 if 'year' in parts or 'years' in parts
            if months isnt 0
              if not (meta.year? or meta.published?) and not metad
                metad = true
                meta = API.service.oab.metadata meta, content
              if (meta.year? or meta.published?) and perms.permits is (if 'pre' in parts then 'preprint' else if 'post' in parts then 'postprint' else if 'publisher' in parts then 'publisher pdf' else false)
                pp = moment(if meta.published then meta.published else meta.year + '-12-01').add months, 'months'
                if pp.isAfter(moment())
                  perms.embargo = pp.format "YYYY-MM-DD"
                  break

  if not content? and not confirmed
    if file? or url?
      f.error = file.error ? 'Could not extract any content'
  else
    _clean = (str) -> return str.toLowerCase().replace(/[^a-z0-9\/\. ]+/g, "").replace(/\s\s+/g, ' ').trim()

    try
      lowercontentsmall = _clean(if content.length < 800000 then content else content.substring(0,400000) + content.substring(content.length-400000,content.length))
      lowercontentstart = if lowercontentsmall.length < 100000 then lowercontentsmall else lowercontentsmall.substring(0,100000)

    f.name ?= meta.title
    try f.checksum = crypto.createHash('md5').update(content, 'utf8').digest('base64')
    seen = false
    if f.checksum and perms.files?
      for pf in perms.files
        if pf.checksum is f.checksum
          seen = true
          break
    if not seen
      f.expected = {} # check if the file meets our expectations
      try f.expected.words = content.split(' ').length # will need to be at least 500 words
      try f.expected.doi = if meta.doi and lowercontentstart.indexOf(_clean meta.doi) isnt -1 then true else false # should have the doi in it near the front
      if content and not f.expected.doi and not meta.title? and not metad
        meta = API.service.oab.metadata meta, content # get at least title again if not already tried to get it, and could not find doi in the file
      try f.expected.title = if meta.title and lowercontentstart.replace(/ /g,'').indexOf(_clean meta.title.replace(/ /g,'')) isnt -1 then true else false
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
        for tp in types
          if f.type.indexOf(tp) isnt -1
            f.expected.type = true
            break

      f.match = if f.expected.words > 500 and (f.expected.doi or f.expected.title or f.expected.author) and f.expected.type then true else false

      if f.expected.words is 1 and f.type is 'pdf'
        # there was likely a pdf file reading failure due to bad PDF formatting
        f.expected.words = 0
        f.unacceptable = 'We could not find any text in the provided PDF - it is possible the PDF is a scan in which case text is only contained within images which we do not yet extract, or some PDFs have errors in their structure which stops us being able to machine-read them'

      f.versioning = checked: 0, ve: 0, matches: []
      try
        # dev https://docs.google.com/spreadsheets/d/1XA29lqVPCJ2FQ6siLywahxBTLFaDCZKaN5qUeoTuApg/edit#gid=0
        # live https://docs.google.com/spreadsheets/d/10DNDmOG19shNnuw6cwtCpK-sBnexRCCtD4WnxJx_DPQ/edit#gid=0
        for l in API.use.google.sheets.feed (if API.settings.dev then '1XA29lqVPCJ2FQ6siLywahxBTLFaDCZKaN5qUeoTuApg' else '10DNDmOG19shNnuw6cwtCpK-sBnexRCCtD4WnxJx_DPQ')
          try
            f.versioning.checked += 1
            wts = l.whattosearch
            if wts.indexOf('<<') isnt -1 and wts.indexOf('>>') isnt -1
              wtm = wts.split('<<')[1].split('>>')[0]
              wts = wts.replace('<<'+wtm+'>>',meta[wtm.toLowerCase()]) if meta[wtm.toLowerCase()]?
            matched = false
            if l.howtosearch is 'string'
              wtsc = _clean wts
              matched = true if (l.wheretosearch is 'file' and lowercontentsmall.indexOf(wtsc) isnt -1) or (l.wheretosearch isnt 'file' and ((meta.title? and _clean(meta.title).indexOf(wtsc) isnt -1) or (f.name? and _clean(f.name).indexOf(wtsc) isnt -1)))
            else
              re = new RegExp wts, 'giu'
              matched = true if (l.wheretosearch is 'file' and lowercontentsmall.match(re) isnt null) or (l.wheretosearch isnt 'file' and ((meta.title? and meta.title.match(re) isnt null) or (f.name? and f.name.match(re) isnt null)))
            if matched
              if l.whatitindicates is 'publisher pdf' then f.versioning.ve += 1 else f.versioning.ve -= 1
              f.versioning.matches.push {indicates: l.whatitindicates, by: l.howtosearch + ' ' + wts, in: l.wheretosearch}

      f.version = 'publisher pdf' if f.versioning.ve > 0
      f.version = 'postprint' if f.versioning.ve < 0
      if f.version is 'unknown' and f.type? and f.type isnt 'pdf'
        f.version = 'postprint'
        
      try f.lantern = API.service.lantern.licence undefined, undefined, lowercontentsmall # check lantern for licence info
      f.licence = f.lantern.licence if f.lantern?.licence?
  
      f.acceptable = false
      if confirmed
        f.acceptable = true
        delete f.unacceptable
        if confirmed is f.checksum
          f.acceptance = 'The administrator has confirmed that this file is the version that can be shared now'
          f.admin_confirms = true
        else
          f.acceptance = 'The depositor says that this file is the version that can be shared now'
          f.depositor_says = true
      else if f.match
        if f.type isnt 'pdf'
          f.acceptable = true
          f.acceptance = 'File is not a PDF, therefore is acceptable'
        else #if perms.permitted
          #if perms.ricks?.can_archive
          #  f.acceptable = true
          #  f.acceptance = 'Rick says any version of article can be posted now'
          if perms.ricks?.can_archive_conditions?.versions_archivable? # the version we can tell it is appears to meet what Rick says can be posted
            if f.version in perms.ricks.can_archive_conditions.versions_archivable or f.version is 'postprint' and 'postprint' in perms.ricks.can_archive_conditions.versions_archivable
              f.acceptable = true
              f.acceptance = 'We believe this is a ' + f.version + ' and Rick says such versions can be shared'
            else
              f.unacceptable = 'We believe this file is a ' + f.version + ' version and Rick does not list that as an archivable type'

          # https://github.com/OAButton/discussion/issues/1377
          if not f.acceptable and perms.sherpa?
            if perms.sherpa.color is 'green'
              if f.version in ['preprint','postprint']
                f.acceptable = true
                f.acceptance = 'Sherpa color is ' + perms.sherpa.color + ' so ' + f.version + ' is acceptable'
              else
                f.unacceptable = 'Sherpa color is ' + perms.sherpa.color + ' which allows only preprint or postprint but version is ' + f.version
            else if perms.sherpa.color is 'blue'
              if f.version in ['postprint']
                f.acceptable = true
                f.acceptance = 'Sherpa color is ' + perms.sherpa.color + ' so ' + f.version + ' is acceptable'
              else
                f.unacceptable = 'Sherpa color is ' + perms.sherpa.color + ' which allows only postprint but version is ' + f.version
            else if perms.sherpa?.color is 'yellow'
              if f.version in ['preprint']
                f.acceptable = true
                f.acceptance = 'Sherpa color is ' + perms.sherpa.color + ' so ' + f.version + ' is acceptable'
              else
                f.unacceptable = 'Sherpa color is ' + perms.sherpa.color + ' which allows only preprint but version is ' + f.version
  
        if not f.acceptable and f.licence? and f.licence.toLowerCase().indexOf('cc') is 0
          f.acceptable = true
          f.acceptance = 'Lantern indicates this file contains a ' + f.lantern.licence + ' licence statement which confirms this article can be archived'
          delete f.unacceptable
        if not f.acceptable
          f.unacceptable = 'File is a pdf amd we cannot confirm via Rick or Sherpa or Lantern if it is an acceptable version or not'
      else
        f.unacceptable ?= if f.expected.words < 500 then 'File is less than 500 words, does not appear to be a full article' else if not f.expected.type then 'File is of unexpected type ' + f.type else if not meta.doi and not meta.title then 'Insufficient metadata to validate file' else 'File does not contain expected metadata such as DOI or title'
    
  perms.file = f if not _.isEmpty f

  try perms.lantern = API.service.lantern.licence('https://doi.org/' + meta.doi) if not f.licence and meta.doi? and 'doi.org' not in url # and not got licence already from ricks or sherpa?
  if f.acceptable isnt undefined and f.acceptable isnt true and perms.lantern?.licence? and perms.lantern.licence.toLowerCase().indexOf('cc') is 0
    f.licence = perms.lantern.licence
    f.acceptable = true
    f.acceptance = 'Lantern indicates that the splash page contains a ' + perms.lantern.licence + ' licence statement which confirms this article can be archived'
    delete f.unacceptable

  if f.acceptable and not f.licence?
    if perms.ricks?.can_archive_conditions?.deposit_statement_required_calculated? and perms.ricks.can_archive_conditions.deposit_statement_required_calculated.indexOf('cc') is 0
        f.licence = perms.ricks.can_archive_conditions.deposit_statement_required_calculated
    else if perms.sherpa?.publisher?.alias? and perms.sherpa.publisher.alias.toLowerCase().indexOf('cc-') isnt -1
      f.licence = 'cc-' + perms.sherpa.publisher.alias.toLowerCase().split('cc-')[1].split(' ')[0]

  if not verbose
    delete perms.files if perms.files?
    delete perms.ricks
    delete perms.sherpa
    delete perms.lantern
    if perms.file?.acceptable
      delete perms.file.versioning
      delete perms.file.expected
      delete perms.file.lantern
  perms.metadata = meta if verbose
  return perms





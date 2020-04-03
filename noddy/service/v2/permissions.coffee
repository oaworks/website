
import crypto from 'crypto'
import moment from 'moment'

API.add 'service/oab/permissions',
  get: () ->
    return API.service.oab.permissions this.queryParams, this.queryParams.content, this.queryParams.url, this.queryParams.confirmed, this.queryParams.uid
  post: () ->
    return API.service.oab.permissions this.queryParams, this.request.files ? this.request.body, undefined, this.queryParams.confirmed ? this.bodyParams?.confirmed

API.add 'service/oab/permissions/:doi/:doi2', get: () -> return API.service.oab.permissions doi: this.urlParams.doi + '/' + this.urlParams.doi2

API.service.oab.permissions = (meta={}, file, url, confirmed, uid) ->
  # example files / URLs
  # https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3206455
  # https://static.cottagelabs.com/obstm.pdf

  # dev and live demo accounts that always return a fixed answer
  if meta.doi? and meta.doi.indexOf('10.1234/oab-syp-') is 0 #and (meta.from is 'qZooaHWRz9NLFNcgR' or uid is 'eZwJ83xp3oZDaec86')
    return {
      demo: true,
      permissions: {
        archiving_allowed: if meta.doi is '10.1234/oab-syp-aam' then true else false,
        version_allowed: if meta.doi is '10.1234/oab-syp-aam' then "postprint" else undefined
      }
      file: {
        archivable: true, archivable_reason: "Demo acceptance", version: "postprint", licence: "cc-by", same_paper: true, name: "example.pdf", format: "pdf", checksum: "example-checksum"
      }
    }

  formats = ['doc','tex','pdf','htm','xml','txt','rtf','odf','odt','page']

  perms = {permissions: {archiving_allowed: false, version_allowed: undefined, embargo: undefined, required_statement: undefined, licence_required: undefined}, file: undefined}
  meta = meta.metadata if meta.metadata? # if passed a catalogue object

  if typeof file is 'string'
    file = data: file
  if _.isArray file
    file = if file.length then file[0] else undefined
  if not file? and url?
    file = API.http.getFile url

  f = {archivable: undefined, archivable_reason: undefined, version: 'unknown', version_standard: undefined, same_paper: undefined, licence: undefined}
  if file?
    file.name ?= file.filename
    try f.name = file.name
    try f.format = if file.name? and file.name.indexOf('.') isnt -1 then file.name.substr(file.name.lastIndexOf('.')+1) else 'html'
    if file.data
      if f.format is 'pdf'
        try content = API.convert.pdf2txt file.data
      if not content? and f.format? and API.convert[f.format+'2txt']?
        try content = API.convert[f.format+'2txt'] file.data
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
    meta = API.service.oab.metadata undefined, meta, content

  if meta.doi? and not perms.ricks?
    try
      # https://rickscafe-api.herokuapp.com/permissions/doi/
      cached = API.http.cache meta.doi, 'ricks_permissions'
      if cached and typeof cached is 'object' and cached.application?
        perms.ricks = cached
        API.log 'Permissions check found in Ricks cache for ' + meta.doi
    if not perms.ricks?
      ru = 'https://api.greenoait.org/permissions/doi/' + meta.doi
      if uid and uc = API.service.oab.deposit.config(uid)
        ru += '?affiliation=' + uc.ROR_ID if uc.ROR_ID
      API.log 'Permissions check connecting to Ricks for ' + ru
      try
        perms.ricks = HTTP.call('GET',ru).data.authoritative_permission
        try API.http.cache(meta.doi, 'ricks_permissions', perms.ricks) if perms.ricks?.application?
      catch
        API.log 'Permissions check connection to Ricks failed for ' + meta.doi
        perms.error = 'Could not connect to Ricks'
    try
      perms.permissions.archiving_allowed = perms.ricks?.application?.can_archive_conditions?.versions_archivable? and ('postprint' in perms.ricks.application.can_archive_conditions.versions_archivable or 'publisher pdf' in perms.ricks.application.can_archive_conditions.versions_archivable)
      perms.permissions.required_statement = perms.ricks.application.can_archive_conditions.deposit_statement_required_calculated if typeof perms.ricks?.application?.can_archive_conditions?.deposit_statement_required_calculated is 'string' and perms.ricks.application.can_archive_conditions.deposit_statement_required_calculated.indexOf('cc-') isnt 0
      perms.permissions.licence_required = perms.ricks.application.can_archive_conditions.licenses_required[0] if perms.ricks?.application?.can_archive_conditions?.licenses_required?
      perms.permissions.policy_full_text = perms.ricks.provenance.policy_full_text if perms.ricks?.provenance?.policy_full_text
    try
      if perms.permissions.archiving_allowed
        perms.permissions.version_allowed = if 'publisher pdf' in perms.ricks.application.can_archive_conditions.versions_archivable then 'publisher pdf' else if 'postprint' in perms.ricks.application.can_archive_conditions.versions_archivable then 'postprint' else 'preprint'
    try
      for k of perms.ricks.application.can_archive_conditions
        if k.indexOf('embargo') isnt -1 and perms.ricks.application.can_archive_conditions[k] and perms.permissions.version_allowed is k.split('_embargo')[0].replace('_','').replace('publisherpdf','publisher pdf')
          em = moment(perms.ricks.application.can_archive_conditions[k])
          if em.isAfter(moment())
            perms.permissions.embargo = em.format "YYYY-MM-DD"
            break
  if false and not perms.sherpa? # sherpa is turned off now - could use it as a fallback if ever ricks does not respond (but may need to update sherpa to their new api spec)
    if not (meta.issn? or meta.journal?) and not metad
      metad = true
      meta = API.service.oab.metadata undefined, meta, content
    if meta.issn? or meta.journal?
      try perms.sherpa = API.use.sherpa.romeo.find(if meta.issn then {issn:meta.issn} else {title:meta.journal})
      perms.permissions.archiving_allowed ?= perms.sherpa?.color in ['green','yellow','blue']
      try
        if perms.permissions.archiving_allowed
          perms.permissions.version_allowed ?= if perms.sherpa.color is 'yellow' then 'preprint' else 'postprint'
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
                meta = API.service.oab.metadata undefined, meta, content
              if (meta.year? or meta.published?) and perms.permissions.version_allowed is (if 'pre' in parts then 'preprint' else if 'post' in parts then 'postprint' else if 'publisher' in parts then 'publisher pdf' else false)
                pp = moment(if meta.published then meta.published else meta.year + '-12-01').add months, 'months'
                if pp.isAfter(moment())
                  perms.permissions.embargo = pp.format "YYYY-MM-DD"
                  break

  if not content? and not confirmed
    if file? or url?
      f.error = file.error ? 'Could not extract any content'
  else
    _clean = (str) -> return str.toLowerCase().replace(/[^a-z0-9\/\.]+/g, "").replace(/\s\s+/g, ' ').trim()

    lowercontentsmall = (if content.length < 20000 then content else content.substring(0,6000) + content.substring(content.length-6000,content.length)).toLowerCase()
    lowercontentstart = _clean(if lowercontentsmall.length < 6000 then lowercontentsmall else lowercontentsmall.substring(0,6000))

    f.name ?= meta.title
    try f.checksum = crypto.createHash('md5').update(content, 'utf8').digest('base64')
    seen = false
    if f.checksum and perms.files?
      for pf in perms.files
        if pf.checksum is f.checksum
          seen = true
          break
    if not seen
      f.same_paper_evidence = {} # check if the file meets our expectations
      try f.same_paper_evidence.words_count = content.split(' ').length # will need to be at least 500 words
      try f.same_paper_evidence.words_more_than_threshold = if f.same_paper_evidence.words_count > 500 then true else false
      try f.same_paper_evidence.doi_match = if meta.doi and lowercontentstart.indexOf(_clean meta.doi) isnt -1 then true else false # should have the doi in it near the front
      if content and not f.same_paper_evidence.doi_match and not meta.title? and not metad
        meta = API.service.oab.metadata undefined, meta, content # get at least title again if not already tried to get it, and could not find doi in the file
      try f.same_paper_evidence.title_match = if meta.title and lowercontentstart.replace(/\./g,'').indexOf(_clean meta.title.replace(/ /g,'').replace(/\./g,'')) isnt -1 then true else false
      if meta.author?
        try
          authorsfound = 0
          f.same_paper_evidence.author_match = false
          # get the surnames out if possible, or author name strings, and find at least one in the doc if there are three or less, or find at least two otherwise
          meta.author = {name: meta.author} if typeof meta.author is 'string'
          meta.author = [meta.author] if not _.isArray meta.author
          for a in meta.author
            if f.same_paper_evidence.author_match is true
              break
            else
              try
                an = (a.last ? a.lastname ? a.family ? a.surname ? a.name).trim().split(',')[0].split(' ')[0]
                af = (a.first ? a.firstname ? a.given ? a.name).trim().split(',')[0].split(' ')[0]
                inc = lowercontentstart.indexOf _clean an
                if an.length > 2 and af.length > 0 and inc isnt -1 and lowercontentstart.substring(inc-20,inc+an.length+20).indexOf(_clean af) isnt -1
                  authorsfound += 1
                  if (meta.author.length < 3 and authorsfound is 1) or (meta.author.length > 2 and authorsfound > 1)
                    f.same_paper_evidence.author_match = true
                    break
      if f.format?
        for ft in formats
          if f.format.indexOf(ft) isnt -1
            f.same_paper_evidence.document_format = true
            break

      f.same_paper = if f.same_paper_evidence.words_more_than_threshold and (f.same_paper_evidence.doi_match or f.same_paper_evidence.title_match or f.same_paper_evidence.author_match) and f.same_paper_evidence.document_format then true else false

      if f.same_paper_evidence.words_count is 1 and f.format is 'pdf'
        # there was likely a pdf file reading failure due to bad PDF formatting
        f.same_paper_evidence.words_count = 0
        f.archivable_reason = 'We could not find any text in the provided PDF. It is possible the PDF is a scan in which case text is only contained within images which we do not yet extract. Or, the PDF may have errors in it\'s structure which stops us being able to machine-read it'

      f.version_evidence = score: 0, strings_checked: 0, strings_matched: []
      try
        # dev https://docs.google.com/spreadsheets/d/1XA29lqVPCJ2FQ6siLywahxBTLFaDCZKaN5qUeoTuApg/edit#gid=0
        # live https://docs.google.com/spreadsheets/d/10DNDmOG19shNnuw6cwtCpK-sBnexRCCtD4WnxJx_DPQ/edit#gid=0
        for l in API.use.google.sheets.feed (if API.settings.dev then '1XA29lqVPCJ2FQ6siLywahxBTLFaDCZKaN5qUeoTuApg' else '10DNDmOG19shNnuw6cwtCpK-sBnexRCCtD4WnxJx_DPQ')
          try
            f.version_evidence.strings_checked += 1
            wts = l.whattosearch
            if wts.indexOf('<<') isnt -1 and wts.indexOf('>>') isnt -1
              wtm = wts.split('<<')[1].split('>>')[0]
              wts = wts.replace('<<'+wtm+'>>',meta[wtm.toLowerCase()]) if meta[wtm.toLowerCase()]?
            matched = false
            if l.howtosearch is 'string'
              wtsc = _clean wts
              matched = if (l.wheretosearch is 'file' and _clean(lowercontentsmall).indexOf(wtsc) isnt -1) or (l.wheretosearch isnt 'file' and ((meta.title? and _clean(meta.title).indexOf(wtsc) isnt -1) or (f.name? and _clean(f.name).indexOf(wtsc) isnt -1))) then true else false
            else
              re = new RegExp wts, 'gium'
              matched = if (l.wheretosearch is 'file' and lowercontentsmall.match(re) isnt null) or (l.wheretosearch isnt 'file' and ((meta.title? and meta.title.match(re) isnt null) or (f.name? and f.name.match(re) isnt null))) then true else false
            if matched
              sc = l.score ? l.score_value
              if typeof sc is 'string'
                try sc = parseInt sc
              sc = 1 if typeof sc isnt 'number'
              if l.whatitindicates is 'publisher pdf' then f.version_evidence.score += sc else f.version_evidence.score -= sc
              f.version_evidence.strings_matched.push {indicates: l.whatitindicates, found: l.howtosearch + ' ' + wts, in: l.wheretosearch, score_value: sc}

      f.version = 'publisher pdf' if f.version_evidence.score > 0
      f.version = 'postprint' if f.version_evidence.score < 0
      if f.version is 'unknown' and f.format? and f.format isnt 'pdf'
        f.version = 'postprint'
      f.version_standard = if f.version is 'preprint' then 'submittedVersion' else if f.version is 'postprint' then 'acceptedVersion' else if f.version is 'publisher pdf' then 'publishedVersion' else undefined

      try
        ls = API.service.lantern.licence undefined, undefined, lowercontentsmall # check lantern for licence info in the file content
        if ls?.licence?
          f.licence = ls.licence
          f.licence_evidence = {string_match: ls.match}
        f.lantern = ls

      f.archivable = false
      if confirmed
        f.archivable = true
        if confirmed is f.checksum
          f.archivable_reason = 'The administrator has confirmed that this file is a version that can be archived.'
          f.admin_confirms = true
        else
          f.archivable_reason = 'The depositor says that this file is a version that can be archived'
          f.depositor_says = true
      else if f.same_paper
        if f.format isnt 'pdf'
          f.archivable = true
          f.archivable_reason = 'Since the file is not a PDF, we assume it is a Postprint.'
        else
          if perms.ricks?.application?.can_archive_conditions?.versions_archivable? # the version we can tell it is appears to meet what Rick says can be posted
            if f.version in perms.ricks.application.can_archive_conditions.versions_archivable or f.version is 'postprint' and 'postprint' in perms.ricks.application.can_archive_conditions.versions_archivable
              f.archivable = true
              f.archivable_reason = 'We believe this is a ' + f.version + ' and our permission system says that version can be shared'
            else
              f.archivable_reason = 'We believe this file is a ' + f.version + ' version and our permission system does not list that as an archivable version'

          # https://github.com/OAButton/discussion/issues/1377
          if not f.archivable and perms.sherpa?
            if perms.sherpa.color is 'green'
              if f.version in ['preprint','postprint']
                f.archivable = true
                f.archivable_reason = 'Sherpa Romeo color is ' + perms.sherpa.color + ' so ' + f.version + ' is archivable'
              else
                f.archivable_reason = 'Sherpa Romeo color is ' + perms.sherpa.color + ' which allows only preprint or postprint but version is ' + f.version
            else if perms.sherpa.color is 'blue'
              if f.version in ['postprint']
                f.archivable = true
                f.archivable_reason = 'Sherpa Romeo color is ' + perms.sherpa.color + ' so ' + f.version + ' is archivable'
              else
                f.archivable_reason = 'Sherpa Romeo color is ' + perms.sherpa.color + ' which allows only postprint but version is ' + f.version
            else if perms.sherpa?.color is 'yellow'
              if f.version in ['preprint']
                f.archivable = true
                f.archivable_reason = 'Sherpa Romeo color is ' + perms.sherpa.color + ' so ' + f.version + ' is archivable'
              else
                f.archivable_reason = 'Sherpa Romeo color is ' + perms.sherpa.color + ' which allows only preprint but version is ' + f.version

        if not f.archivable and f.licence? and f.licence.toLowerCase().indexOf('cc') is 0
          f.archivable = true
          f.archivable_reason = 'It appears this file contains a ' + f.lantern.licence + ' licence statement. Under this licence the article can be archived'
        if not f.archivable
          if f.version is 'publisher pdf'
            f.archivable_reason = 'The file given is a Publisher PDF, and only postprints are allowed'
          else
            f.archivable_reason = 'We cannot confirm if it is an archivable version or not'
      else
        f.archivable_reason ?= if not f.same_paper_evidence.words_more_than_threshold then 'The file is less than 500 words, and so does not appear to be a full article' else if not f.same_paper_evidence.document_format then 'File is an unexpected format ' + f.format else if not meta.doi and not meta.title then 'We have insufficient metadata to validate file is for the correct paper ' else 'File does not contain expected metadata such as DOI or title'

  try perms.lantern = API.service.lantern.licence('https://doi.org/' + meta.doi) if not f.licence and meta.doi? and 'doi.org' not in url
  if f.archivable isnt undefined and f.archivable isnt true and perms.lantern?.licence? and perms.lantern.licence.toLowerCase().indexOf('cc') is 0
    f.licence = perms.lantern.licence
    f.licence_evidence = {string_match: perms.lantern.match}
    f.archivable = true
    f.archivable_reason = 'We think that the splash page the DOI resolves to contains a ' + perms.lantern.licence + ' licence statement which confirms this article can be archived'

  if f.archivable and not f.licence?
    if perms.ricks?.application?.can_archive_conditions?.deposit_statement_required_calculated? and perms.ricks.application.can_archive_conditions.deposit_statement_required_calculated.indexOf('cc') is 0
        f.licence = perms.ricks.application.can_archive_conditions.deposit_statement_required_calculated
    else if perms.sherpa?.publisher?.alias? and perms.sherpa.publisher.alias.toLowerCase().indexOf('cc-') isnt -1
      f.licence = 'cc-' + perms.sherpa.publisher.alias.toLowerCase().split('cc-')[1].split(' ')[0]

  perms.permissions.licence_required ?= f.licence if f.licence

  perms.file = f if not _.isEmpty f
  return perms

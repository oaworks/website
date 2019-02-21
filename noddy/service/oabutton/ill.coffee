

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

API.service.oab.ill = (opts) ->
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
        vars[o] = opts[o]
        vars.details += '<p>' + o + ': ' + opts[o] + '</p>'
      API.service.oab.mail({vars: vars, template: {filename:'instantill_create.html'}, to: user.emails[0].address})
      vars.illid = oab_ill.insert opts
      API.mail.send {
        service: 'openaccessbutton',
        from: 'requests@openaccessbutton.org',
        to: ['mark@cottagelabs.com','joe@righttoresearch.org'],
        subject: 'ILL CREATED',
        text: JSON.stringify(vars,undefined,2)
      }
      return vars.illid
    else
      return 401
  else
    return 404
    
API.service.oab.ill_progress = () ->
  # TODO need a function that can lookup ILL progress from the library systems some how
  return
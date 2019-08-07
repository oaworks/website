


API.service.oab.receive = (rid,files,url,title,description,firstname,lastname,cron,admin) ->
  r = oab_request.find {receiver:rid}
  description ?= r.description if typeof r.description is 'string'
  description ?= r.received.description if r.received? and typeof r.received.description is 'string'
  if not r
    return 404
  else if (r.received?.url or r.received?.zenodo) and not admin
    return 400
  else
    today = new Date().getTime()
    r.received ?= {}
    r.received.date ?= today
    r.received.from ?= r.email
    r.received.description ?= description
    r.received.validated ?= false
    r.received.admin = admin
    r.received.cron = cron
    up = {}
    if url?
      r.received.url = url
    else
      if files? and files.length > 0
        up.content = files[0].data
        up.name = files[0].filename
      up.publish = API.settings.service.openaccessbutton?.zenodo?.publish or r.received.admin
      creators = []
      if r.names
        try
          r.names = r.names.replace(/\[/g,'').replace(/\]/g,'').split(',') if typeof r.names is 'string'
          for n in r.names
            creators.push {name: n}
      if creators.length is 0
        creators = [{name:(if lastname or firstname then '' else 'Unknown')}]
        creators[0].name = lastname if lastname
        creators[0].name += (if lastname then ', ' else '') + firstname if firstname
        creators[0].name = r.name if creators[0].name is 'Unknown' and r.name
        if creators[0].name is 'Unknown' and r.author
          try
            for a in r.author
              if a.family and ( creators[0].name is 'Unknown' or r.email.toLowerCase().indexOf(a.family.toLowerCase()) isnt -1 )
                creators[0].name = a.family
                creators[0].name += (if a.family then ', ' else '') + a.given if a.given
      # http://developers.zenodo.org/#representation
      # journal_volume and journal_issue are acceptable too but we don't routinely collect those
      # access_right can be open embargoed restricted closed
      # if embargoed can also provide embargo_date
      # can provide access_conditions which is a string sentence explaining what conditions we will allow access for
      # license can be a string specifying the license type for open or embargoed content, using opendefinition license tags like cc-by
      meta =
        title: title ? (if r.title then r.title else (if r.url.indexOf('h') isnt 0 and r.url.indexOf('1') isnt 0 then r.url else 'Unknown')),
        description: description ? "Deposited from Open Access Button",
        creators: creators,
        doi: r.doi,
        keywords: r.keywords,
        version: 'AAM',
        journal_title: r.journal,
        prereserve_doi: API.settings.service.openaccessbutton?.zenodo?.prereserve_doi and not r.doi?
      try meta['access_right'] = r['access_right'] if typeof r['access_right'] is 'string' and r['access_right'] in ['open','embargoed','restricted','closed']
      try meta['embargo_date'] = r['embargo_date'] if r['embargo_date']? and meta['access_right'] is 'embargoed'
      try meta['access_conditions'] = r['access_conditions'] if typeof r['access_conditions'] is 'string'
      try meta.license = r.license if typeof r.license is 'string'
      try meta['publication_date'] = r.published if r.published? and typeof r.published is 'string' and r.length is 10
      z = API.use.zenodo.deposition.create meta, up, API.settings.service.openaccessbutton?.zenodo?.token
      r.received.zenodo = 'https://zenodo.org/record/' + z.id if z.id
      r.received.zenodo_doi = z.metadata.prereserve_doi.doi if z.metadata?.prereserve_doi?.doi?
        
    oab_request.update r._id, {hold:'$DELETE',received:r.received,status:(if up.publish is false and not r.received.url? then 'moderate' else 'received')}
    API.service.oab.admin(r._id,'successful_upload') if up.publish
    API.mail.send
      service: 'openaccessbutton'
      from: 'requests@openaccessbutton.org'
      to: API.settings.service.openaccessbutton.notify.receive
      subject: 'Request ' + r._id + ' received' + (if r.received.url? then ' - URL provided' else (if up.publish is false then ' - zenodo publish required' else ' - file published on Zenodo'))
      text: (if API.settings.dev then 'https://dev.openaccessbutton.org/request/' else 'https://openaccessbutton.org/request/') + r._id
    return {data: r}


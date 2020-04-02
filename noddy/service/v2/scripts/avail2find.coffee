
import unidecode from 'unidecode'

@oab_availability = new API.collection {index:"oab",type:"availability"}

API.add 'service/oab/scripts/avail2find',
  get: 
    roleRequired: 'root'
    action: () ->
      dev = true
      processed = 0
      find_saves = []
      catalogue_saves = []
      catalogue_updates = []

      process = (rec) ->
        processed += 1
        if find_saves.length is 1000
          console.log processed
          oab_find.insert find_saves, undefined, undefined, undefined, undefined, undefined, dev
          find_saves = []
        if catalogue_saves.length is 1000
          oab_catalogue.insert catalogue_saves, undefined, undefined, undefined, undefined, undefined, dev
          catalogue_saves = []
        if catalogue_updates.length is 1000
          oab_catalogue.bulk catalogue_updates, 'update', undefined, undefined, dev
          catalogue_updates = []

        res = {}
        res.url = rec.availability[0].url if rec.availability? and rec.availability.length
        res.sources = rec.sources ? []
        res.checked = res.checked ? []
        if rec.bing
          res.sources.push 'bing'
          res.checked.push('bing') if 'bing' not in res.checked
        if rec.reversed
          res.sources.push 'reverse'
          res.checked.push('reverse') if 'reverse' not in res.checked
        if rec.scraped
          res.sources.push 'scrape'
          res.checked.push('scrape') if 'scrape' not in res.checked
        res.refresh = rec.refresh ? 30
        res.refresh = 0 if res.refresh is true
        if typeof res.refresh isnt 'number'
          try
            n = parseInt res.refresh
            res.refresh = if isNaN(n) then 0 else n
          catch
            res.refresh = 0
        res.cached = true if rec.cache
        res.capped = true if rec.capped
        res.found = rec.found ? {}
        if typeof rec.source?.article is 'string' and res.url?
          if res.source is 'doaj'
            res.metadata.journal ?= res.url
          else
            res.found[rec.source.article] = res.url
          res.checked.push(rec.source.article) if rec.source.article not in res.checked
        for nm in ['exlibris','test','from','plugin','uid','username','email','all','find','embedded','pilot','live','wrong']
          res[nm] = rec[nm] if rec[nm]?
          if nm in ['pilot','live'] and typeof res[nm] is 'boolean'
            res[nm] = if res[nm] is true then Date.now() else undefined
        res.find ?= true
        res.ill = rec.ill if rec.ill?
        
        res.metadata = rec.meta?.article ? {}
        delete res.metadata.subject if res.metadata.subject?
        delete res.metadata.title if res.metadata.title? and (res.metadata.title is 404 or res.metadata.title.indexOf('404') is 0)
        if res.metadata.author?
          delete res.metadata.author if typeof res.metadata.author is 'string'
          delete res.metadata.author if _.isArray res.metadata.author and res.metadata.author.length > 0 and typeof res.metadata.author[0] is 'string'
        if res.metadata.year?
          try
            for ms in res.metadata.year.split('/')
              res.metadata.year = ms if ms.length is 4
          try
            for md in res.metadata.year.split('-')
              res.metadata.year = md if md.length is 4
          try
            delete res.metadata.year if typeof res.metadata.year isnt 'number' and (res.metadata.year.length isnt 4 or res.metadata.year.replace(/[0-9]/gi,'').length isnt 0)
        if not res.metadata.year? and res.metadata.published?
          try
            mps = res.metadata.published.split('-')
            res.metadata.year = mps[0] if mps[0].length is 4
        if res.metadata.year?
          try
            delete res.metadata.year if typeof res.metadata.year isnt 'number' and (res.metadata.year.length isnt 4 or res.metadata.year.replace(/[0-9]/gi,'').length isnt 0)
          catch
            delete res.metadata.year
        
        if rec.url or rec.match
          u = if typeof rec.url is 'string' and rec.url.indexOf('http') is 0 then rec.url else if typeof rec.match is 'string' and rec.match.indexOf('http') is 0 then rec.match else undefined
          if u and u.indexOf('doi.org') is -1 and u.indexOf('europepmc.org') is -1
            res.metadata ?= []
            res.metadata.push(u) if u not in res.metadata

        find_saves.push res

        if JSON.stringify(res.metadata) isnt '{}' and res.test isnt true
          if catalogued = oab_catalogue.finder res.metadata
            upd = {}
            upd.url = res.url if res.url? and res.url isnt catalogued.url
            upd.metadata = res.metadata if not _.isEqual res.metadata, catalogued.metadata
            upd.sources = _.union(res.sources, catalogued.sources) if JSON.stringify(res.sources.sort()) isnt JSON.stringify catalogued.sources.sort()
            uc = _.union res.checked, catalogued.checked
            upd.checked = uc if JSON.stringify(uc.sort()) isnt JSON.stringify catalogued.checked.sort()
            uf = _.extend(res.found, catalogued.found)
            upd.found = uf if not _.isEqual uf, catalogued.found
            if typeof res.metadata.title is 'string'
              ftm = API.service.oab.ftitle(res.metadata.title)
              upd.ftitle = ftm if ftm isnt catalogued.ftitle
            if not _.isEmpty upd
              upd._id = catalogued._id
              catalogue_updates.push upd
          else
            fl = 
              url: res.url
              metadata: res.metadata
              sources: res.sources
              checked: res.checked
              found: res.found
            fl.ftitle = API.service.oab.ftitle(res.metadata.title) if typeof res.metadata.title is 'string'
            catalogue_saves.push fl

      #actioned = oab_availability.each '*', undefined, process, undefined, undefined, undefined, dev
      
      if find_saves.length
        oab_find.insert find_saves, undefined, undefined, undefined, undefined, undefined, dev
      if catalogue_saves.length
        oab_catalogue.insert catalogue_saves, undefined, undefined, undefined, undefined, undefined, dev
      if catalogue_updates.length
        oab_catalogue.bulk catalogue_updates, 'update', undefined, undefined, dev

      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'Availabilities to finds complete'
        text: 'Availabilities found and processed: ' + processed
      return processed





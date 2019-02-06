
import fs from 'fs'
import moment from 'moment'
import { Random } from 'meteor/random'
import Future from 'fibers/future'

###API.add 'service/oab/scripts/blog_issue_rebuild',
  get: 
    roleRequired: 'root'
    action: () ->
      urls = []
      updates = []
      recs = JSON.parse(fs.readFileSync('/home/cloo/backups/oabutton_full_old_old_05032018.json'))
      console.log recs.hits.hits.length

      old_ratings = API.convert.csv2json(fs.readFileSync('/home/cloo/oabutton_ratings.csv').toString())
      story_ratings = {}
      for rate in old_ratings
        if rate.Story? and typeof rate.Story is 'string'
          story_ratings[rate.Story.toLowerCase()] = rate

      new_ratings = API.convert.csv2json(fs.readFileSync('/home/cloo/oabutton_ratings_withID_13072018.csv').toString())
      console.log new_ratings[0]
      ratings = {}
      for rating in new_ratings
        ratings[rating._id] = rating

      counter = 0
      for rec in recs.hits.hits
        counter += 1
        console.log counter
        console.log updates.length
        rec = rec._source
        rec.type ?= 'article'
        if rec.type is 'article' and not rec.request? and rec.test isnt true and rec.story and urls.indexOf(rec.url) is -1 and not oab_request.get(rec._id,undefined,false)? and not oab_request.get({url:rec.url},undefined,false)?
          delete rec.email if rec.email? and rec.email is 'None'
          if not rec.rating?
            if rec.story? and story_ratings[rec.story.toLowerCase()]?
              rec.rating = story_ratings[rec.story.toLowerCase()].Rating
            if ratings[rec._id]?
              rec.rating = ratings[rec._id].rating
          if rec.rating?
            rec.rating = parseInt(rec.rating) if typeof rec.rating is 'string'
            rec.rating = if rec.rating >= 3 then 1 else 0
          if not rec.email? or (rec.email.indexOf('cottagelabs.com') is -1 and rec.email.indexOf('joe@') is -1 and rec.email.indexOf('natalianorori') is -1 and rec.email.indexOf('n/a') is -1)
            urls.push rec.url
            rec.legacy ?= {}
            rec.legacy.blog_issue_reload = true
            if rec.metadata?
              if rec.metadata.journal?.name?
                if typeof rec.metadata.journal.name is 'string' and rec.metadata.journal.name.length > 1 and rec.metadata.journal.name.indexOf('\\') is -1 and rec.metadata.journal.name.indexOf('by ') isnt 0 and rec.metadata.journal.name.indexOf('info') isnt 0
                  rec.journal ?= rec.metadata.journal.name.trim()
              if rec.metadata.title? and rec.metadata.title.length > 1
                rec.title ?= rec.metadata.title
              if rec.metadata.identifier? and rec.metadata.identifier.length > 0 and rec.metadata.identifier[0].type? and rec.metadata.identifier[0].type.toLowerCase() is 'doi' and rec.metadata.identifier[0].id?
                rec.doi = rec.metadata.identifier[0].id
              if rec.metadata.author?
                for author in rec.metadata.author
                  if author.name? and author.name.indexOf('\\') is -1
                    rec.author ?= []
                    rec.author.push author
              delete rec.metadata
              delete rec.description if rec.description?
              if rec.coords_lat
                rec.location ?= {}
                rec.location.geo ?= {}
                rec.location.geo.lat = rec.coords_lat
                delete rec.coords_lat
              if rec.coords_lng
                rec.location ?= {}
                rec.location.geo ?= {}
                rec.location.geo.lon = rec.coords_lng
                delete rec.coords_lng
              rec.created_date = moment(rec.createdAt, "x").format("YYYY-MM-DD HHmm.ss") if not rec.created_date?
              if rec.user?
                if typeof rec.user is 'string'
                  uid = rec.user
                  rec.user = {}
                else
                  uid = rec.user.id
                user = API.accounts.retrieve uid
                if not user?
                  delete rec.user # keep the request but remove the user info
                else
                  rec.user.email ?= user.emails[0].address
                  rec.user.username ?= user.profile?.firstname ? user.username ? user.emails[0].address
                  rec.user.firstname ?= user.profile?.firstname
                  rec.user.lastname ?= user.profile?.lastname
                  rec.user.affiliation ?= user.service?.openaccessbutton?.profile?.affiliation
                  rec.user.profession ?= user.service?.openaccessbutton?.profile?.profession
              updates.push rec
      
      fs.writeFileSync '/home/cloo/oabutton_blog_issue_imports.json', JSON.stringify updates
      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'Blog issue rebuild complete'
        text: 'updates: ' + updates.length
      return {count: updates.length}



API.add 'service/oab/scripts/blog_issue_process',
  get: 
    roleRequired: 'root'
    action: () ->
      imports = JSON.parse(fs.readFileSync('/home/cloo/oabutton_blog_issue_imports.json'))
      processed = 0
      blacklisted = 0
      counter = 0
      alreadyIDs = []
      if not fs.existsSync('/home/cloo/oabutton_blog_issue_imports_processed.json')
        fs.writeFileSync '/home/cloo/oabutton_blog_issue_imports_processed.json', ''
      else
        prev = JSON.parse('[' + fs.readFileSync('/home/cloo/oabutton_blog_issue_imports_processed.json') + ']')
        for pr in prev
          alreadyIDs.push pr._id
          console.log alreadyIDs.length + ' already done'
      if imports.length > 0
        console.log imports.length + ' records to process'
        for req in imports
          counter += 1
          console.log counter
          console.log processed
          req.type ?= 'article'
          if req._id in alreadyIDs
            processed += 1
          else if req.url? and not API.service.oab.blacklist req.url
            future = new Future()
            Meteor.setTimeout (() -> future.return()), 800
            future.wait()
            try
              req.count = if req.story then 1 else 0
              if not req.title or not req.email
                meta = API.service.oab.scrape req.url, undefined, req.doi
                if meta?.email?
                  for e in meta.email
                    isauthor = false
                    if meta?.author?
                      for a in meta.author
                        isauthor = a.family and e.toLowerCase().indexOf(a.family.toLowerCase()) isnt -1
                    if isauthor and not API.service.oab.dnr(e) and API.mail.validate(e, API.settings.service?.openaccessbutton?.mail?.pubkey).is_valid
                      req.email = e
                      break
                req.keywords ?= meta?.keywords ? []
                req.title ?= meta?.title ? ''
                req.doi ?= meta?.doi ? ''
                req.author = meta?.author ? []
                req.journal = meta?.journal ? ''
                req.issn = meta?.issn ? ''
                req.publisher = meta?.publisher ? ''
                req.year = meta?.year
  
              if req.doi and (not req.journal or not req.year)
                try
                  cr = API.use.crossref.works.doi req.doi
                  req.title = cr.title[0]
                  req.author ?= cr.author
                  req.journal ?= cr['container-title'][0] if cr['container-title']?
                  req.issn ?= cr.ISSN[0] if cr.ISSN?
                  req.subject ?= cr.subject
                  req.publisher ?= cr.publisher
                  req.year = cr['published-print']['date-parts'][0][0] if cr['published-print']?['date-parts']? and cr['published-print']['date-parts'].length > 0 and cr['published-print']['date-parts'][0].length > 0
                  req.year ?= cr.created['date-time'].split('-')[0] if cr.created?['date-time']?
  
              req.status ?= if not req.story or not req.title or not req.email or not req.user? then "help" else "moderate"
              if req.journal and not req.sherpa?
                try
                  sherpa = API.use.sherpa.romeo.search {jtitle:req.journal}
                  req.sherpa = {color:sherpa.publishers[0].publisher[0].romeocolour[0]}
              if req.year
                try
                  req.year = parseInt(req.year) if typeof req.year is 'string'
                  if req.year < 2000
                    req.status = 'closed'
                    req.closed_on_create = true
              if req.sherpa?.color? and typeof req.sherpa.color is 'string' and req.sherpa.color.toLowerCase() is 'white'
                req.status = 'closed'
                req.closed_on_create = true
  
              if req.location?.geo
                req.location.geo.lat = Math.round(req.location.geo.lat*1000)/1000 if req.location.geo.lat
                req.location.geo.lon = Math.round(req.location.geo.lon*1000)/1000 if req.location.geo.lon
  
              req.receiver ?= Random.id()
              
              if req.title? and typeof req.title is 'string'
                try req.title = req.title.charAt(0).toUpperCase() + req.title.slice(1)
              if req.journal? and typeof req.journal is 'string'
                try req.journal = req.journal.charAt(0).toUpperCase() + req.journal.slice(1)
              
              processed += 1
              if alreadyIDs.length or counter > 1
                fs.appendFileSync '/home/cloo/oabutton_blog_issue_imports_processed.json', ',\n'
              fs.appendFileSync '/home/cloo/oabutton_blog_issue_imports_processed.json', JSON.stringify req

          else
            blacklisted += 1

      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'Blog issue processing complete'
        text: 'imports: ' + imports.length + '\nprocessed: ' + processed.length + '\nalready processed: ' + alreadyIDs.length + '\nblacklisted: ' + blacklisted
      return {count: imports.length}


# got 3884 records from old files
# processing them left 3817
# 55 were blacklisted, 12 did not work for other reasons
# 3757 have title, 3276 have doi, 2295 have sherpa

API.add 'service/oab/scripts/blog_issue_load',
  get: 
    roleRequired: 'root'
    action: () ->
      imports = JSON.parse('[' + fs.readFileSync('/home/cloo/oabutton_blog_issue_imports_processed.json') + ']')
      if imports.length > 0
        oab_request.import imports, false
        
      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'Blog issue load complete'
        text: 'imports: ' + imports.length
      return {count: imports.length}

API.add 'service/oab/scripts/blog_issue_check',
  get: 
    action: () ->
      imports = JSON.parse('[' + fs.readFileSync('/home/cloo/oabutton_blog_issue_imports_processed.json') + ']')
      found = 0
      added = []
      for imp in imports
        if oab_request.get(imp._id, undefined, false)
          found += 1
        else
          if imp.legacy?.id?
            imp.legacy.tid = imp.legacy.id.toString()
            delete imp.legacy.id
          oab_request.insert(imp,undefined,undefined,undefined,false)
          added.push imp._id

      txt = 'found: ' + found + '\nadded:\n'
      for ad in added
        txt += ad + '\n'
      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'Blog issue check complete'
        text: txt

      return {found: found, added: added}

API.add 'service/oab/scripts/blog_issue_datefix',
  get: 
    action: () ->
      imports = JSON.parse('[' + fs.readFileSync('/home/cloo/oabutton_blog_issue_imports_processed.json') + ']')
      dateimports = []
      for imp in imports
        rq = oab_request.get(imp._id, undefined, false)
        if rq.legacy?.tid?
          imp.legacy.tid = imp.legacy.id.toString()
          delete imp.legacy.id
          dateimports.push imp

      if dateimports.length
        oab_request.import dateimports, false

      return {fixed: dateimports.length}
###

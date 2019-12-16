
import fs from 'fs'

API.add 'service/oab/scripts/illiad_comparison',
  get: 
    roleRequired: 'root'
    action: () ->
      titles = oab_availability.search 'from:illiad AND NOT url:http* AND NOT url:pmid* AND NOT url:pmc*', {newest:true, size:1000}, undefined, false
      console.log titles.hits.total

      tried = 0
      oldfound = 0
      newfound = 0
      
      outfile = '/home/cloo/static/illiad_comparison.csv'

      fs.writeFileSync outfile, 'live_title,live_discovered_article,dev_bing,dev_reversed,dev_source,dev_doi,dev_discovered_article'
      
      for t in titles.hits.hits
        tried += 1
        oldfound += 1 if t._source.discovered?.article
        fs.appendFileSync outfile, '\n"' + t._source.url.replace(/"/g,'') + '","' + (if t._source.discovered.article then t._source.discovered.article.replace(/"/g,'') else '') + '",'
        try
          ret = API.service.oab.find url:t._source.url, refresh: 0
          if ret?.meta?.article?
            fs.appendFileSync outfile, '"' + ret.meta.article.bing + '","' + ret.meta.article.reversed + '",'
            fs.appendFileSync outfile, '"' + (ret.meta.article.source ? '') + '","' + (ret.meta.article.doi ? '') + '",'
            if ret.meta.article.url and ret.meta.article.source and ret.meta.article.redirect isnt false and not ret.meta.article.journal_url
              newfound += 1
              fs.appendFileSync outfile, '"' + (if typeof ret.meta.article.redirect is 'string' then ret.meta.article.redirect else ret.meta.article.url).replace(/"/g,'') + '"'
          else
            fs.appendFileSync outfile, ',,,,'
        catch
          fs.appendFileSync outfile, ',,,,'
        console.log tried, oldfound, newfound

      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'Illiad comparison complete'
        text: 'Query returned ' + titles.hits.total + '\nTried ' +  tried + '\nOld found ' + oldfound + '\nNew found ' + newfound + (if outfile.indexOf('/home/cloo/static/') is 0 then '\n\nhttps://static.cottagelabs.com/' + outfile.replace('/home/cloo/static/','') else '')
      return tried: tried, oldfound: oldfound, newfound: newfound


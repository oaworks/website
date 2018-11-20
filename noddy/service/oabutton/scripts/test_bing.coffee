
import fs from 'fs'
import Future from 'fibers/future'

API.add 'service/oab/scripts/test_bing',
  get: 
    roleRequired: 'root'
    action: () ->
      titles = oab_availability.search 'from:illiad AND discovered.article:false AND NOT url:http* AND NOT url:pmid*', {newest:false, size:1000}, undefined, false
      console.log titles.hits.total

      tried = 0
      found = 0
      matches = 0
      
      outfile = '/home/cloo/static/MS_titles_bing_results_2.csv'

      fs.writeFileSync outfile, 'title,bing_url,bing_title,title_confirmed,accepted_title,scraped_doi,match'
      
      for t in titles.hits.hits
        tried += 1
        console.log tried, found, matches
        try
          title = t._source.url.replace('TITLE:','').replace('CITATION:','').replace(/[^a-zA-Z0-9\-]+/g, " ")
          title = title.replace('pmid','pmid ') if title.indexOf('pmid') is 0
          title = title.replace('pmc','pmc ') if title.indexOf('pmc') is 0
          if title.length < 250 # there are some titles entered into the system that are too long and cause an error so ignore them
            fs.appendFileSync outfile, '\n"' + title.replace(/"/g,'') + '",'
            scraped = {}
            future = new Future()
            Meteor.setTimeout (() -> future.return()), 500
            future.wait()
            try
              bing = API.use.microsoft.bing.search title
              title = title.replace(/\-/g,'')
              if bing.data? and bing.data.length > 0 and bing.data[0].url
                found += 1
                fs.appendFileSync outfile, '"' + bing.data[0].url.replace(/"/g,'') + '"'
              fs.appendFileSync outfile, ','
              if bing.data? and bing.data.length > 0 and bing.data[0].name
                fs.appendFileSync outfile, '"' + bing.data[0].name.replace(/"/g,'') + '"'
              fs.appendFileSync outfile, ','
              try
                if bing.data[0].url.toLowerCase().indexOf('.pdf') is -1
                  scraped = API.service.oab.scrape bing.data[0].url
                  try fs.appendFileSync outfile, '"scraped","' + scraped.title.replace(/"/g,'') + '"'
                  fs.appendFileSync outfile, ','
                  try fs.appendFileSync outfile, '"' + scraped.doi.replace(/"/g,'') + '"'
                else if title.replace(/[^a-z0-9]+/g, "").indexOf(bing.data[0].url.toLowerCase().split('.pdf')[0].split('/').pop().replace(/[^a-z0-9]+/g, "")) is 0
                  try fs.appendFileSync outfile, '"url","' + bing.data[0].url.toLowerCase().split('.pdf')[0].split('/').pop() + '"'
                  fs.appendFileSync outfile, ','
                else
                  content = API.convert.pdf2txt(bing.data[0].url)
                  content = content.substring(0,1000) if content.length > 1000
                  content = content.toLowerCase().replace(/[^a-z0-9]+/g, "").replace(/\s\s+/g, '')
                  if content.indexOf(title.replace(/ /g, '').toLowerCase()) isnt -1
                    try fs.appendFileSync outfile, '"pdf","' + title + '"'
                  else
                    fs.appendFileSync outfile, ','
                  fs.appendFileSync outfile, ','
              catch
                fs.appendFileSync outfile, ',,'
            catch
              fs.appendFileSync outfile, ',,,,'
            fs.appendFileSync outfile, ','
            try
              matched = title.toLowerCase().replace(/ /g,'').replace(/\s\s+/g, '').indexOf(bing.data[0].name.toLowerCase().replace('(pdf)','').replace(/[^a-z0-9]+/g, "").replace(/\s\s+/g, '')) is 0
              matches += 1 if matched
              fs.appendFileSync outfile, '"' + (if matched then 'Yes' else 'No') + '"'

      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'MS titles bing test complete'
        text: 'Query returned ' + titles.hits.total + '\nTried ' +  tried + '\nFound ' + found + '\n Matched ' + matches
      return tried: tried, found: found, matches: matches



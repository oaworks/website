
import fs from 'fs'
import Future from 'fibers/future'

API.add 'service/oab/scripts/test_bing',
  get: 
    roleRequired: 'root'
    action: () ->
      titles = oab_availability.search 'discovered.article:false AND NOT url:http*', {newest:true, size:10}, undefined, false
      found = 0
      matches = 0
      results = 'title,bing,scraped_title,scraped_doi,match'
      for t in titles.hits.hits
        title = t._source.url
        results.append '\n'
        results.append title + ','
        scraped = {}
        future = new Future()
        Meteor.setTimeout (() -> future.return()), 200
        future.wait()
        try
          bing = API.use.microsoft.bing.search title
          if bing.data? and bing.data.length > 0 and bing.data[0].url
            found += 1
            results.append bing.data[0].url
          results.append ','
          try
            scraped = API.service.oab.scrape title
            try results.append scraped.title
            results.append ','
            try results.append scraped.doi
          catch
            results.append ','
        catch
          results.append ',,'
        results.append ','
        try
          matched = title.toLowerCase().replace(/ /g,'') is scraped.title.toLowerCase().replace(/ /g,'')
          matches += 1 if matched
          results.append if matched then 'Yes' else 'No'

      fs.writeFileSync '/home/cloo/static/MS_titles_bing_results.csv', results
      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'MS titles bing test complete'
        text: 'Found ' + found + ', matched ' + matches
      return true

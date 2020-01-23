
API.add 'service/oab/scripts/zenodofiles',
  csv: true
  get: 
    action: () ->
      res = []
      recs = HTTP.call('GET', 'https://api.openaccessbutton.org/requests?q=received.zenodo:*%20AND%20NOT%20undefined&fields=received.zenodo&size=200').data
      for rec in recs.hits.hits
        try
          url = rec.fields['received.zenodo'][0]
          pg = API.http.puppeteer url
          fl = 'https://zenodo.org/' + pg.split('<a class="filename" href="')[1].split('">')[0]
          res.push fl
      return res
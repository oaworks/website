

'''API.add 'service/oab/scripts/fix_bot_refused',
  get: 
    roleRequired: 'root'
    action: () ->
      # query the live log for API hits on the receiver refuse endpoint by googlebot
      updates = 0
      res = API.es.call 'POST', API.settings.es.index + '_log/_search?size=2500&q=url:*refuse* AND url:*receive* AND url:*oab* AND headers:*google*', undefined, undefined, undefined, undefined, undefined, undefined, false
      console.log res.hits.total
      for r in res.hits.hits
        try
          rec = r._source
          if rec.url.indexOf('/api/service/oab/receive') is 0
            receiver = rec.url.replace('/api/service/oab/receive/','').replace('/refuse','')
            req = oab_request.find {receiver:receiver,status:'refused'}, undefined, undefined, false
            if req? and req.refused? and req.refused.length is 1
              updates += 1
              updated = oab_request.update req._id, {status:'progress',email:req.refused[0].email,refused:'$DELETE'}, undefined, undefined, undefined, undefined, false
              console.log updated
      return updates'''

'''
API.add 'service/oab/scripts/fix_professions',
  get: 
    roleRequired: 'root'
    action: () ->
      professions = ['Student','Health professional','Patient','Researcher','Librarian']
      fix = (req) ->
        if req.user?
          if req.user.profession
            p = req.user.profession[0].toUpperCase() + req.user.profession.substring(1,req.user.profession.length)
            if professions.indexOf(p) is -1
              if p.toLowerCase() is 'academic'
                p = 'Researcher'
              else if req.user.profession.toLowerCase() is 'doctor'
                p = 'Health professional'
              else
                p = 'Other'
            if p isnt req.user.profession
              req.user.profession = p
              return {_id:req._id,'user':req.user}
          else
            req.user.profession = 'Other'
            return {_id:req._id,'user':req.user}

      updates = oab_request.each 'user.email:*', undefined, fix, 'update', undefined, undefined, false

      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'Fix professions complete'
        text: 'total: ' + updates.total +  '\nprocessed: ' + updates.processed +  '\nupdated: ' + updates.updated
      return updates
'''




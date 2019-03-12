
'''API.add 'service/oab/scripts/fix_crossref_closure',
  get: 
    roleRequired: 'root'
    action: () ->
      csv = 'rid,story,name,email,status'
      processed = 0
      counter = 0
      emails = 0
      
      fix = (req) ->
        processed += 1
        status = if req.rating is 0 or req.rating is "0" then 'closed' else if req.rating then 'progress' else if req.story then 'moderate' else 'help'
        rep = {status: status, closed_on_update: '$DELETE', closed_on_update_reason: '$DELETE'}
        if not req.doi
          rep.closed_on_update = true
          rep.closed_on_update_reason = 'nodoi'
          rep.status = 'closed'
        else if rep.status isnt 'closed'
          counter += 1

        csv += '\n' + req._id + ',' + (if req.story then 'Yes' else 'No') + ',' + (req.user?.firstname ? req.user?.username ? '') + ',' + (req.user?.email ? '') + ',' + rep.status
        emails += 1 if req.user?.email? and req.story and rep.status isnt 'closed'
        oab_request.update req._id, rep, undefined, undefined, undefined, undefined, false

      # 490 requests were set closed because we had no crossref_type at all
      # but in these cases, only 191 have a DOI so 299 remain closed as nodoi anyway
      # none of the 490 got as far as finding year or sherpa data, so would not have been closed for those reasons yet
      #updates = oab_request.each 'closed_on_create_reason:notarticle AND NOT crossref_type:*', undefined, fix, undefined, undefined, undefined, false

      # 218 were closed on update, all for notarticle (which is the only one we currently try to set on update)
      # but they all do have crossref_type of journal-article, the bug in the code just accidentally closed them anyway because it did not need to re-do the search
      # all with DOI are within year range etc (or would already have been legit closed) so would not have been closed for that
      # 35 have no DOI, so get closed anyway, leaving 183
      updates2 = oab_request.each 'closed_on_update_reason:notarticle', undefined, fix, undefined, undefined, undefined, false
      
      console.log processed, counter, emails, updates, updates2

      #API.mail.send
      #  to: ['alert@cottagelabs.com','joe@openaccessbutton.org']
      #  subject: 'Fix crossref closure complete'
      #  text: 'Requests found and processed: ' + processed + '\nRequests to change from closed: ' + counter + '\nPeople to email: ' + emails + '\nRequests processed from closed on create: ' + updates + '\nRequests processed from closed on update: ' + updates2 + '\n\n' + csv
      return [processed,counter,emails,updates,updates2]

'''


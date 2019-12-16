
'''API.add 'service/oab/scripts/clean_availabilities',
  get: 
    roleRequired: 'root'
    action: () ->
      processed = 0

      fix = (rec) ->
        processed += 1
        delete rec.apikey
        console.log processed
        return rec

      actioned = oab_availability.each 'apikey:*', undefined, fix, 'insert', undefined, undefined, false
      
      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'Clean availabilities complete'
        text: 'Availabilities found and processed: ' + processed + '\nActioned: ' + JSON.stringify actioned
      return processed'''




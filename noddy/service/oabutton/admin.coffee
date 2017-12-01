
API.service = {} if not API.service?
API.service.oab = {}

API.service.oab.admin = (rid,action) ->
  r = oab_request.get rid
  vars = API.service.oab.vars r
  usermail
  if r.user?.id
    u = API.accounts.retrieve r.user.id
    usermail = u.emails[0].address
  update = {}
  requestors = []
  requestors.push(usermail) if usermail
  oab_support.each {rid:rid}, (s) -> requestors.push(s.email) if s.email and s.email not in requestors
  if action is 'send_to_author'
    update.status = 'progress'
    update.rating = 1 if r.story
    API.service.oab.mail({vars:vars,template:{filename:'requesters_request_inprogress.html'},to:requestors}) if requestors.length
    if r.type is 'article'
      if r.email
        if r.story
          API.service.oab.mail({vars:vars,template:{filename:'author_request_article_v2.html'},to:r.email})
        else
          API.service.oab.mail({vars:vars,template:{filename:'author_request_article_v2_nostory.html'},to:r.email})
    else if r.email
      API.service.oab.mail({vars:vars,template:{filename:'author_request_data_v2.html'},to:r.email})
  else if action is 'story_too_bad'
    update.rating = 0
    API.service.oab.mail({vars:vars,template:{filename:'requesters_request_inprogress.html'},to:requestors}) if requestors.length
    API.service.oab.mail({vars:vars,template:{filename:'author_request_article_v2_nostory.html'},to:r.email}) if r.email
  else if action is 'not_a_scholarly_article'
    update.status = 'closed'
    API.service.oab.mail({vars:vars,template:{filename:'initiator_invalid.html'},to:usermail}) if usermail
  else if action is 'dead_author'
    update.status = 'closed'
    API.service.oab.mail({vars:vars,template:{filename:'requesters_request_failed_authordeath.html'},to:requestors}) if requestors.length
  else if action is 'user_testing'
    update.test = true
    update.status = 'closed'
    update.rating = 0 if r.story
    API.service.oab.mail({vars:vars,template:{filename:'initiator_testing.html'},to:usermail}) if usermail
  else if action is 'broken_link' and usermail
    API.service.oab.mail({vars:vars,template:{filename:'initiator_brokenlink.html'},to:usermail})
  else if action is 'remove_submitted_url'
    update.status = 'moderate'
    update.received = false
  oab_request.update(rid,update) if JSON.stringify(update) isnt '{}'


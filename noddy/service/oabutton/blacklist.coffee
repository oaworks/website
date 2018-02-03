

# the blacklist is for sites we won't allow finds / requetsts to operate on

API.service.oab.blacklist = (url,stale=360000) ->
  API.log msg: 'Checking OAB blacklist', url: url
  stale = 0 if stale is false
  return false if url? and (url.length < 4 or url.indexOf('.') is -1)
  bl = API.use.google.sheets.feed API.settings.service.openaccessbutton?.google?.sheets?.blacklist, stale
  blacklist = []
  blacklist.push(i.url) for i in bl
  if url
    for b in blacklist
      return true if url.indexOf(b) isnt -1
    return false
  else
    return blacklist


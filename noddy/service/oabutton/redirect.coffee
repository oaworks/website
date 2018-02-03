

# LIVE: https://docs.google.com/spreadsheets/d/1Te9zcQtBLq2Vx81JUE9R42fjptFGXY6jybXBCt85dcs/edit#gid=0
# Develop: https://docs.google.com/spreadsheets/d/1AaY7hS0D9jtLgVsGO4cJuLn_-CzNQg0yCreC3PP3UU0/edit#gid=0

API.service.oab.redirect = (url) ->
  API.log msg: 'Checking OAB open list', url: url
  url = API.http.resolve url # will return undefined if the url doesn't resolve at all
  if url
    return false if API.service.oab.blacklist(url) is true # ignore anything on the usual URL blacklist
    list = API.use.google.sheets.feed API.settings.service.openaccessbutton?.google?.sheets?.redirect, 360000
    for listing in list
      if listing.redirect and url.replace('http://','').replace('https://','').split('#')[0] is listing.redirect.replace('http://','').replace('https://','').split('#')[0]
        # we have an exact alternative for this url
        return listing.redirect
      else if url.indexOf(listing.domain.replace('http://','').replace('https://','').split('/')[0]) isnt -1
        if (listing.fulltext and listing.splash and listing.identifier) or listing.element
          source = url
          if listing.fulltext
            # switch the url by comparing the fulltext and splash examples, and converting the url in the same way
            start = listing.splash.split(listing.identifier)[0]
            url = url.replace start, listing.fulltext.split(listing.identifier)[0]
            end = listing.splash.split(listing.identifier)[1]
            url = url.replace(end, listing.fulltext.split(listing.identifier)[1]) if end
          else if listing.element and url.indexOf('.pdf') is -1
            try
              content = API.http.phantom url
              url = content.toLowerCase().split(listing.element.toLowerCase())[1].split('"')[0].split("'")[0].split('>')[0]
          return false if (not url? or url.length < 6 or url is source) and listing.blacklist is "yes"
          # fulltext or element can possibly give us a url which then redirects to a login wall
          # so we have to check the given url against the whole sheet listing again for the login wall
          # so this allows the rest of the listing to be checked before returning - MAKE SURE loginwall fragments are at the end of the sheet
          url = API.http.resolve url # resolve it again to make sure whatever we have now is accessible
        else if listing.loginwall and url.indexOf(listing.loginwall.replace('http://','').replace('https://','')) isnt -1
          # this url is on the login wall of the repo in question, so it is no use
          return false
        else if listing.blacklist is "yes"
          return false
  return url


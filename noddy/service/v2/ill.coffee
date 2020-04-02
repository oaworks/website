
import crypto from 'crypto'



API.add 'service/oab/subscription',
  get:
    #roleRequired: 'openaccessbutton.user'
    authOptional: true
    action: () ->
      if this.user
        uid = this.user._id
      else if this.queryParams.uid
        uid = this.queryParams.uid
        delete this.queryParams.uid
      #if this.queryParams.uid and this.user and API.accounts.auth 'openaccessbutton.admin', this.user
      #  uid = this.queryParams.uid
      #  delete this.queryParams.uid
      if not uid? or _.isEmpty this.queryParams
        return {}
      else
        res = {metadata: API.service.oab.metadata this.queryParams}
        res.subscription = API.service.oab.ill.subscription uid, res.metadata
        return res

API.add 'service/oab/ill',
  get: () ->
    return {data: 'ILL service'}
  post:
    authOptional: true
    action: () ->
      opts = this.request.body ? {}
      for o of this.queryParams
        opts[o] = this.queryParams[o]
      if this.user
        opts.from = this.user._id
        opts.api = true
      return API.service.oab.ill.start opts

API.add 'service/oab/ill/openurl',
  get: () ->
    return 'Will eventually redirect after reading openurl params passed here, somehow. For now a POST of metadata here by a user with an open ulr registered will build their openurl'
  post:
    #roleRequired: 'openaccessbutton.user'
    authOptional: true
    action: () ->
      opts = this.request.body ? {}
      for o of this.queryParams
        opts[o] = this.queryParams[o]
      #delete opts.uid if opts.uid and not API.accounts.auth 'openaccessbutton.admin', this.user
      if not opts.uid and not this.user?
        return 404
      else
        return API.service.oab.ill.openurl opts.uid ? this.user._id, opts

API.add 'service/oab/ill/config',
  get: 
    authOptional: true
    action: () ->
      try
        return API.service.oab.ill.config this.queryParams.uid ? this.user._id
      return 404
  post: 
    authRequired: 'openaccessbutton.user'
    action: () ->
      opts = this.request.body ? {}
      for o of this.queryParams
        opts[o] = this.queryParams[o]
      if opts.uid and API.accounts.auth 'openaccessbutton.admin', this.user
        user = Users.get opts.uid
        delete opts.uid
      else
        user = this.user
      return API.service.oab.ill.config user, opts

API.add 'service/oab/ills',
  get:
    roleRequired:'openaccessbutton.user'
    action: () ->
      restrict = if API.accounts.auth('openaccessbutton.admin', this.user) and this.queryParams.all then [] else [{term:{from:this.userId}}]
      delete this.queryParams.all if this.queryParams.all?
      return oab_ill.search this.queryParams, {restrict:restrict}
  post:
    roleRequired:'openaccessbutton.user'
    action: () ->
      restrict = if API.accounts.auth('openaccessbutton.admin', this.user) and this.queryParams.all then [] else [{term:{from:this.userId}}]
      delete this.queryParams.all if this.queryParams.all?
      return oab_ill.search this.bodyParams, {restrict:restrict}



API.service.oab.ill = {}

API.service.oab.ill.subscription = (uid, meta={}, refresh=false) ->
  # dev and live demo accounts that always return a fixed answer
  if (meta.doi is '10.1234/567890' or meta.title is 'Engineering a Powerfully Simple Interlibrary Loan Experience with InstantILL') and (uid is 'qZooaHWRz9NLFNcgR' or uid is 'eZwJ83xp3oZDaec86')
    return {findings:{}, uid: uid, lookups:[], error:[], url: 'https://scholarworks.iupui.edu/bitstream/handle/1805/20422/07-PAXTON.pdf?sequence=1&isAllowed=y', demo: true}

  do_serialssolutions_xml = true
  do_sfx_xml = true
  sig = uid + JSON.stringify(meta) + do_serialssolutions_xml + do_sfx_xml
  sig = crypto.createHash('md5').update(sig, 'utf8').digest('base64')
  res = API.http.cache(sig, 'oab_ill_subs', undefined, refresh) if refresh and refresh isnt true and refresh isnt 0
  if not res?
    res = {findings:{}, uid: uid, lookups:[], error:[]}
    res.contents = []
    user = API.accounts.retrieve uid
    if user?.service?.openaccessbutton?.ill?.config?.subscription?
      config = user.service.openaccessbutton.ill.config
      # need to get their subscriptions link from their config - and need to know how to build the query string for it
      openurl = API.service.oab.ill.openurl uid, meta, true
      openurl = openurl.replace(config.ill_redirect_params.replace('?',''),'') if config.ill_redirect_params
      openurl = openurl.split('?')[1] if openurl.indexOf('?') isnt -1
      if typeof config.subscription is 'string'
        config.subscription = config.subscription.split(',')
      if typeof config.subscription_type is 'string'
        config.subscription_type = config.subscription_type.split(',')
      config.subscription_type ?= []
      for s of config.subscription
        sub = config.subscription[s]
        if typeof sub is 'object'
          subtype = sub.type
          sub = sub.url
        else
          subtype = config.subscription_type[s] ? 'unknown'
        sub = sub.trim()
        if sub
          if (subtype is 'serialssolutions' or sub.indexOf('serialssolutions') isnt -1) and sub.indexOf('.xml.') is -1 and do_serialssolutions_xml is true
            tid = sub.split('.search')[0]
            tid = tid.split('//')[1] if tid.indexOf('//') isnt -1
            #bs = if sub.indexOf('://') isnt -1 then sub.split('://')[0] else 'http' # always use htto because https on the xml endpoint fails
            sub = 'http://' + tid + '.openurl.xml.serialssolutions.com/openurlxml?version=1.0&genre=article&'
          else if (subtype is 'sfx' or sub.indexOf('sfx.') isnt -1) and sub.indexOf('sfx.response_type=simplexml') is -1 and do_sfx_xml is true
            sub += (if sub.indexOf('?') is -1 then '?' else '&') + 'sfx.response_type=simplexml'
          url = sub + (if sub.indexOf('?') is -1 then '?' else '&') + openurl
          url = url.split('snc.idm.oclc.org/login?url=')[1] if url.indexOf('snc.idm.oclc.org/login?url=') isnt -1
          url = url.replace('cache=true','')
          if subtype is 'sfx' or sub.indexOf('sfx.') isnt -1 and url.indexOf('=10.') isnt -1
            url = url.replace('=10.','=doi:10.')
          # need to use the proxy as some subscriptions endpoints need a registered IP address, and ours is registered for some of them already
          # but having a problem passing proxy details through, so ignore for now
          # BUT AGAIN eds definitely does NOT work without puppeteer so going to have to use that again for now and figure out the proxy problem later
          #pg = API.http.puppeteer url #, undefined, API.settings.proxy
          # then get that link
          # then in that link find various content, depending on what kind of service it is
          
          # try doing without puppeteer and see how that goes
          API.log 'Using OAB subscription check for ' + url
          pg = ''
          spg = ''
          error = false
          res.lookups.push url
          try
            #pg = HTTP.call('GET', url, {timeout:15000, npmRequestOptions:{proxy:API.settings.proxy}}).content
            pg = if url.indexOf('.xml.serialssolutions') isnt -1 or url.indexOf('sfx.response_type=simplexml') isnt -1 then HTTP.call('GET',url).content else API.http.puppeteer url #, undefined, API.settings.proxy
            console.log pg
            spg = if pg.indexOf('<body') isnt -1 then pg.toLowerCase().split('<body')[1].split('</body')[0] else pg
            console.log spg
            res.contents.push spg
          catch err
            console.log(err) if API.settings.log?.level is 'debug'
            API.log {msg: 'ILL subscription check error when looking up ' + url, level:'warn', url: url, error: err}
            error = true
          #res.u ?= []
          #res.u.push url
          #res.pg = pg

          # sfx 
          # with access:
          # https://cricksfx.hosted.exlibrisgroup.com/crick?sid=Elsevier:Scopus&_service_type=getFullTxt&issn=00225193&isbn=&volume=467&issue=&spage=7&epage=14&pages=7-14&artnum=&date=2019&id=doi:10.1016%2fj.jtbi.2019.01.031&title=Journal+of+Theoretical+Biology&atitle=Potential+relations+between+post-spliced+introns+and+mature+mRNAs+in+the+Caenorhabditis+elegans+genome&aufirst=S.&auinit=S.&auinit1=S&aulast=Bo
          # which will contain a link like:
          # <A title="Navigate to target in new window" HREF="javascript:openSFXMenuLink(this, 'basic1', undefined, '_blank');">Go to Journal website at</A>
          # but the content can be different on different sfx language pages, so need to find this link via the tag attributes, then trigger it, then get the page it opens
          # can test this with 10.1016/j.jtbi.2019.01.031 on instantill page
          # note there is also now an sfx xml endpoint that we have found to check
          if subtype is 'sfx' or url.indexOf('sfx.') isnt -1
            res.error.push 'sfx' if error
            if do_sfx_xml
              if spg.indexOf('getFullTxt') isnt -1 and spg.indexOf('<target_url>') isnt -1
                try
                  # this will get the first target that has a getFullTxt type and has a target_url element with a value in it, or will error
                  res.url = spg.split('getFullTxt')[1].split('</target>')[0].split('<target_url>')[1].split('</target_url>')[0].trim()
                  res.findings.sfx = res.url
                  if res.url?
                    if res.url.indexOf('getitnow') is -1
                      res.found = 'sfx'
                      API.http.cache(sig, 'oab_ill_subs', res)
                      return res
                    else
                      res.url = undefined
                      res.findings.sfx = undefined
            else
              if spg.indexOf('<a title="navigate to target in new window') isnt -1 and spg.split('<a title="navigate to target in new window')[1].split('">')[0].indexOf('basic1') isnt -1
                # tried to get the next link after the click through, but was not worth putting more time into it. For now, seems like this will have to do
                res.url = url
                res.findings.sfx = res.url
                if res.url?
                  if res.url.indexOf('getitnow') is -1
                    res.found = 'sfx'
                    API.http.cache(sig, 'oab_ill_subs', res)
                    return res
                  else
                    res.url = undefined
                    res.findings.sfx = undefined
  
          # eds
          # note eds does need a login, but IP address range is supposed to get round that
          # our IP is supposed to be registered with the library as being one of their internal ones so should not need login
          # however a curl from our IP to it still does not seem to work - will try with puppeteer to see if it is blocking in other ways
          # not sure why the links here are via an oclc login - tested, and we will use without it
          # with access:
          # https://snc.idm.oclc.org/login?url=http://resolver.ebscohost.com/openurl?sid=google&auinit=RE&aulast=Marx&atitle=Platelet-rich+plasma:+growth+factor+enhancement+for+bone+grafts&id=doi:10.1016/S1079-2104(98)90029-4&title=Oral+Surgery,+Oral+Medicine,+Oral+Pathology,+Oral+Radiology,+and+Endodontology&volume=85&issue=6&date=1998&spage=638&issn=1079-2104
          # can be tested on instantill page with 10.1016/S1079-2104(98)90029-4
          # without:
          # https://snc.idm.oclc.org/login?url=http://resolver.ebscohost.com/openurl?sid=google&auinit=MP&aulast=Newton&atitle=Librarian+roles+in+institutional+repository+data+set+collecting:+outcomes+of+a+research+library+task+force&id=doi:10.1080/01462679.2011.530546
          else if subtype is 'eds' or url.indexOf('ebscohost.') isnt -1
            res.error.push 'eds' if error
            if spg.indexOf('view this ') isnt -1 and pg.indexOf('<a data-auto="menu-link" href="') isnt -1
              res.url = url.replace('://','______').split('/')[0].replace('______','://') + pg.split('<a data-auto="menu-link" href="')[1].split('" title="')[0]
              res.findings.eds = res.url
              if res.url?
                if res.url.indexOf('getitnow') is -1
                  res.found = 'eds'
                  API.http.cache(sig, 'oab_ill_subs', res)
                  return res
                else
                  res.url = undefined

          # serials solutions
          # the HTML source code for the No Results page includes a span element with the class SS_NoResults. This class is only found on the No Results page (confirmed by serialssolutions)
          # does not appear to need proxy or password
          # with:
          # https://rx8kl6yf4x.search.serialssolutions.com/?genre=article&issn=14085348&title=Annales%3A%20Series%20Historia%20et%20Sociologia&volume=28&issue=1&date=20180101&atitle=HOW%20TO%20UNDERSTAND%20THE%20WAR%20IN%20SYRIA.&spage=13&PAGES=13-28&AUTHOR=%C5%A0TERBENC%2C%20Primo%C5%BE&&aufirst=&aulast=&sid=EBSCO:aph&pid=
          # can test this on instantill page with How to understand the war in Syria - Annales Series Historia et Sociologia 2018
          # but the with link has a suppressed link that has to be clicked to get the actual page with the content on it
          # <a href="?ShowSupressedLinks=yes&SS_LibHash=RX8KL6YF4X&url_ver=Z39.88-2004&rfr_id=info:sid/sersol:RefinerQuery&rft_val_fmt=info:ofi/fmt:kev:mtx:journal&SS_ReferentFormat=JournalFormat&SS_formatselector=radio&rft.genre=article&SS_genreselector=1&rft.aulast=%C5%A0TERBENC&rft.aufirst=Primo%C5%BE&rft.date=2018-01-01&rft.issue=1&rft.volume=28&rft.atitle=HOW+TO+UNDERSTAND+THE+WAR+IN+SYRIA.&rft.spage=13&rft.title=Annales%3A+Series+Historia+et+Sociologia&rft.issn=1408-5348&SS_issnh=1408-5348&rft.isbn=&SS_isbnh=&rft.au=%C5%A0TERBENC%2C+Primo%C5%BE&rft.pub=Zgodovinsko+dru%C5%A1tvo+za+ju%C5%BEno+Primorsko&paramdict=en-US&SS_PostParamDict=disableOneClick">Click here</a>
          # which is the only link with the showsuppressedlinks param and the clickhere content
          # then the page with the content link is like:
          # https://rx8kl6yf4x.search.serialssolutions.com/?ShowSupressedLinks=yes&SS_LibHash=RX8KL6YF4X&url_ver=Z39.88-2004&rfr_id=info:sid/sersol:RefinerQuery&rft_val_fmt=info:ofi/fmt:kev:mtx:journal&SS_ReferentFormat=JournalFormat&SS_formatselector=radio&rft.genre=article&SS_genreselector=1&rft.aulast=%C5%A0TERBENC&rft.aufirst=Primo%C5%BE&rft.date=2018-01-01&rft.issue=1&rft.volume=28&rft.atitle=HOW+TO+UNDERSTAND+THE+WAR+IN+SYRIA.&rft.spage=13&rft.title=Annales%3A+Series+Historia+et+Sociologia&rft.issn=1408-5348&SS_issnh=1408-5348&rft.isbn=&SS_isbnh=&rft.au=%C5%A0TERBENC%2C+Primo%C5%BE&rft.pub=Zgodovinsko+dru%C5%A1tvo+za+ju%C5%BEno+Primorsko&paramdict=en-US&SS_PostParamDict=disableOneClick
          # and the content is found in a link like this:
          # <div id="ArticleCL" class="cl">
          #   <a target="_blank" href="./log?L=RX8KL6YF4X&amp;D=EAP&amp;J=TC0000940997&amp;P=Link&amp;PT=EZProxy&amp;A=HOW+TO+UNDERSTAND+THE+WAR+IN+SYRIA.&amp;H=c7306f7121&amp;U=http%3A%2F%2Fwww.ulib.iupui.edu%2Fcgi-bin%2Fproxy.pl%3Furl%3Dhttp%3A%2F%2Fopenurl.ebscohost.com%2Flinksvc%2Flinking.aspx%3Fgenre%3Darticle%26issn%3D1408-5348%26title%3DAnnales%2BSeries%2Bhistoria%2Bet%2Bsociologia%26date%3D2018%26volume%3D28%26issue%3D1%26spage%3D13%26atitle%3DHOW%2BTO%2BUNDERSTAND%2BTHE%2BWAR%2BIN%2BSYRIA.%26aulast%3D%25C5%25A0TERBENC%26aufirst%3DPrimo%C5%BE">Article</a>
          # </div>
          # without:
          # https://rx8kl6yf4x.search.serialssolutions.com/directLink?&atitle=Writing+at+the+Speed+of+Sound%3A+Music+Stenography+and+Recording+beyond+the+Phonograph&author=Pierce%2C+J+Mackenzie&issn=01482076&title=Nineteenth+Century+Music&volume=41&issue=2&date=2017-10-01&spage=121&id=doi:&sid=ProQ_ss&genre=article
          
          # we also have an xml alternative for serials solutions
          # see https://journal.code4lib.org/articles/108
          else if subtype is 'serialssolutions' or url.indexOf('serialssolutions.') isnt -1
            res.error.push 'serialssolutions' if error
            if do_serialssolutions_xml is true
              if spg.indexOf('<ssopenurl:url type="article">') isnt -1
                fnd = spg.split('<ssopenurl:url type="article">')[1].split('</ssopenurl:url>')[0].trim() # this gets us something that has an empty accountid param - do we need that for it to work?
                if fnd.length
                  res.url = fnd
                  res.findings.serials = res.url
                  if res.url?
                    if res.url.indexOf('getitnow') is -1
                      res.found = 'serials'
                      API.http.cache(sig, 'oab_ill_subs', res)
                      return res
                    else
                      res.url = undefined
                      res.findings.serials = undefined
              # disable journal matching for now until we have time to get it more accurate - some things get journal links but are not subscribed
              #else if spg.indexOf('<ssopenurl:result format="journal">') isnt -1
              #  # we assume if there is a journal result but not a URL that it means the institution has a journal subscription but we don't have a link
              #  res.journal = true
              #  res.found = 'serials'
              #  API.http.cache(sig, 'oab_ill_subs', res)
              #  return res
            else
              if spg.indexOf('ss_noresults') is -1
                try
                  surl = url.split('?')[0] + '?ShowSupressedLinks' + pg.split('?ShowSupressedLinks')[1].split('">')[0]
                  #npg = API.http.puppeteer surl #, undefined, API.settings.proxy
                  API.log 'Using OAB subscription unsuppress for ' + surl
                  npg = HTTP.call('GET', surl, {timeout: 15000, npmRequestOptions:{proxy:API.settings.proxy}}).content
                  if npg.indexOf('ArticleCL') isnt -1 and npg.split('DatabaseCL')[0].indexOf('href="./log') isnt -1
                    res.url = surl.split('?')[0] + npg.split('ArticleCL')[1].split('DatabaseCL')[0].split('href="')[1].split('">')[0]
                    res.findings.serials = res.url
                    if res.url?
                      if res.url.indexOf('getitnow') is -1
                        res.found = 'serials'
                        API.http.cache(sig, 'oab_ill_subs', res)
                        return res
                      else
                        res.url = undefined
                        res.findings.serials = undefined
                catch
                  res.error.push 'serialssolutions' if error

    API.http.cache(sig, 'oab_ill_subs', res) if not _.isEmpty res.findings
    
  # return cached or empty result if nothing else found
  else
    res.cache = true
  return res

API.service.oab.ill.start = (opts={}) ->
  # opts should include a key called metadata at this point containing all metadata known about the object
  # but if not, and if needed for the below stages, it is looked up again
  opts.metadata ?= {}
  meta = API.service.oab.metadata opts
  for m of meta
    opts.metadata[m] ?= meta[m]
    
  if opts.library is 'imperial'
    # TODO for now we are just going to send an email when a user creates an ILL
    # until we have a script endpoint at the library to hit
    # library POST URL: https://www.imperial.ac.uk/library/dynamic/oabutton/oabutton3.php
    if not opts.forwarded
      API.mail.send {
        service: 'openaccessbutton',
        from: 'requests@openaccessbutton.org',
        to: ['mark@cottagelabs.com','joe@righttoresearch.org','s.barron@imperial.ac.uk'],
        subject: 'EXAMPLE ILL TRIGGER',
        text: JSON.stringify(opts,undefined,2)
      }
      API.service.oab.mail({template:{filename:'imperial_confirmation_example.txt'},to:opts.id})
      HTTP.call('POST','https://www.imperial.ac.uk/library/dynamic/oabutton/oabutton3.php',{data:opts})
    return oab_ill.insert opts

  else if opts.from?
    user = API.accounts.retrieve opts.from
    if user?
      vars = {}
      vars.name = user.profile?.firstname ? 'librarian'
      vars.details = ''
      ordered = ['title','author','volume','issue','date','pages']
      for o of opts
        if o is 'metadata'
          for m of opts[o]
            if m isnt 'email'
              opts[m] = opts[o][m]
              ordered.push(m) if m not in ordered
          delete opts.metadata
        else
          ordered.push(o) if o not in ordered
      for r in ordered
        if opts[r]
          vars[r] = opts[r]
          if r is 'author'
            authors = '<p>Authors:<br>'
            first = true
            ats = []
            for a in opts[r]
              if a.family
                if first
                  first = false
                else
                  authors += ', '
                atidy = a.family + (if a.given then ' ' + a.given else '')
                authors += atidy
                ats.push atidy
            vars.details += authors + '</p>'
            vars[r] = ats
          else if ['started','ended','took'].indexOf(r) is -1
            vars.details += '<p>' + r + ':<br>' + opts[r] + '</p>'
        #vars.details += '<p>' + o + ':<br>' + opts[o] + '</p>'
      opts.norequests = true if user.service?.openaccessbutton?.ill?.config?.norequests
      delete opts.author if opts.author? # remove author metadata due to messy provisions causing save issues
      delete opts.metadata.author if opts.metadata?.author?
      vars.illid = oab_ill.insert opts
      vars.details += '<p>Open access button ILL ID:<br>' + vars.illid + '</p>';
      eml = if user.service?.openaccessbutton?.ill?.config?.email and user.service?.openaccessbutton?.ill?.config?.email.length then user.service?.openaccessbutton?.ill?.config?.email else if user.email then user.email else user.emails[0].address

      # such as https://ambslibrary.share.worldcat.org/wms/cmnd/nd/discover/items/search?ai0id=level3&ai0type=scope&offset=1&pageSize=10&si0in=in%3A&si0qs=0021-9231&si1in=au%3A&si1op=AND&si2in=kw%3A&si2op=AND&sortDirection=descending&sortKey=librarycount&applicationId=nd&requestType=search&searchType=advancedsearch&eventSource=df-advancedsearch
      # could be provided as: (unless other params are mandatory) 
      # https://ambslibrary.share.worldcat.org/wms/cmnd/nd/discover/items/search?si0qs=0021-9231
      if user.service?.openaccessbutton?.ill?.config?.search and user.service.openaccessbutton.ill.config.search.length and (opts.issn or opts.journal)
        if user.service.openaccessbutton.ill.config.search.indexOf('worldcat') isnt -1
          su = user.service.openaccessbutton.ill.config.search.split('?')[0] + '?ai0id=level3&ai0type=scope&offset=1&pageSize=10&si0in='
          su += if opts.issn? then 'in%3A' else 'ti%3A'
          su += '&si0qs=' + (opts.issn ? opts.journal)
          su += '&sortDirection=descending&sortKey=librarycount&applicationId=nd&requestType=search&searchType=advancedsearch&eventSource=df-advancedsearch'
        else
          su = user.service.openaccessbutton.ill.config.search
          su += if opts.issn then opts.issn else opts.journal
        vars.details += '<p>Search URL:<br><a href="' + su + '">' + su + '</a></p>'
        vars.worldcatsearchurl = su

      if not opts.forwarded
        API.service.oab.mail({vars: vars, template: {filename:'instantill_create.html'}, to: eml, from: "InstantILL <InstantILL@openaccessbutton.org>", subject: "ILL request " + vars.illid})
      
      # send msg to mark and joe for testing (can be removed later)
      txt = vars.details
      delete vars.details
      txt += '<br><br>' + JSON.stringify(vars,undefined,2)
      API.mail.send {
        service: 'openaccessbutton',
        from: 'InstantILL <InstantILL@openaccessbutton.org>',
        to: ['mark@cottagelabs.com','joe@righttoresearch.org'],
        subject: 'ILL CREATED',
        html: txt,
        text: txt
      }
      
      return vars.illid
    else
      return 401
  else
    return 404

API.service.oab.ill.config = (user, config) ->
  # need to set a config on live for the IUPUI user ajrfnwswdr4my8kgd
  # the URL params they need are like
  # https://ill.ulib.iupui.edu/ILLiad/IUP/illiad.dll?Action=10&Form=30&sid=OABILL&genre=InstantILL&aulast=Sapon-Shevin&aufirst=Mara&issn=10478248&title=Journal+of+Educational+Foundations&atitle=Cooperative+Learning%3A+Liberatory+Praxis+or+Hamburger+Helper&volume=5&part=&issue=3&spage=5&epage=&date=1991-07-01&pmid
  # and their openurl config https://docs.google.com/spreadsheets/d/1wGQp7MofLh40JJK32Rp9di7pEkbwOpQ0ioigbqsufU0/edit#gid=806496802
  # tested it and set values as below defaults, but also noted that it has year and month boxes, but these do not correspond to year and month params, or date params
  user = Users.get(user) if typeof user is 'string'
  if config?
    uc = user.service?.openaccessbutton?.ill?.config ? {}
    update = {}
    for k in ['ill_institution','ill_redirect_base_url','ill_redirect_params','method','sid','title','doi','pmid','pmcid','author','journal','issn','volume','issue','page','published','year','terms','book','other','cost','time','email','problem_email','subscription','subscription_type','val','search','autorun','autorunparams','intropara','norequests','noillifoa','noillifsub','saypaper','pilot','live']
      if k is 'ill_redirect_base_url' and config[k]?
        if config[k].indexOf('illiad.dll') isnt -1 and config[k].toLowerCase().indexOf('action=') is -1
          config[k] = config[k].split('?')[0]
          if config[k].indexOf('/openurl') is -1
            config[k] = config[k].split('#')[0] + '/openurl'
            config[k] += if config[k].indexOf('#') is -1 then '' else '#' + config[k].split('#')[1].split('?')[0]
          config[k] += '?genre=article'
        else if config[k].indexOf('relais') isnt -1 and config[k].toLowerCase().indexOf('genre=') is -1
          config[k] = config[k].split('?')[0]
          config[k] += '?genre=article'
      if k in ['pilot','live']
        update[k] = if config[k] is true and not uc[k] then Date.now() else '$DELETE'
      else
        update[k] = config[k] if config[k]?
    if JSON.stringify(update) isnt '{}'
      if not user.service.openaccessbutton.ill?
        Users.update user._id, {'service.openaccessbutton.ill': {config: update}}
      else
        Users.update user._id, {'service.openaccessbutton.ill.config': update}
      user = Users.get user._id
  try
    rs = user.service.openaccessbutton.ill.config ? {}
    try rs.adminemail = if user.email then user.email else user.emails[0].address
    return rs
  catch
    return {}

API.service.oab.ill.resolver = (user, resolve, config) ->
  # should configure and return link resolver settings for the given user
  # should be like the users config but can have different params set for it
  # and has to default to the ill one anyway
  # and has to apply per resolver url that the user gives us
  # this shouldn't actually be a user setting - it should be settings for a given link resolver address
  return false
  
API.service.oab.ill.openurl = (uid, meta={}, withoutbase=false) ->
  config = API.service.oab.ill.config uid
  config ?= {}
  return '' if withoutbase isnt true and not config.ill_redirect_base_url
  # add iupui / openURL defaults to config
  defaults =
    sid: 'sid'
    title: 'atitle' # this is what iupui needs (title is also acceptable, but would clash with using title for journal title, which we set below, as iupui do that
    doi: 'rft_id' # don't know yet what this should be
    #pmid: 'pmid' # same as iupui ill url format
    pmcid: 'pmcid' # don't know yet what this should be
    #aufirst: 'aufirst' # this is what iupui needs
    #aulast: 'aulast' # this is what iupui needs
    author: 'aulast' # author should actually be au, but aulast works even if contains the whole author, using aufirst just concatenates
    journal: 'title' # this is what iupui needs
    #issn: 'issn' # same as iupui ill url format
    #volume: 'volume' # same as iupui ill url format
    #issue: 'issue' # same as iupui ill url format
    #spage: 'spage' # this is what iupui needs
    #epage: 'epage' # this is what iupui needs
    page: 'pages' # iupui uses the spage and epage for start and end pages, but pages is allowed in openurl, check if this will work for iupui
    published: 'date' # this is what iupui needs, but in format 1991-07-01 - date format may be a problem
    year: 'rft.year' # this is what IUPUI uses
    # IUPUI also has a month field, but there is nothing to match to that
  for d of defaults
    config[d] = defaults[d] if not config[d]

  url = if config.ill_redirect_base_url then config.ill_redirect_base_url else ''
  url += if url.indexOf('?') is -1 then '?' else '&'
  url += config.ill_redirect_params.replace('?','') + '&' if config.ill_redirect_params
  url += config.sid + '=InstantILL&'
  for k of meta
    v = false
    if k is 'author'
      # need to check if config has aufirst and aulast or something similar, then need to use those instead, 
      # if we have author name parts
      try
        if typeof meta.author is 'string'
          v = meta.author
        else if _.isArray meta.author
          v = ''
          for author in meta.author
            v += ', ' if v.length
            if typeof author is 'string'
              v += author
            else if author.family
              v += author.family + if author.given then ', ' + author.given else ''
        else
          if meta.author.family
            v = meta.author.family + if meta.author.given then ', ' + meta.author.given else ''
          else
            v = JSON.stringify meta.author
    else if k not in ['started','ended','took','terms','book','other','cost','time','email','redirect','url','source','notes','createdAt','created_date','_id']
      v = meta[k]
    if v
      url += (if config[k] then config[k] else k) + '=' + encodeURIComponent(v) + '&'
  if meta.usermetadata
    url = url.replace('usermetadata=true','')
    if url.indexOf('notes=') is -1
      url += '&notes=The user provided some metadata.'
    else
      url.replace('notes=','notes=The user provided some metadata. ')
  return url.replace('/&&/g','&')

API.service.oab.ill.terms = (uid) ->
  return API.service.oab.ill.config(uid).terms

API.service.oab.ill.progress = () ->
  # TODO need a function that can lookup ILL progress from the library systems some how
  return
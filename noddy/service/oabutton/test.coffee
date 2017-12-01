
import Future from 'fibers/future'

API.add 'service/oab/test',
  get:
    roleRequired: if API.settings.dev then undefined else 'root'
    action: () -> return API.service.oab.test(this.queryParams.verbose)

API.service.oab.test = (verbose) ->
  result = {passed:[],failed:[]}

  oab_request.remove url: 'https://jcheminf.springeropen.com/articles/10.1186/1758-2946-3-47'

  tests = [
    () ->
      result.find_citation = API.service.oab.find url: 'Nusch, C., & Percivale, B. (2016). El Bicentenario argentino como territorio en disputa. Analecta política, 6(10).', refresh: 0
      return result.find_citation.match is "https://doi.org/10.18566/apolit.v6n10.a04" and result.find_citation.availability?[0]?.url is "https://revistas.upb.edu.co/index.php/analecta/article/download/6166/5658" and result.find_citation.meta.article.source is "oadoi"
    () ->
      result.find_title = API.service.oab.find url: 'Effect of Saxagliptin on Renal Outcomes in the SAVOR-TIMI 53 Trial', refresh: 0
      return result.find_title.match is "https://doi.org/10.2337/dc16-0621" and result.find_title.availability?[0]?.url is "https://spiral.imperial.ac.uk:8443/bitstream/10044/1/42241/4/Effect%20of%20Saxagliptin%20on%20Renal%20Outcomes%20in%20the%20SAVOR%20trial%20clean%20final%201....pdf" and result.find_title.meta.article.source is "oadoi"
    () ->
      result.find_url = API.service.oab.find url: 'http://journals.sagepub.com/doi/abs/10.1177/0037549715583150', refresh: 0
      return result.find_url.match is "http://journals.sagepub.com/doi/abs/10.1177/0037549715583150" and result.find_url.availability?[0]?.url is "http://journals.sagepub.com/doi/pdf/10.1177/0037549715583150" and result.find_url.meta.article.source is "oadoi"
    () ->
      result.find_pmid = API.service.oab.find url: '27353853', refresh: 0
      return result.find_pmid.match is "https://www.ncbi.nlm.nih.gov/pubmed/27353853" and result.find_pmid.availability?[0]?.url is "http://circimaging.ahajournals.org/content/circcvim/9/7/e005150.full.pdf" and result.find_pmid.meta.article.source is "oadoi"
    () ->
      result.find_pmc = API.service.oab.find url: 'PMC3220411', refresh: 0
      return result.find_pmc.match is "http://europepmc.org/articles/PMC3220411" and result.find_pmc.availability?[0]?.url is "http://europepmc.org/articles/PMC3220411?pdf=render" and result.find_pmc.meta.article.source is "eupmc"
    () ->
      result.find_doi = API.service.oab.find url: '10.1145/2908080.2908114', refresh: 0
      return result.find_doi.match is "https://doi.org/10.1145/2908080.2908114" and result.find_doi.availability?[0]?.url is "http://spiral.imperial.ac.uk/bitstream/10044/1/31580/2/paper.pdf" and result.find_doi.meta.article.source is "oadoi"
    () ->
      result.closed = API.service.oab.find url: 'http://www.tandfonline.com/doi/abs/10.1080/09505431.2014.928678', refresh: 0
      return result.closed.match is "http://www.tandfonline.com/doi/abs/10.1080/09505431.2014.928678" and result.closed.availability.length is 0 and not result.closed.meta.article.source? and result.closed.meta.article.doi is "10.1080/09505431.2014.928678"
    () ->
      result.resolve = API.service.oab.resolve 'http://www.sciencedirect.com/science/article/pii/S0735109712600734', undefined, undefined, true
      return _.isEqual result.resolve, API.service.oab.test._examples.resolve
    () ->
      result.redirect_false = API.service.oab.redirect 'https://www.researchgate.net/anything'
      return result.redirect_false is false
    () ->
      result.redirect_fulltext = API.service.oab.redirect 'https://arxiv.org/abs/1711.07985'
      return result.redirect_fulltext is 'https://arxiv.org/pdf/1711.07985.pdf'
    () ->
      result.redirect_element = API.service.oab.redirect 'http://nora.nerc.ac.uk/518502'
      return result.redirect_element is 'http://nora.nerc.ac.uk/518502/1/N518502CR.pdf'
    () ->
      result.scrape = API.service.oab.scrape 'http://www.tandfonline.com/doi/abs/10.1080/09505431.2014.928678'
      return _.isEqual result.scrape, API.service.oab.test._examples.scrape
    () ->
      result.request = API.service.oab.request url: 'https://jcheminf.springeropen.com/articles/10.1186/1758-2946-3-47', test: true
      ck = JSON.parse(JSON.stringify(result.request))
      delete ck.receiver
      delete ck._id
      return _.isEqual ck, API.service.oab.test._examples.request
    () ->
      result.support = API.service.oab.support result.request._id, "I am the test story", "0"
      future = new Future()
      setTimeout (() -> future.return()), 999
      future.wait()
      result.supports = API.service.oab.supports result.request._id, "0"
      oab_support.remove result.support._id
      return result.supports?.rid is result.request._id and result.supports?.story is "I am the test story" and result.supports?.uid is "0"
    () ->
      result.hold = API.service.oab.hold result.request._id, 7
      result.held = oab_request.get result.request._id
      return result.held.status is 'hold' and result.held.holds? and result.held.hold?.until?
    () ->
      result.refuse = API.service.oab.refuse result.request._id, "Test reason"
      result.refused = oab_request.get result.request._id
      oab_request.remove result.request._id
      return result.refused.status is 'refused' and not result.refused.email? and not result.refused.hold? and result.refused.refused? and result.refused.refused[0].reason is "Test reason"
    () ->
      result.dnr = API.service.oab.dnr 'test@test.com', true
      future = new Future()
      setTimeout (() -> future.return()), 999
      future.wait()
      result.ondnr = API.service.oab.dnr 'test@test.com'
      oab_dnr.remove {email: 'test@test.com'}
      return result.ondnr is true
    () ->
      result.vars = API.service.oab.vars {user: {id:"0"}}
      return result.vars.userid is "0" and result.vars.profession? and result.vars.fullname?
  ]
  # TODO need to add tests for ill once we start developing that again

  (if (try tests[t]()) then (result.passed.push(t) if result.passed isnt false) else result.failed.push(t)) for t of tests
  result.passed = result.passed.length if result.passed isnt false and result.failed.length is 0
  result = {passed:result.passed} if result.failed.length is 0 and not verbose
  return result


  
API.service.oab.test._examples = {
  resolve: {
    "url": "http://linkinghub.elsevier.com/retrieve/pii/S0735109712600734",
    "all": true,
    "sources": [
      "oabutton",
      "eupmc",
      "oadoi",
      "base",
      "dissemin",
      "share",
      "core",
      "openaire",
      "figshare",
      "doaj"
    ],
    "found": {
      "oadoi": "http://linkinghub.elsevier.com/retrieve/pii/S0735109712600734"
    },
    "checked": {
      "identifiers": [
        "oabutton",
        "oadoi",
        "eupmc",
        "base",
        "dissemin",
        "share",
        "core",
        "openaire",
        "figshare",
        "doaj"
      ],
      "titles": [
        "eupmc",
        "share",
        "base",
        "core",
        "openaire",
        "doaj"
      ]
    },
    "original": "http://www.sciencedirect.com/science/article/pii/S0735109712600734",
    "doi": "10.1016/s0735-1097(12)60073-4",
    "title": "cost-effectiveness analysis of propensity matched radial and femoral cardiac catheterization and coronary intervention",
    "email": [],
    "source": "oadoi",
    "licence": "elsevier-specific: oa user license",
    "titles": true
  },
  scrape: {
    "url": "http://www.tandfonline.com/doi/abs/10.1080/09505431.2014.928678",
    "doi": "10.1080/09505431.2014.928678",
    "title": "Lamenting the Golden Age: Love, Labour and Loss in the Collective Memory of Scientists",
    "author": [
      {
        "given": "Kerry",
        "family": "Holden",
        "affiliation": []
      }
    ],
    "journal": "Science as Culture",
    "issn": "0950-5431",
    "subject": [
      "Biotechnology",
      "History and Philosophy of Science",
      "Cultural Studies",
      "Sociology and Political Science",
      "Health(social science)",
      "Biomedical Engineering"
    ],
    "publisher": "Informa UK Limited",
    "keywords": [
      "academic science",
      "commercialisation",
      "golden age",
      "moral economy",
      "myth",
      "scientific labour"
    ],
    "email": [
      "k.holden@qmul.ac.uk"
    ]
  },
  request: {
    "url": "https://jcheminf.springeropen.com/articles/10.1186/1758-2946-3-47",
    "test": true,
    "type": "article",
    "count": 0,
    "keywords": [],
    "title": "Open Bibliography for Science, Technology, and Medicine",
    "doi": "10.1186/1758-2946-3-47",
    "author": [
      {
        "given": "Richard",
        "family": "Jones",
        "affiliation": []
      },
      {
        "given": "Mark",
        "family": "MacGillivray",
        "affiliation": []
      },
      {
        "given": "Peter",
        "family": "Murray-Rust",
        "affiliation": []
      },
      {
        "given": "Jim",
        "family": "Pitman",
        "affiliation": []
      },
      {
        "given": "Peter",
        "family": "Sefton",
        "affiliation": []
      },
      {
        "given": "Ben",
        "family": "O'Steen",
        "affiliation": []
      },
      {
        "given": "William",
        "family": "Waites",
        "affiliation": []
      }
    ],
    "journal": "Journal of Cheminformatics",
    "issn": "1758-2946",
    "publisher": "Springer Nature",
    "status": "help",
  }
}
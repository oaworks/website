
# get the big deal data from a sheet and expose it in a website
# https://docs.google.com/spreadsheets/d/e/2PACX-1vQ4frfBvvPOKKFhArpV7cRUG0aAbfGRy214y-xlDG_CsW7kNbL-e8tuRvh8y37F4xc8wjO6FK8SD6UT/pubhtml
# https://docs.google.com/spreadsheets/d/1dPG7Xxvk4qnPajTu9jG_uNuz2R5jvjfeaKI-ylX4NXs/edit
# there are about 6500 records

API.service ?= {}
API.service.bigdeal ?= {}

bigdeal_record = new API.collection {index:"bigdeal",type:"record"}
bigdeal_institution = new API.collection {index:"bigdeal",type:"institution"}

_bigdeal_sync_interval_id = Meteor.setInterval API.service.bigdeal.sync, 604800000 # refresh every week
_bigdeal_last_sync = 0

API.add 'service/bigdeal', () -> return bigdeal_record.search this
API.add 'service/bigdeal/institution', () -> return bigdeal_institution.search this
API.add 'service/bigdeal/sync', get: () -> return API.service.bigdeal.sync()
API.add 'service/bigdeal/sync/last', get: () -> return _bigdeal_last_sync



API.service.bigdeal.sync = () ->
  _bigdeal_last_sync = Date.now()
  API.log 'Syncing Bigdeal dataset'
  recs = API.use.google.sheets.feed '1dPG7Xxvk4qnPajTu9jG_uNuz2R5jvjfeaKI-ylX4NXs'
  # should this do a delete of the records already present first? Or some way to check if there are updates and do updates?
  # with 6500 it is not hard to ingest all again, unless we start adding to them within the system later
  bigdeal_record.remove '*'
  bigdeal_institution.remove '*'
  institutions = {}
  for rec in recs
    try
      rec.value = parseInt rec.packageprice.replace /[^0-9]+/g, ''
      if typeof rec.fte is 'string'
        try
          rec.fte = parseInt rec.fte
        catch
          delete rec.fte
      if rec.notes.toLowerCase().indexOf('canadian') isnt -1
        rec.gbpvalue = Math.floor rec.value * .57
        rec.usdvalue = Math.floor rec.value * .75
      else if rec.packageprice.indexOf('$') isnt -1
        rec.gbpvalue = Math.floor rec.value * .77
        rec.usdvalue = Math.floor rec.value
      else
        rec.gbpvalue = Math.floor rec.value
        rec.usdvalue = Math.floor rec.value * 1.3
    try rec.years = '2013' if rec.years is '2103' # fix what is probably a typo
    try delete rec.url if rec.shareurlpublicly.toLowerCase() isnt 'yes'
    try delete rec.shareurlpublicly
    try rec.collection = 'Unclassified' if rec.collection is ''
    try
      institutions[rec.institution] ?= {institution:rec.institution, deals:[], value:0, usdvalue:0, gbpvalue:0}
      rdc = JSON.parse JSON.stringify rec
      try delete rdc.institution
      try
        institutions[rec.institution].value += rec.value
        institutions[rec.institution].gbpvalue += rec.gbpvalue
        institutions[rec.institution].usdvalue += rec.usdvalue
      institutions[rec.institution].deals.push rdc
  created = bigdeal_record.insert recs
  insts = []
  for i of institutions
    insts.push institutions[i]
  insted = bigdeal_institution.insert insts
  bigdeal_institution.refresh() # refresh issues on index anyway so no need to refresh both
  return retrieved: recs.length, saved: bigdeal_record.count(), example: recs[0], institutions: insts.length, created: bigdeal_institution.count()



require! <[fs path request cheerio bluebird]>
source = do
  setup: \https://data.gcis.nat.gov.tw/od/detail?oid=AD28285B-7B0E-4241-9F58-F2F0F289333E
  update: \https://data.gcis.nat.gov.tw/od/detail?oid=75353060-3C3D-453E-8E5C-4ADDEAA8260F
  dismiss: \https://data.gcis.nat.gov.tw/od/detail?oid=4302E583-A7B5-4BE2-A3D6-9707B1AACE1C

mkdir-recurse = (f) ->
  if fs.exists-sync f => return
  parent = path.dirname(f)
  if !fs.exists-sync parent => mkdir-recurse parent
  fs.mkdir-sync f
root = \https://data.gcis.nat.gov.tw/
filename = (item) -> path.join \data, item.type, "#{item.name}.csv"
parse = (type, url) ->
  $ = cheerio.load (fs.read-file-sync \out .toString!)
  csv = $('.file.CSV')
  ret = []
  for idx from 0 til csv.length
    node = $(csv[idx])
    name = /(\d+)年(\d+)月/.exec node.attr("title")
    if !name => continue
    name = "#{name.1}-#{name.2}"
    href = "#root#{node.attr('href')}"
    item = {type, name, href}
    item.path = filename(item)
    ret.push item
  ret

csvlist = [parse(k, v) for k,v of source].reduce(((a,b) -> a ++ b), [])

failed = []
fetch = (list) ->
  if list.length == 0 => 
    console.log "done. #{failed.length} item(s) failed."
    return
  console.log "remain #{list.length}"
  item = list.splice(0,1) .0
  if fs.exists-sync item.path => return fetch list
  (e,r,b) <- request {
    url: item.href
    method: \GET
    rejectUnauthorized: false
    requestCert: true
    agent: false
  }, _
  if e or !b => 
    console.log e
    console.log "#{item.name} failed. ignore..."
    failed.push item
    return fetch list
  mkdir-recurse path.dirname(item.path)
  fs.write-file-sync item.path, b
  fetch list
  
fetch csvlist

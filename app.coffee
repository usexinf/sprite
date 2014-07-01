fs = require 'fs'
jf = require 'jsonfile'
path = require 'path'
cssom = require 'cssom'
PNG = require('pngjs').PNG
mkdirp = require('mkdirp').mkdirp
require './js/packer.growing'

CONFIG_SRC = './config.json'

config = []
styleSheets = []
mergeStyles = {}
imgObjs = []

###
  1.read config
###

readConfig = (filename) ->
  config = JSON.parse(fs.readFileSync(filename))
  imgDist = config.output.imageDist
  if !fs.existsSync imgDist
    mkdirp imgDist, (err) ->
      if err then console.error err
  log 'readConfig'
  return

log = (name) ->
  date = new Date()
  time = date.toLocaleTimeString()
  ms = date.getMilliseconds()
  console.log "#{time}:#{ms}:#{name}".green
###
  2.parse css
###
regexp =
  image: /\(['"]?(.+\.(png|jpg|jpeg))(\?.*?)?['"]?\)/i

readStyleSheet = (fileName) ->
  fileName = path.join config.workspace, fileName
  data = fs.readFileSync fileName
  styleSheets.push cssom.parse data.toString()
  log 'readStyleSheet'
  return

collectMergeStyle = (styleSheet) ->
  mergeStyle = []
  styleSheet.cssRules.forEach (rule) ->
    if rule.style.merge
      mergeStyle.push rule
  log 'collectMergeStyle'
  return mergeStyle
###
  3.collect images info
###

collectMergeImg = (styleObj) ->
  styleObj.forEach (obj)->
    mergeStyles[obj.style.merge] = []
  styleObj.forEach (obj)->
    merge = obj.style.merge
    if merge
      src = getImgSrc(obj)
      style =
        style: obj
        src: src
      mergeStyles[merge].push style
  log 'collectMergeImg'
  return

getImgSrc = (obj) ->
  bgImg = obj.style['background-image']
  if bgImg
    src = bgImg.split(regexp.image)[1]
  else
    console.log 'error, image no found!'.red
  log 'getImgSrc'
  return src

readImageInfo = (obj, filname, len, callback)->
  imgSrc = obj.src
  fs.createReadStream(imgSrc).pipe(new PNG())
  .on 'parsed', ->
      imageInfo =
        img: this
        w: this.width
        h: this.height
        merge: obj.style.style.merge
        src: imgSrc
      imgObjs[filname].push imageInfo
      log 'readImageInfo'
      console.log imgSrc.magenta
      if imgObjs[filname].length == len
        callback(imgObjs[filname], filname)
        console.log 'last'.red
  .on 'error',(e)->
      console.log ">>Skip: #{e.message} of #{imgSrc}".red
  return

packImg = (imgs)->
  packer = new GrowingPacker()
  imgs.sort (a,b) ->
    return (b.h  - a.h )
  packer.fit(imgs)
  imgs.root = packer.root
  log 'packImg'
  return imgs

createPng = (width, height) ->
  png = new PNG({
    width: width
    height: height
  })
  console.log png
  i = 0
  while i < png.height
    j = 0
    while j < png.width
      idx = (png.width * i + j) << 2
      png.data[idx] = 0
      png.data[idx+1] = 0
      png.data[idx+2] = 0
      png.data[idx+3] = 0
      j++
    i++
  log 'createPng'
  return png

mergePng = (images, filename) ->
  png = createPng images.root.w, images.root.h
  images.forEach (image) ->
    image.img.bitblt(png, 0, 0, image.w, image.h, image.fit.x, image.fit.y)
  png.pack().pipe fs.createWriteStream "output/img/#{filename}.png"
  log 'mergePng'
  return

###
  4.change styleSheet
###

changeStyleSheet = (filename) ->
  console.log filename
###
  main
###
readConfig CONFIG_SRC
readStyleSheet config.input[0]
styleSheets.forEach (styleSheet)->
  collectMergeImg collectMergeStyle styleSheet
  return
for merge of mergeStyles
  mergeStyles[merge].forEach (mergeStyle) ->
    len = mergeStyles[merge].length
    imgObjs[merge] = []
    readImageInfo mergeStyle, merge, len, (imgs, filname)->
      mergePng packImg(imgs), filname
      return
    return
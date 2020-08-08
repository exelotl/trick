##[
.. include:: doc/styles.rst
`↩ back to overview<../trick.html>`_

Module for converting between PNG and raw GBA/NDS image data.
]##

import nimPNG
import streams

type
  GfxColor* = uint16
    ## 15-bit (5 bits per channel) BGR color.
    ## Each component has a value between 0 and 31.
    ##
    ## The 16th bit has no meaning on the GBA, but in this library
    ## it is used to represent empty/transparent pixels.
    ##
    ## The `r`, `g` and `b` components can be accessed using the provided getters and setters.
  
  GfxPalette* = seq[GfxColor]
    ## A list of colors used by a graphic.
  
  GfxBpp* = enum
    ## Bits-per-pixel specifier.
    gfx2bpp = 2
      ## Not used by the GBA hardware, but some games may wish
      ## to store graphics in a compact 2bpp paletted format.
    gfx4bpp = 4
      ## 16-color GBA graphics format.
    gfx8bpp = 8
      ## 256-color GBA graphics format.
  
  GfxLayout* = enum
    gfxBitmap  ## Image is a simple matrix of pixels
    gfxTiles   ## Image is broken into 8x8px tiles
  
  GfxInfo* = object
    ## A specification for how to read or write a paletted image.
    ## This is used by the `pngToBin` or `binToPng` functions.
    
    pal*: GfxPalette
      ## Defines the colors used by the image.
      ## When building the palette via `pngToBin`, it's recommended to
      ## initialize this to `@[clrEmpty]` so that the first encountered
      ## color will be given index 1.
      ## Transparent pixels will always be given index 0.
    bpp*: GfxBpp
      ## How many bits-per-pixel are used by this graphic.
    layout*: GfxLayout
      ## Bitmap or tiled arrangement.
    width*: int 
      ## Image width (only needed for `binToPng`, will be set by `pngToBin`)
    height*: int
      ## Image height (unneeded, will be set by `pngToBin`)
    palGroup*: int
      ## An optional tag which you could use to check whether two
      ## graphics are sharing a palette

const clrEmpty* = (1 shl 15).GfxColor
  ## A color which is different to all other colors due to the unused bit.
  ## It's recommended to use this as the first item in any palette.

func rgb15*(r, g, b: int): GfxColor =
  ## Create a 15-bit BGR color.
  ## Each component should be from 0 to 31.
  (r or (g shl 5) or (b shl 10)).GfxColor

func rgb8*(r, g, b: int): GfxColor =
  ## Create a 15-bit BGR color, using 8-bit components
  ((r shr 3) or ((g shr 3) shl 5) or ((b shr 3) shl 10)).GfxColor

func rgb8*(rgb: int): GfxColor =
  ## Create a 15-bit BGR color from a 24-bit RGB color of the form 0xRRGGBB
  (((rgb and 0xff0000) shr 19) or
    (((rgb and 0x00ff00) shr 11) shl 5) or
    (((rgb and 0x0000ff) shr 3) shl 10)).GfxColor

proc r*(color: GfxColor): int {.noSideEffect.} =
  ## .. include:: doc/see-below.rst
  color.int and 0x001F

proc `r=`*(color: var GfxColor, r: int) =
  ## Red component of a 15-bit color.
  color = (color and 0b1_11111_11111_00000) or (r.uint16 and 0x001F)


proc g*(color: GfxColor): int {.noSideEffect.} =
  ## .. include:: doc/see-below.rst
  (color.int shr 5) and 0x001F

proc `g=`*(color: var GfxColor, g: int) =
  ## Green component of a 15-bit color.
  color = (color and 0b1_11111_00000_11111) or (g.uint16 and 0x001F) shl 5


proc b*(color: GfxColor): int {.noSideEffect.} =
  ## .. include:: doc/see-below.rst
  (color.int shr 10) and 0x001F

proc `b=`*(color: var GfxColor, b: int) =
  ## Blue component of a 15-bit color.
  color = (color and 0b1_00000_11111_11111) or (b.uint16 and 0x001F) shl 10


proc readPal*(palFile: string): GfxPalette =
  ## Read a palette from a binary file.
  let palData = readFile(palFile)
  for i in 0..<(palData.len div 2):
    result.add(palData[i*2].uint16 or (palData[i*2+1].uint16 shl 8))  # little endian?

proc writePal*(palFile: string, pal: GfxPalette) =
  ## Write a palette to a binary file.
  let outStream = openFileStream(palFile, fmWrite)
  defer: outStream.close()
  for color in pal:
    let b1 = (color and 0x00ff).uint8
    let b2 = ((color and 0xff00) shr 8).uint8
    outStream.write(b1)
    outStream.write(b2)

func swap4bpp*(ab: uint8): uint8 =
  ## Swap the low and high nybbles within a byte. e.g.
  ##
  ## ```nim
  ## swap4bpp(0x12) == 0x21
  ## ```
  ## This is needed because, in 4bpp graphics on the GBA, each byte represents
  ## two pixels, whereby the lower 4 bits define the color of the left pixel
  ## and the higher 4 bits define the color of the right pixel.
  ##
  let a = ab and 0xf0
  let b = ab and 0x0f
  (b shl 4) or (a shr 4)

func swap2bpp*(abcd: uint8): uint8 =
  ## Swap all pairs of bits within a byte. e.g. 
  ##
  ## ```nim
  ## swap2bpp(0b00_01_10_11) == 0b11_10_01_00
  ## ```
  ## May be useful for games that store graphics in a 2bpp format.
  ## 
  let a = abcd and 0b11000000
  let b = abcd and 0b00110000
  let c = abcd and 0b00001100
  let d = abcd and 0b00000011
  (d shl 6) or (c shl 2) or (b shr 2) or (a shr 6) 

iterator tileEncode*(width, height: int, bpp=gfx8bpp, tileWidth=8, tileHeight=8): tuple[destIndex, srcIndex:int] =
  ## Used to unravel a tiled space into a linear array.
  ## If each index in the space contains more than one pixel of data, the bpp option can be specified.
  assert(width mod tileWidth == 0)
  assert(height mod tileHeight == 0)
  let pixelsPerByte = 8 div ord(bpp)
  let widthInTiles = width div tileWidth
  var tx,ty,px,py: int
  for i in 0..<width*height:
    let x = tx*tileWidth + px
    let y = ty*tileHeight + py
    if i mod pixelsPerByte == 0:
      yield (i div pixelsPerByte, (x + y*width) div pixelsPerByte)
    
    px += 1
    if px >= tileWidth:
      px = 0
      py += 1
      if py >= tileHeight:
        py = 0
        tx += 1
        if tx >= widthInTiles:
          tx = 0
          ty += 1

proc binToPng*(data: string, conf: GfxInfo): PNG =
  ## Convert raw GBA/NDS graphics data to a PNG object
  var encoder = makePNGEncoder()
  var colorMode = newColorMode(LCT_PALETTE, ord(conf.bpp))
  
  # copy palette from bgr15 to rgba32
  for color in conf.pal:
    colorMode.addPalette(
      (color.r * 256) div 32,
      (color.g * 256) div 32,
      (color.b * 256) div 32,
      255
    )
  encoder.modeIn = colorMode
  encoder.modeOut = colorMode
  
  # calculate height
  let numPixels = data.len * (8 div ord(conf.bpp))
  let width = conf.width
  let height = numPixels div width
  
  var pngData:string
  
  # copy pixels, rearrange if needed depending on layout
  case conf.layout:
    of gfxTiles:
      pngData = newString(data.len)
      for i, j in tileEncode(width, height, conf.bpp):
        pngData[j] = data[i]
    of gfxBitmap:
      shallowCopy(pngData, data)
  
  # correct pixel endianness within bytes
  case conf.bpp
  of gfx2bpp:
    for abcd in mitems(pngData):
      abcd = swap2bpp(abcd.uint8).char
  of gfx4bpp:
    for ab in mitems(pngData):
      ab = swap4bpp(ab.uint8).char
  of gfx8bpp:
    discard   # nothing to do
    
  result = encodePNG(pngData, width, height, encoder)

proc writeFile*(filename: string, png: PNG) =
  ## Write a PNG object to a file
  var stream = openFileStream(filename, fmWrite)
  defer: stream.close()
  png.writeChunks(stream)

proc pngToBin*(filename: string, conf: var GfxInfo, buildPal: bool): string =
  ## Load a PNG by filename and convert to GBA/NDS image data.
  ##
  ## Pixels are returned as a string of raw binary data.
  ## Fields of `conf` will be modified to include any additional data such as image width.
  ##
  ## If `buildPal` is true, unique colors will be added to `conf.pal`.
  ## Otherwise new colors are considered an error.
  
  let pngRes = loadPNG32(filename)
  let pixels = pngRes.data
  let numPixels = pngRes.width * pngRes.height
  let numBytes = numPixels div (8 div ord(conf.bpp))
  
  # update width in case the user of this procedure wants to know.
  conf.width = pngRes.width
  
  # initialise the output data
  var data = newString(numBytes)
  
  # get the Nth 32-bit RGBA pixel in the PNG data
  # convert to 15-bit BGR and return its index in the palette
  template getPixel(n: int): uint8 =
    let i = n*4
    if pixels[i+3] == 0.char:
      # fully transparent pixel always maps to index zero
      0.uint8
    else:
      let color = rgb8(pixels[i].int, pixels[i+1].int, pixels[i+2].int)
      var c = color.GfxColor
      let index = conf.pal.find(color)
      if index == -1:
        # extend the palette if we are allowed to
        if buildPal:
          conf.pal.add(color)
          (conf.pal.len-1).uint8
        else:
          raise newException(Exception, "While processing " & filename & ", encountered a color which does not exist in the specified palette")
      else: index.uint8
  
  # fill the output bytes with palette entries according to bit depth
  case conf.bpp
  of gfx2bpp:
    for i in 0..<numBytes:
      data[i] = (
        (getPixel(i*4)) or
        (getPixel(i*4 + 1) shl 2) or
        (getPixel(i*4 + 2) shl 4) or
        (getPixel(i*4 + 3) shl 6)).char
  of gfx4bpp:
    for i in 0..<numBytes:
      data[i] = (getPixel(i*2) or (getPixel(i*2 + 1) shl 4)).char
  of gfx8bpp:
    for i in 0..<numBytes:
      data[i] = getPixel(i).char
  
  case conf.layout
  of gfxTiles:
    result = newString(numBytes)
    for i, j in tileEncode(pngRes.width, pngRes.height, conf.bpp):
      result[i] = data[j]
  of gfxBitmap:
    result = data
  

proc readPng*(filename: string): PNG[string] =
  ## Load a `PNG` object instead of the less-flexible `PNGResult` that nimPNG usually returns.
  var stream = openFileStream(filename, fmRead)
  result = decodePNG(string, stream)
  stream.close()

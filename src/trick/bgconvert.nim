import common, gfxconvert, palbuilder
import tables, hashes, strformat, intsets
import nimPNG

##[
.. include:: doc/styles.rst
`↩ back to overview<../trick.html>`_
]##

type
  SomeTile* = Tile4 | Tile8 | Tile16   ## Typeclass representing all tiles.
  Tile4* = array[32, uint8]      ## Data for an 8x8 pixel tile at 4bpp, where each pixel is a palette index (0 = transparent)
  Tile8* = array[64, uint8]      ## Data for an 8x8 pixel tile at 8bpp, where each pixel is a palette index (0 = transparent) 
  Tile16* = array[64, GfxColor]  ## Data for an 8x8 pixel tile at 15bpp, where each pixel is a direct color
  ScrEntry* = distinct uint16
    ## Screen entry. Map data is simply an array of these.
    ## 
    ## Each entry holds an index of a tile in the tileset, along with flipping flags and a palette index.
    ## 
    ## **Properties:**
    ## - `tid<#tid.t,ScrEntry,int>`_
    ## - `hflip<#hflip.t,ScrEntry,bool>`_
    ## - `vflip<#vflip.t,ScrEntry,bool>`_
    ## - `palbank<#palbank.t,ScrEntry,int>`_
  
  Screenblock* = array[1024, ScrEntry]
    ## A 32x32 block of screen entries, which represents a 256x256 pixel region of a tiled background.
    ## 
    ## On the GBA, each background layer can consist of up to 4 screenblocks (in a 2x2 arrangement).
    ## 
    ## Within a screenblock, an individual entry can be indexed by `sb[y*32 + x]`
  
  Bg16* = object
    ## A 15bpp (i.e. direct color, 5 bits per channel) tiled background.
    ## 
    ## This is not a real format that the GBA uses, but is useful as an intermediate representation before converting to 4bpp or 8bpp.
    w*, h*: int
    img*: seq[Tile16]
    map*: seq[ScrEntry]
  
  Bg8* = object
    ## An 8bpp tiled background.
    w*, h*: int             ## Dimensions in tiles
    img*: seq[Tile8]        ## Tile/char image data
    map*: seq[ScrEntry]     ## Map entries
    pal*: GfxPalette        ## Palette with up to 256 colors
  
  Bg4* = object
    ## A 4bpp tiled background with a list of palettes.
    w*, h*: int             ## Dimensions in tiles
    img*: seq[Tile4]        ## Tile/char image data
    map*: seq[ScrEntry]     ## Map entries
    pals*: seq[GfxPalette]  ## List of palettes
  
  BgAff* = object
    ## An 8bpp tiled background with a map of only simple indexes.
    w*, h*: int             ## Dimensions in tiles
    img*: seq[Tile8]        ## Tile/char image data
    map*: seq[uint8]        ## Map entries (just simple tile indexes)
    pal*: GfxPalette        ## Palette with up to 256 colors

# Screen-entry Flags
const
  SE_HFLIP: uint16 = 0x0400   ## Horizontal flip
  SE_VFLIP: uint16 = 0x0800   ## Vertical flip
  SE_ID_MASK: uint16 = 0x03FF
  SE_ID_SHIFT: uint16 = 0
  SE_FLIP_MASK: uint16 = 0x0C00
  SE_FLIP_SHIFT: uint16 = 10
  SE_PALBANK_MASK: uint16 = 0x0000F000
  SE_PALBANK_SHIFT: uint16 = 12


template tid*(se: ScrEntry): int =
  ## .. include:: doc/see-below.rst
  (se.uint16 and SE_ID_MASK).int

template `tid=`*(se: var ScrEntry, val: int) =
  ## Tile index. i.e. which tile in the tileset to use for this entry.
  se = (((val.uint16 shl SE_ID_SHIFT) and SE_ID_MASK) or (se.uint16 and not SE_ID_MASK)).ScrEntry


template hflip*(se: ScrEntry): bool =
  ## .. include:: doc/see-below.rst
  (se.uint16 and SE_HFLIP) != 0

template `hflip=`*(se: var ScrEntry, val: bool) =
  ## If true, this tilemap entry is flipped horizontally.
  se = ((val.uint16 shl 10) or (se.uint16 and not SE_HFLIP)).ScrEntry


template vflip*(se: ScrEntry): bool =
  ## .. include:: doc/see-below.rst
  (se.uint16 and SE_VFLIP) != 0

template `vflip=`*(se: var ScrEntry, val: bool) =
  ## If true, this tilemap entry is flipped vertically.
  se = ((val.uint16 shl 11) or (se.uint16 and not SE_VFLIP)).ScrEntry


template palbank*(se: ScrEntry): int =
  ## .. include:: doc/see-below.rst
  ((se.uint16 and SE_PALBANK_MASK) shr SE_PALBANK_SHIFT).int

template `palbank=`*(se: var ScrEntry, val: int) =
  ## Which palette is used by this entry (when working with 4bpp tiles)
  se = (((val.uint16 shl SE_PALBANK_SHIFT) and SE_PALBANK_MASK) or (se.uint16 and not SE_PALBANK_MASK)).ScrEntry

template `and`(a: ScrEntry, b: uint16): ScrEntry = (a.uint16 and b).ScrEntry
template `or`(a: ScrEntry, b: uint16): ScrEntry = (a.uint16 or b).ScrEntry


proc hashData64(data: pointer, size: int): Hash =
  ## Hashes an array of bytes of size `size`, which should be a multiple of 64 (assuming a 64-bit system)
  var h: Hash = 0
  var p = cast[ptr UncheckedArray[int]](data)
  var i = 0
  var s = size div sizeof(int)
  while s > 0:
    h = h !& p[i]
    inc i
    dec s
  result = !$h

proc hash*(tile: ref SomeTile): Hash =
  ## Hashes a tile.
  hashData64(tile, sizeof(tile))


# Tile Flipping
# -------------

proc flipX*[T: SomeTile](tile: T): T =
  ## Returns a copy of `tile` flipped horizontally.
  
  when tile is Tile4:
    # Flipping of 4bpp tiles needs its own implementation
    # because each element in the array represents more than one pixel
    for y in 0..<8:
      let o = y*4
      result[o + 0] = swap4bpp(tile[o + 3])
      result[o + 1] = swap4bpp(tile[o + 2])
      result[o + 2] = swap4bpp(tile[o + 1])
      result[o + 3] = swap4bpp(tile[o + 0])
  else:
    # Flipping of 8bpp and 15bpp tiles can have a generic implementation
    for y in 0..<8:
      let o = y*8
      for x in 0..<8:
        result[o + x] = tile[o + 7-x]

proc flipY*[T: SomeTile](tile: T): T =
  ## Returns a copy of `tile` flipped vertically.
  
  when tile is Tile4:
    for y in 0..<8:
      let a = y*4
      let b = (7-y)*4
      result[a + 0] = tile[b + 0]
      result[a + 1] = tile[b + 1]
      result[a + 2] = tile[b + 2]
      result[a + 3] = tile[b + 3]
  else:
    for y in 0..<8:
      let a = y*8
      let b = (7-y)*8
      for x in 0..<8:
        result[a + x] = tile[b + x]


# Tilemap Reduction
# -----------------

proc reduce*[T:SomeTile](data: seq[T]|View[T], firstBlank=true): tuple[tiles: seq[T], map: seq[ScrEntry]] =
  ## Convert an array of tiles into a minimal tileset with duplicates removed
  ## (including horizontally/vertically flipped copies) and a map of tile indexes.
  
  var dictionary: Table[T, ScrEntry]  # mapping from tiles to their index (and flip flags)
  var tiles: seq[T]
  var map: seq[ScrEntry]
  
  if firstBlank:
    # add empty tile to tileset and dictionary
    var t: T
    when t is Tile16:
      for px in mitems(t):
        px = clrEmpty
    tiles.add(t)
    dictionary[t] = 0.ScrEntry
  
  for t in data:
    dictionary.withValue(t, se) do:
      # tile exists, add entry to map
      map.add(dictionary[t])
    do:
      # tile doesn't exist in any orientation, so let's add all of them to the dictonary
      let tx = t.flipX()
      let ty = t.flipY()
      let txy = tx.flipY()
      let se = tiles.len.ScrEntry
      # add the flipped versions first, so that the default for symmetrical tiles is unflipped
      dictionary[txy] = se or SE_HFLIP or SE_VFLIP
      dictionary[ty] = se or SE_VFLIP
      dictionary[tx] = se or SE_HFLIP
      dictionary[t] = se
      map.add(se)    # add entry to map
      tiles.add(t)   # add tile to tileset
  
  (tiles, map)


proc reduceAff*[T:SomeTile](data: seq[T]|View[T], firstBlank=true): tuple[tiles: seq[T], map: seq[uint8]] =
  ## Convert an array of tiles into a minimal tileset with duplicates removed.
  ## The resulting map has only indices, no palette or flip bits, and symmetrical tiles in the tileset will not be handled.
  
  var dictionary: Table[T, uint8]  # mapping from tiles to their index
  var tiles: seq[T]
  var map: seq[uint8]
  
  if firstBlank:
    # add empty tile to tileset and dictionary
    var t: T
    when t is Tile16:
      for px in mitems(t):
        px = clrEmpty
    tiles.add(t)
    dictionary[t] = 0'u8
  
  for t in data:
    dictionary.withValue(t, se) do:
      # tile exists, add entry to map
      map.add(dictionary[t])
    do:
      # tile doesn't exist in any orientation, so let's add all of them to the dictonary
      let id = tiles.len.uint8
      dictionary[t] = id
      map.add(id)    # add entry to map
      tiles.add(t)   # add tile to tileset
  
  (tiles, map)


proc toScreenBlocks*(map: seq[ScrEntry]; w: int): seq[Screenblock] =
  ## Arrange a map into screenblocks.
  ## 
  ## The width and height of the map should be multiples of 32.
  ## 
  ## **Example:**
  ## 
  ## .. code-block:: nim
  ##   let bg4 = loadBg4("myLevel.png")
  ##   writeFile("my_level.map.bin", toBytes(bg4.map.toScreenBlocks(bg4.w)))
  ##   writeFile("my_level.img.bin", toBytes(bg4.img))
  ##   writeFile("my_level.pal.bin", toBytes(joinPalettes(bg4.pals)))
  
  let h = map.len div w
  doAssert(w > 0 and (w mod 32 == 0), "Width of map in tiles ({w}) should be a multiple of 32".fmt)
  doAssert(map.len mod w == 0, "Map length should be a multiple of its width in tiles ({w})".fmt)
  doAssert(h > 0 and (h mod 32 == 0), "Height of map in tiles ({h}) should be a multiple of 32".fmt)
  
  let widthInScrblocks = w div 32
  let heightInScrblocks = h div 32
  let numScreenblocks = widthInScrblocks * heightInScrblocks
  
  result = newSeq[Screenblock](numScreenblocks)
  
  for i, sb in mpairs(result):
    let sbx = i mod widthInScrblocks
    let sby = i div widthInScrblocks
    for y in 0..<32:
      for x in 0..<32:
        let xInMap = sbx*32 + x
        let yInMap = sby*32 + y
        sb[x + y*32] = map[xInMap + yInMap * w]


proc clear*(tile: var SomeTile) =
  ## Set all pixels in a tile to transparent.
  ## 
  ## - For 4bpp and 8bpp (paletted) tiles, each pixel is set to zero.
  ## - For 15bpp (direct color) tiles, each pixel is set to `clrEmpty`.
  ## 
  when tile is Tile16:
    for p in mitems(tile):
      p = clrEmpty    
  else:
    for p in mitems(tile):
      p = 0


# Palette loading
# ---------------
# Return IntSets so they can be passed to palettebuilder

proc getPalettesFromTiles*(tiles16: seq[Tile16]): seq[IntSet] =
  ## Create a list containing one palette for each tile in a list of 15bpp direct color tiles.
  ## 
  ## Each palette is represented as `IntSet` for performance reasons. You can use
  ## `reducePalettes<palettebuilder.html#reducePalettes,seq[IntSet]>`_ to merge the result
  ## down to a lesser number of palettes.
  ## 
  ## Fails with `AssertionError` if there are more than 16 colors in any single tile (including `clrEmpty`).
  
  for t in tiles16:
    var pal = initIntSet()
    pal.incl(clrEmpty.int)
    for color in t:
      pal.incl(color.int)
      if pal.len > 16:
        raiseAssert("Tile has too many colors!")
    result.add(pal)


# High level background loading functions
# ---------------------------------------

proc loadBg16*(filename: string, firstBlank = true): Bg16 =
  ## Load a direct color 15bpp tiled background from a PNG file.
  ## 
  ## Note: this isn't a real format that the GBA uses, but is useful as
  ## an intermediate representation before converting to 4bpp or 8bpp.
  
  let pngRes = loadPNG32(filename)
  let pixels = pngRes.data
  let numPixels = pngRes.width * pngRes.height
  let numTiles = numPixels div (8*8)
  
  var tiles = newSeq[Tile16](numTiles)
  let tilesAsPixels = viewSeqAs[GfxColor, Tile16](tiles) 
  
  for i, j in tileEncode(pngRes.width, pngRes.height):
    let k = j*4
    tilesAsPixels[i] =
      if pixels[k+3] == 0.char:  clrEmpty  # fully transparent pixel
      else: rgb8(pixels[k].int, pixels[k+1].int, pixels[k+2].int)
  
  # reduce to 15bpp tileset + map
  var (img16, map) = reduce(tiles, firstBlank)
  result.w = pngRes.width div 8
  result.h = pngRes.height div 8
  result.img = img16
  result.map = map


proc toBg8*(bg16: Bg16): Bg8 =
  ## Convert a direct color 15bpp background to a paletted 8bpp background.
  
  # mapping of colors to their position in the palette
  var colorIndexes: OrderedTable[GfxColor, int]
  
  # first color is transparent
  colorIndexes[clrEmpty] = 0
  
  # convert the tileset from 15bpp to 8bpp
  var img8 = newSeq[Tile8](bg16.img.len)
  for i, tile in bg16.img:
    for j, color in tile:
      var index = colorIndexes.getOrDefault(color, -1)
      if index == -1:
        index = colorIndexes.len
        colorIndexes[color] = index
      img8[i][j] = index.uint8
  
  var pal: GfxPalette
  for color in keys(colorIndexes):
    pal.add(color)
  
  doAssert(pal.len <= 256)
  
  result.w = bg16.w
  result.h = bg16.h
  result.img = img8
  result.map = bg16.map
  result.pal = pal


proc toBg4*(bg16: Bg16): Bg4 =
  ## Convert a direct color 15bpp background to a paletted 4bpp background.
  
  # figure out a set of 16-color palettes, and which palette each tile in the tileset should have.
  let (mergedPals, palNums) = reducePalettes(getPalettesFromTiles(bg16.img))
  
  # convert the tileset from 15bpp to 4bpp
  var img4 = newSeq[Tile4](bg16.img.len)
  for i, tile in bg16.img:
    let intendedPalNum = palNums[i]
    let pal = mergedPals[intendedPalNum]
    for j, outByte in mpairs(img4[i]):
      let color1 = tile[j*2]
      let color2 = tile[j*2 + 1]
      let index1 = pal.find(color1)
      let index2 = pal.find(color2)
      doAssert(index1 != -1)
      doAssert(index2 != -1)
      outByte = (index1 or (index2 shl 4)).byte
  
  # copy the map entries and set the correct palettes
  var map = bg16.map
  for se in mitems(map):
    se.palbank = palNums[se.tid]
  
  result.w = bg16.w
  result.h = bg16.h
  result.img = img4
  result.map = map
  result.pals = mergedPals


proc loadBg8*(filename: string, firstBlank = true): Bg8 =
  ## Load an 8bpp paletted tiled background from a PNG file.
  
  let png = readPng(filename)
  let info = png.getInfo()
  let pngPal = info.mode.palette
  
  if pngPal.len == 0:
    # Load a direct color image then convert to 8bpp paletted.
    return loadBg16(filename).toBg8()
  
  var pal: GfxPalette
  for c in pngPal:
    if ord(c.a) == 0:
      pal.add clrEmpty
    else:
      pal.add rgb8(ord(c.r), ord(c.g), ord(c.b))
  
  doAssert(pal.len <= 256)
  
  let pixels = png.pixels
  let numPixels = info.width * info.height
  
  let numTiles = numPixels div (8*8)
  var tiles = newSeq[Tile8](numTiles)
  let tilesAsPixels = viewSeqAs[char, Tile8](tiles) 
  
  for i, j in tileEncode(info.width, info.height):
    tilesAsPixels[i] = pixels[j]
  
  # reduce to 8bpp tileset + map
  var (img8, map) = reduce(tiles)
  result.w = info.width div 8
  result.h = info.height div 8
  result.img = img8
  result.map = map
  result.pal = pal


proc toBg4*(bg8: Bg8): Bg4 =
  ## Strict conversion from 8bpp background to 4bpp background.
  ## 
  ## If the 8bpp background has more than 16 colors, then it will be treated as having
  ## several palettes (`0..15`, `16..31`, `32..47`, ...).
  ## 
  ## Each tile in the image is only allowed to refer to colors from a single one of those palettes.
  
  var maxUsedPalette = 0  # with this we can trim any colors that weren't used?
  var pals: seq[GfxPalette]
  
  for i, c in bg8.pal:
    if i mod 16 == 0:
      pals.add(newSeqOfCap[GfxColor](cap=16))
    pals[pals.len-1].add(c)
  
  var img = newSeq[Tile4](bg8.img.len)
  var map = bg8.map
  var tidToPal: seq[int]
  
  proc firstNonTransparentIndex(t8: var Tile8): uint8 =
    for p in t8:
      if p mod 16 != 0:
        return p
  
  # Convert 8bpp to 4bpp
  for i, t4 in mpairs(img):
    let t8 = unsafeAddr bg8.img[i]
    let palNum = firstNonTransparentIndex(t8[]) div 16
    let palStart = palNum * 16
    tidToPal.add(palNum.int)
    if palNum.int > maxUsedPalette:
      maxUsedPalette = palNum.int
    for j, p4 in mpairs(t4):
      var p = t8[j*2]
      var q = t8[j*2 + 1]
      if p mod 16 == 0: p = palStart
      if q mod 16 == 0: q = palStart
      doAssert(
        (p div 16 == palNum) and (q div 16 == palNum),
        block:
          let badPixel = if (p div 16) != palNum: p else: q
          fmt"Found pixel with value {badPixel} which is outside the designated palette range ({palStart}..{palStart+15}) for tile number {i}."
      )
      p4 = (p - palStart.uint8) or ((q - palStart.uint8) shl 4)
  
  for se in mitems(map):
    se.palbank = tidToPal[se.tid]
  
  result.w = bg8.w
  result.h = bg8.h
  result.img = img
  result.map = map
  result.pals = pals[0..maxUsedPalette]


proc loadBg4*(filename: string, indexed=false, firstBlank=true): Bg4 =
  ## Load a 4bpp tiled background from a PNG file.
  ## 
  ## The resulting background is ideal for usage on the GBA.
  ## 
  ## **Parameters:**
  ## 
  ## filename
  ##   Path to PNG file.
  ## indexed
  ##   If true, the palette of the input PNG will be preserved.
  ##   Otherwise, the input PNG will be loaded as true color,
  ##   and new palettes will be derived from it.
  ## 
  if indexed:
    var bg = loadBg8(filename, firstBlank)
    bg.toBg4()
  else:
    var bg = loadBg16(filename, firstBlank)
    bg.toBg4()


proc toBgAff*(bg16: Bg16): BgAff =
  ## Convert a direct color 15bpp background to an affine background.
  
  doAssert(bg16.img.len <= 256, "Affine backgrounds can't have more than 256 tiles.")
  
  # mapping of colors to their position in the palette
  var colorIndexes: OrderedTable[GfxColor, int]
  
  # first color is transparent
  colorIndexes[clrEmpty] = 0
  
  # convert the tileset from 15bpp to 8bpp
  var img8 = newSeq[Tile8](bg16.img.len)
  for i, tile in bg16.img:
    for j, color in tile:
      var index = colorIndexes.getOrDefault(color, -1)
      if index == -1:
        index = colorIndexes.len
        colorIndexes[color] = index
      img8[i][j] = index.uint8
  
  var pal: GfxPalette
  for color in keys(colorIndexes):
    pal.add(color)
  
  doAssert(pal.len <= 256)
  
  var map: seq[uint8]
  for se in bg16.map:
    map.add(se.tid.uint8)
  
  result.w = bg16.w
  result.h = bg16.h
  result.img = img8
  result.map = map
  result.pal = pal

proc loadBgAff*(filename: string, firstBlank = true): BgAff =
  ## Load an affine background from a PNG file.
  
  let png = readPng(filename)
  let info = png.getInfo()
  let pngPal = info.mode.palette
  
  if pngPal.len == 0:
    # Load a direct color image then convert to 8bpp paletted.
    result = loadBg16(filename).toBgAff()
  
  else:
    var pal: GfxPalette
    for c in pngPal:
      if ord(c.a) == 0:
        pal.add clrEmpty
      else:
        pal.add rgb8(ord(c.r), ord(c.g), ord(c.b))
    
    doAssert(pal.len <= 256)
    
    let pixels = png.pixels
    let numPixels = info.width * info.height
    
    let numTiles = numPixels div (8*8)
    var tiles = newSeq[Tile8](numTiles)
    let tilesAsPixels = viewSeqAs[char, Tile8](tiles) 
    
    for i, j in tileEncode(info.width, info.height):
      tilesAsPixels[i] = pixels[j]
    
    # reduce to 8bpp tileset + map
    var (img8, map) = reduceAff(tiles)
    doAssert(img8.len <= 256, "Affine backgrounds can't have more than 256 tiles.")
    result.w = info.width div 8
    result.h = info.height div 8
    result.img = img8
    result.map = map
    result.pal = pal


# Tile reduction tests

when isMainModule:
  
  # testing with mario level @ 4bpp
  block:
    var conf = GfxInfo(
      pal: @[clrEmpty],
      bpp: gfx4bpp,
      layout: gfxTiles,
    )
    
    var data = pngToBin("test_gfx/mario.png", conf, buildPal=true)
    
    let dataTiles = viewBytesAs[Tile4](data)
    let (tiles, map) = reduce(dataTiles)
    
    # find a good width for exported image
    var w = tiles.len div 2
    while tiles.len mod w != 0:
      w -= 1
    conf.width = w*8
    
    let tilesetBytes = toBytes(tiles)
    let outPng = binToPng(tilesetBytes, conf)
    writeFile("test_gfx/mario_reduced_tiles.png", outPng)
    
    let mapBytes = toBytes(map)
    writeFile("test_gfx/mario_map.bin", mapBytes)
  
  # testing with goodboy level @ 8bpp
  block:
    var conf = GfxInfo(
      pal: @[clrEmpty],
      bpp: gfx8bpp,
      layout: gfxTiles,
    )
    
    var data = pngToBin("test_gfx/LevelTest2.png", conf, buildPal=true)
    let mapWidthInTiles = conf.width div 8
    let dataTiles = viewBytesAs[Tile8](data)
    let (tiles, map) = reduce(dataTiles)
    
    var w = tiles.len div 4
    while tiles.len mod w != 0:
      w -= 1
    conf.width = w*8
    
    let tilesetBytes = toBytes(tiles)
    let outPng = binToPng(tilesetBytes, conf)
    writeFile("test_gfx/LevelTest2_tiles.png", outPng)
    writeFile("test_gfx/LevelTest2_gfx.bin", toBytes(tiles))
    let mapScrBlocks = toScreenBlocks(map, mapWidthInTiles)
    writeFile("test_gfx/LevelTest2_map.bin", toBytes(mapScrBlocks))
    writePal("test_gfx/LevelTest2_pal.bin", conf.pal)

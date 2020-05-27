##[
.. include:: doc/styles.rst
`↩ back to overview<../trick.html>`_
]##

import intsets
import gfxconvert

proc toPalette*(palSet: IntSet): GfxPalette =
  ## Convert an IntSet to a list of 15-bit colors, while ensuring
  ## that the trasparent color (`clrEmpty`) is always first.
  for n in palSet:
    let color = n.GfxColor
    if color == clrEmpty and result.len > 0:
      result.add(result[0])
      result[0] = color
    else:
      result.add(color)

proc toIntSet*(pal: GfxPalette): IntSet =
  ## Convert a list of colors to an IntSet, for efficient comparison and merging.
  for color in pal:
    result.incl(color.int)

proc reducePalettes*(tilePals: seq[IntSet]): tuple[mergedPals: seq[GfxPalette], palNums: seq[int]] =
  ## Given a list of individual palettes for each tile in the map
  ## Merge these down into a set of palettes and a list of indexes
  
  var palSets: seq[IntSet]    # master pal list
  var palNums: seq[int]       # index of which palette is used by each tile
  
  proc findOrExtend(newPal: IntSet): int =
    ## add newPal to the list of sets, or find an existing set to merge it with
    ## return the index of the new palette
    for i in 0..<palSets.len:
      
      if newPal <= palSets[i]:
        # newpal is a subset of another pal, nothing to be done
        return i
      
      elif newPal >= palSets[i]:
        # newpal is a superset of another pal, let's merge them
        let union = palSets[i] + newPal
        if union.len <= 16:  # but only if the result doesn't have more than 16 colors
          palSets[i].assign(union)
          return i
    
    # .. reaching end means we must append newPal to the list
    palSets.add(newPal)
    return palSets.len-1
  
  
  # 1. Find all tiles that share the same palettes.
  #    Assign each tile to an initial palette.
  for tid, palData in tilePals:
    palNums.add(findOrExtend(palData))
  
  # utilities for rearranging palettes
  
  proc remapPal(fromNum, toNum: int) =
    for i in 0..<palNums.len:
      if palNums[i] == fromNum:
        palNums[i] = toNum
  
  proc removePal(num:int) =
    palSets.delete(num)
    for i in 0..<palNums.len:
      if palNums[i] >= num:
        palNums[i] -= 1
  
  proc removePalQuick(num:int) =
    palSets.del(num)
    for i in 0..<palNums.len:
      if palNums[i] == palNums.len:
        palNums[i] = num
  
  # 2. Identify palettes which, when combined, do not exceed the maximum allowed size.
  #    For each pal, rating against every other pal, get heuristic value to decide how suitable the other pal is for merging.
  #    The pair with the highest rating will be merged.
  #    An easy heuristic would be the number of colors they have in common (more = better)
  proc mergeBestFit(): bool =
    const UNRATED = -999999
    var bestRating = UNRATED
    var bestRatedDest = -1
    var bestRatedSrc = -1
    
    for i in 0..<palSets.len:
      for j in 0..<palSets.len:
        if i == j: continue
        let destPal = palSets[i]  # the palette that we would merge into
        let srcPal = palSets[j]   # the palette that we would remove
        
        if union(srcPal, destPal).len > 16:
          ## Merging would result in too many colors, skip
          continue
        
        let commonColors = srcPal * destPal
        let srcOnlyColors = srcPal - destPal
        let destOnlyColors = destPal - srcPal
        
        # heuristic: prefer palettes with more colors in common and less different colors
        let rating = commonColors.len - min(srcOnlyColors.len, destOnlyColors.len)
        if rating > bestRating:
          bestRating = rating
          bestRatedDest = i
          bestRatedSrc = j
    
    if bestRating == UNRATED:
      # no merges were possible
      return false
    
    # merge the best rated couple:
    palSets[bestRatedDest].incl(palSets[bestRatedSrc])
    
    # remap and delete src
    remapPal(bestRatedSrc, bestRatedDest)
    removePal(bestRatedSrc)
    return true
  
  # 3. repeat step 2 until nothing changed.
  while mergeBestFit():
    discard
  
  var mergedPals: seq[GfxPalette]
  for s in palSets:
    mergedPals.add(s.toPalette())
  
  return (mergedPals, palNums)


proc joinPalettes*(mergedPals: seq[GfxPalette]): GfxPalette =
  ## Build a master palette bank from a set of 16-color palettes.
  ## 
  ## If a palette has less than 16 colors, it will be padded. If a palette has more than 16 colors, it will be truncated.
  ## 
  for pal in mergedPals:
    result.add(rgb8(0,0,0))      # transparent is copied as black I guess
    for i in 1..<16:
      if i < pal.len:
        result.add(pal[i])       # copy color
      else:
        result.add(rgb8(0,0,0))  # pad with black


when isMainModule:
  
  import nimpng, strformat
  
  # let pals = getTilePalettes("tilemaptest.png")
  # let (palettes, palNums) = reducePalettes(pals)
  
  # const w = 4
  # const h = 4
  # var str = ""
  # for y in 0..<h:
  #   for x in 0..<w:
  #     str &= $palNums[x + y*w] & " "
  #   if y != h-1:
  #     str &= "\n"
  # echo str
  
  proc getTilePalettes(pngRes: PNGResult): seq[IntSet] =
    ## Returns a list with one palette for each 8x8 tile in a decoded PNG image.
    ## You will most likely want to merge down this list using `reducePalettes`
    
    let pixels = pngRes.data
    let numPixels = pngRes.width * pngRes.height
    
    var pixelCount = 0
    var currentPal = initIntSet()
    currentPal.incl(clrEmpty.int)
    
    for i, j in tileEncode(pngRes.width, pngRes.height, gfx8bpp):
      let k = j*4
      let color = if pixels[k+3] == 0.char:  clrEmpty  # fully transparent pixel
                  else: rgb8(pixels[k].int, pixels[k+1].int, pixels[k+2].int)
      
      # add color to palette if it doesn't already exist
      currentPal.incl(color.int)
      if currentPal.len > 16:
        raiseAssert("Tile has too many colors!")
      
      # add palette to list if we moved onto a new tile
      pixelCount += 1
      if pixelCount >= 8*8:
        pixelCount = 0
        result.add(currentPal)
        currentPal = initIntSet()
        currentPal.incl(clrEmpty.int)
  
  proc correctImage(pngFileName: string): PNG =
    ## Correct a map image so that each tile only uses colors from a single block of 16 colors
    ## and hope that Grit will know what to do, in order to convert the image to 4bpp.
    ##
    ## An alternative would be to use Grit in 8bpp mode, and then convert the result from 8bpp to 4bpp.
    
    echo "Correcting palettes ", pngFileName
    
    let inputPng = loadPNG32(pngFileName)
    let width = inputPng.width
    let height = inputPng.height
    let sepPals = getTilePalettes(inputPng)
    let (mergedPals, palNums) = reducePalettes(sepPals)
    
    # build master palette from the set of merged palettes
    
    var masterPal: seq[GfxColor]
    for pal in mergedPals:
      masterPal.add(rgb8(0,0,0))      # transparent is copied as black I guess
      for i in 1..<16:
        if i < pal.len:
          masterPal.add(pal[i])       # copy color
        else:
          masterPal.add(rgb8(0,0,0))  # pad with black
    
    var info = GfxInfo(
      pal: masterPal,
      bpp: gfx8bpp,
      layout: gfxBitmap,
      width: width,
    )
    
    let pixels = inputPng.data
    let numPixels = width * height
    
    var data = newString(numPixels)
    
    for y in 0..<height:
      for x in 0..<width:
        let i = x + y*width
        let p = i*4
        let t = (x div 8) + (y div 8) * (width div 8)
        let paln = palNums[t]
        
        var index: int
        if pixels[p+3] == 0.char:
          index = 0  # transparent
        else:
          let color = rgb8(pixels[p].int, pixels[p+1].int, pixels[p+2].int)
          index = mergedPals[paln].find(color)
          assert(index != -1, "couldn't find color {color} in designated palette {paln} for tile ({x div 8},{y div 8})".fmt)
        
        data[i] = (paln*16 + index).char
    
    result = binToPng(data, info)
  
  let outPng = correctImage("../levels/planet2.png")
  writeFile("../levels/planet2_fix2.png", outPng)
  
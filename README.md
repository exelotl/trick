## Trick ;)

- [API Documentation](https://exelotl.github.io/trick)

Trick is a library for GBA and NDS asset conversion in Nim.

It can be used as a counterpart to [Natu](https://github.com/exelotl/natu), as an easy way to get images, maps and sounds into your GBA games.

It was also used for the [PP20th translation](https://www.romhacking.net/translations/4522/) project, thus is able to convert binary data back to PNG in some cases.

## Features

- Sprite Graphics
  - Convert PNG images to raw GBA image data, and vice-versa
  - Supported formats: 2 / 4 / 8 bpp paletted images using 15-bit BGR color, with bitmap or tile arrangement
- Backgrounds / Tilemaps
  - Convert PNG images to a map + tileset + palette.
  - Tileset reduction: identify & remove duplicate tiles, including flipped versions
  - Rearrange maps into screenblocks
- Palette Reduction
  - Given a list of palettes, attempt to merge them into the least number of 16-color palettes necessary. This doesn't produce optimal results, but may be good enough for some projects.
- Data Utils
  - Facilities to reinterpret data as an array of some known type, without copying
  - Convert raw bytes to C strings (a utility borrowed from the Nim compiler)
  - Name helpers: filename to identifier, snake_case to camelCase
- Audio
  - Translate [Maxmod](https://maxmod.devkitpro.org/) soundbank headers to Nim


## Overview

Trick is intended for making command-line tools to wrangle assets for your homebrew projects.

Installation

```
$ nimble install trick
```

Then

```nim
import trick
```


## Examples


### PNG to binary

Convert your sprite sheets into raw binary formats used by GBA/NDS games:

```nim
var conf = GfxInfo(
  pal: @[clrEmpty],   # initial palette
  bpp: gfx4bpp,       # bit depth
  layout: gfxTiles,   # arrange into 8x8 tiles
)

# do the conversion
# `data` is now a string containing raw pixel data
# `conf.pal` will be populated with all the colors in the image
let data = pngToBin("mario.png", conf, buildPal=true)

# output to files
writeFile("mario.img.bin", data)
writePal("mario.pal.bin", conf.pal)
```

### Binary to PNG

The inverse of the above process. This may be useful for rom hacking, validation etc.

```nim
let conf = GfxInfo(
  pal: readPal("mario.pal.bin"),
  bpp: gfx4bpp,       # bit depth
  layout: gfxTiles,   # unscramble from tile arrangement
)
let data = readFile("mario.img.bin")
let png = binToPng(data, conf)
writeFile("mario_out.png", png)
```

### PNG to tileset + tilemap + palettes

The typical use case here is to take an image of your whole level and transform it into a tile map. Under the hood this involves both tileset reduction and palette reduction.

```nim
let bg4 = loadBg4("brinstar.png")
writeFile("brinstar.map.bin", toBytes(bg4.map))
writeFile("brinstar.img.bin", toBytes(bg4.img))
writeFile("brinstar.pal.bin", toBytes(joinPalettes(bg4.pals)))
```

### Data to C

While the above examples use `.bin` files, the preferred way to embed read-only data in your Nim GBA games is by using extenal C files. 

Example:

```nim
let data = readFile("mario.img.bin")

# convert binary data to a C string literal
let imgStringLit = makeCString(data)

# output C source code
writeFile("source/gfxdata.c", fmt"""
const char *marioImg = {imgStringLit};
""")

# output Nim source code
writeFile("source/gfxdata.nim", fmt"""
{{.compile: "gfxdata.c".}}
var marioImg* {{.importc, extern:"marioImg", codegenDecl:"const $# $#".}}: array[{data.len}, uint8]
""")
```

To explain the generated Nim code: the [`{.compile.}`][1] pragma ensures that `gfxdata.c` is compiled and linked into the final ROM. The [`{.importc.}`][2] and [`{.extern.}`][3] pragmas are used to make the C variable accessible to Nim. [`{.codegenDecl.}`][4] is just to help avoid compiler warnings.

It's worth mentioning that this Nim code *could* be written by hand, but I recommend this approach to maintain integrity between the assets and the game code. It will also save a lot of work once you modify your tool to support multiple images, by using a config file or by processing all images in a certain folder, etc.

[1]: https://nim-lang.org/docs/manual.html#implementation-specific-pragmas-compile-pragma
[2]: https://nim-lang.org/docs/manual.html#foreign-function-interface-importc-pragma
[3]: https://nim-lang.org/docs/manual.html#foreign-function-interface-extern-pragma
[4]: https://nim-lang.org/docs/manual.html#implementation-specific-pragmas-codegendecl-pragma


Example of using data in your game code:

```nim
import natu, gfxdata

# copy the image data into VRAM
memcpy32(addr tileMemObj[0], addr marioImg, marioImg.len div sizeof(uint32))
```


### Soundbank conversion

Create a soundbank using `mmutil`. The constants are converted to Nim and the data is converted to C.

```nim
let soundFiles = ["audio/mysong.xm", "audio/jump.wav"]
makeSoundbank("source/soundbank.nim", "data/soundbank.c", soundFiles)
```

Or convert all files in a directory:

```nim
makeSoundbank("source/soundbank.nim", "data/soundbank.c", "audio/*")
```

---

## Todo

- Fonts (currently the only way to produce [TTE](https://www.coranac.com/tonc/text/tte.htm) compatible fonts is [Usenti](http://www.coranac.com/projects/usenti/))

- Ability to convert backgrounds/tilemaps back into PNG

- 8bpp backgrounds, Affine backgrounds

- More graphic formats (in particular, NDS 3D texture formats with alpha bits have been implemented by [MyLegGuy](https://github.com/MyLegGuy) for PP20th, but I've yet to merge this code)

- Metatiles? Currently, sprite sheets must be supplied as a vertical strip (i.e. 1 frame wide, N frames tall). This is maybe unconventional, but an advantage is you can guarantee no space in the spritesheet is wasted.

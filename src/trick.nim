##[

.. include:: trick/doc/styles.rst

Trick is a library for GBA image conversion and more.

```nim
import trick                       # import everything
import trick/[common, gfxconvert]  # import individual modules
```

See below for an API overview of each module.


common
------

This module contains some general utilitites for working with data.

`Go to full docs ⇒<trick/common.html>`_

.. raw:: html
  <h4>Types</h4>

==========================================  =============  =====================================================
Name                                        Type           Summary
==========================================  =============  =====================================================
`View[T]<trick/common.html#View>`_          object         Allows you to treat arbitrary memory like an array of some type, without copying.
==========================================  =============  =====================================================

.. raw:: html
  <h4>Procedures</h4>

========================================================  ============================  =============  =================================
Name                                                      Parameters                    Returns        Summary
========================================================  ============================  =============  =================================
`viewSeq<trick/common.html#viewSeq,seq[T][T]>`_           seq[T]                        View[T]        Interpret a sequence as a view
`viewSeqAs<trick/common.html#viewSeqAs,seq[T][B]>`_       seq[A]                        View[B]        Interpret a sequence as a view of a different type
`viewBytesAs<trick/common.html#viewBytesAs,string>`_      string                        View[T]        Interpret a string of binary data as a view of some type
`toSeq<trick/common.html#toSeq,View[T]>`_                 View[T]                       seq[T]         Convert a view to a sequence
`toBytes<trick/common.html#toBytes,View[T]>`_             View[T]                       string         Convert a view to binary data
`toBytes<trick/common.html#toBytes,seq[T][T]>`_           seq[T]                        string         Convert a sequence to binary data
`makeCString<trick/common.html#makeCString,string>`_      string                        string         Convert a string of binary data to an escaped C string literal
`toCamelCase<trick/common.html#toCamelCase,string>`_      *name*, *firstUpper=false*    string         Convert a string from snake_case to camelCase
`fileToVarName<trick/common.html#fileToVarName,string>`_  *name*, *firstUpper=false*    string         Convert a filename to a variable name
========================================================  ============================  =============  =================================


gfxconvert
----------

Types and procedures to convert between PNG and raw binary image/palette data.

For reading and writing PNGs, Trick uses the `nimPNG<https://github.com/jangko/nimPNG>`_
library by jangko.

`Go to full docs ⇒<trick/gfxconvert.html>`_

.. raw:: html
  <h4>Types</h4>

================================================  =============  =====================================================
Name                                              Type           Summary
================================================  =============  =====================================================
`GfxInfo<trick/gfxconvert.html#GfxInfo>`_         object         Configuration object to encode/decode an image
`GfxColor<trick/gfxconvert.html#GfxColor>`_       uint16         15-bit BGR color 
`GfxPalette<trick/gfxconvert.html#GfxPalette>`_   seq[GfxColor]  List of colors
`GfxBpp<trick/gfxconvert.html#GfxBpp>`_           enum           Bits per pixel specifier
`GfxLayout<trick/gfxconvert.html#GfxLayout>`_     enum           Whether the image is arranged into 8x8 tiles
================================================  =============  =====================================================

.. raw:: html
  <h4>Constants</h4>

===========================================  =============  =====================================================
Name                                         Type           Summary
===========================================  =============  =====================================================
`clrEmpty<trick/gfxconvert.html#clrEmpty>`_  GfxColor       Special 'transparent' color
===========================================  =============  =====================================================

.. raw:: html
  <h4>Procedures</h4>

=================================================================  ================================  ===============  ==============================================
Name                                                               Parameters                        Returns          Summary
=================================================================  ================================  ===============  ==============================================
`binToPng<trick/gfxconvert.html#binToPng,string,GfxInfo>`_         *data*, *conf*                    PNG              Convert raw GBA/NDS image data to a `PNG<https://github.com/jangko/nimPNG>`_ object
`writeFile<trick/gfxconvert.html#writeFile,string,PNG>`_           *filename*, *png*                                  Write a PNG object to a file
`pngToBin<trick/gfxconvert.html#pngToBin,string,GfxInfo,bool>`_    *filename*, *conf*, *buildPal*    string           Load a PNG and convert to GBA/NDS image data
`readPal<trick/gfxconvert.html#readPal,string>`_                   *filename*                        GfxPalette       Read a palette from a binary file
`writePal<trick/gfxconvert.html#writePal,string,GfxPalette>`_      *filename*, *pal*                                  Write a palette to a binary file
`rgb5<trick/gfxconvert.html#rgb5,int,int,int>`_                    *r*, *g*, *b*                     GfxColor         Create a color using 5-bit components
`rgb8<trick/gfxconvert.html#rgb8,int,int,int>`_                    *r*, *g*, *b*                     GfxColor         Create a color using 8-bit components
`rgb8<trick/gfxconvert.html#rgb8,int>`_                            *hex*                             GfxColor         Create a color using an 0xRRGGBB value
`swap4bpp<trick/gfxconvert.html#swap4bpp,uint8>`_                  *ab*                              *ba*             Swap the low and high nybbles within a byte
`swap2bpp<trick/gfxconvert.html#swap2bpp,uint8>`_                  *abcd*                            *dcba*           Swap the four pairs of bits within a byte
=================================================================  ================================  ===============  ==============================================

.. raw:: html
  <h4>Iterators</h4>

=================================================================  ===========================  =========================  =================================
Name                                                               Parameters                   Returns                    Summary
=================================================================  ===========================  =========================  =================================
`tileEncode<trick/gfxconvert.html#tileEncode.i,int,int,int,int>`_  *width*, *height*, *bpp=8*   (*srcIndex*, *destIndex*)  Unravel a tiled space into a bitmap space or vice versa
=================================================================  ===========================  =========================  =================================


bgconvert
---------

Procedures for working with tiled backgrounds.

`Go to full docs ⇒<trick/bgconvert.html>`_

.. raw:: html
  <h4>Types</h4>

================================================  ======================  =====================================================
Name                                              Type                    Summary
================================================  ======================  =====================================================
`Tile4<trick/bgconvert.html#Tile4>`_              array[32, uint8]        8x8 pixels at 4bpp (paletted)
`Tile8<trick/bgconvert.html#Tile8>`_              array[64, uint8]        8x8 pixels at 8bpp (paletted)
`Tile16<trick/bgconvert.html#Tile16>`_            array[32, GfxColor]     8x8 pixels at 15bpp
`SomeTile<trick/bgconvert.html#SomeTile>`_        Tile4 | Tile8 | Tile16  Typeclass for any kind of tile
`ScrEntry<trick/bgconvert.html#ScrEntry>`_        distinct uint16         Tile index with palette and flipping flags (via getters/setters)
`Screenblock<trick/bgconvert.html#Screenblock>`_  array[1024, ScrEntry]   A block of 32x32 screen entries
`Bg4<trick/bgconvert.html#Bg4>`_                  object                  4bpp tiled background with a list of 16-color palettes
`Bg8<trick/bgconvert.html#Bg8>`_                  object                  8bpp tiled background with a single 256-color palette
`Bg16<trick/bgconvert.html#Bg16>`_                object                  15bpp direct-color tiled background (used for processing/conversion)
`BgAff<trick/bgconvert.html#BgAff>`_              object                  8bpp affine tiled background
================================================  ======================  =====================================================

.. raw:: html
  <h4>Procedures</h4>

========================================================================  ===================  =================  =================================
Name                                                                      Parameters           Returns            Summary
========================================================================  ===================  =================  =================================
`loadBg4<trick/bgconvert.html#loadBg4,string>`_                           *filename*           Bg4                Load a PNG as a 4bpp tiled background
`loadBg8<trick/bgconvert.html#loadBg8,string>`_                           *filename*           Bg8                Load a PNG as a 8bpp tiled background
`loadBg16<trick/bgconvert.html#loadBg16,string>`_                         *filename*           Bg16               Load a PNG as a 15bpp (direct color) tiled background
`loadBgAff<trick/bgconvert.html#loadBgAff,string>`_                       *filename*           BgAff              Load a PNG as an affine background
`toBg4<trick/bgconvert.html#toBg4,Bg8>`_                                  Bg8                  Bg4                Convert a 8bpp background to 4bpp with strict rules
`toBg4<trick/bgconvert.html#toBg4,Bg16>`_                                 Bg16                 Bg4                Convert a 15bpp (direct color) background to 4bpp (paletted)
`toBg8<trick/bgconvert.html#toBg8,Bg16>`_                                 Bg16                 Bg8                Convert a 15bpp (direct color) background to 8bpp (paletted)
`toBgAff<trick/bgconvert.html#toBgAff,Bg16>`_                             Bg16                 BgAff              Convert a 15bpp (direct color) background to affine
`reduce<trick/bgconvert.html#reduce,seq[T]>`_                             *tiles*              (*tiles*, *map*)   Remove duplicates from a list of tiles and build a tile map
`reduceAff<trick/bgconvert.html#reduceAff,seq[T]>`_                       *tiles*              (*tiles*, *map*)   Remove duplicates from a list of tiles and build an affine map
`getPalettesFromTiles<trick/bgconvert.html#getPalettesFromTiles>`_        *tiles16*            seq[IntSet]        Get a list of palettes from a list of 15bpp tiles
`toScreenBlocks<trick/bgconvert.html#toScreenBlocks,seq[ScrEntry],int>`_  *map*, *w*           seq[Screenblock]   Arrange a map into screenblocks (chunks of 32x32 tiles)
`flipX<trick/bgconvert.html#flipX,T>`_                                    *tile*               *tile*             Flip a tile horizontally
`flipY<trick/bgconvert.html#flipY,T>`_                                    *tile*               *tile*             Flip a tile vertically
`clear<trick/bgconvert.html#clear>`_                                      *tile*                                  Erase all pixels in a tile
========================================================================  ===================  =================  =================================


palbuilder
----------

This module implements a palette reduction algorithm: Given a list of palettes (of which
many are duplicates or at least have colors in common), it attempts to merge them down
into a reduced list of palettes.

This also produces a list of indexes, mapping palettes from the old list to the new list.

Note: Throughout this module, `IntSet<https://nim-lang.org/docs/intsets.html>`_ is
used in place of GfxPalette, for performance reasons.

`Go to full docs ⇒<trick/palbuilder.html>`_

.. raw:: html
  <h4>Procedures</h4>

=======================================================================  ===============  ===========================  ====================================================
Name                                                                     Parameters       Returns                      Summary
=======================================================================  ===============  ===========================  ====================================================
`reducePalettes<trick/palbuilder.html#reducePalettes,seq[IntSet]>`_      seq[IntSet]      (seq[GfxPalette], seq[int])  Try to produce a minimal list of 16-color palettes
`toPalette<trick/palbuilder.html#toPalette,IntSet>`_                     IntSet           GfxPalette                   Convert an IntSet to a list of colors
`toIntSet<trick/palbuilder.html#toIntSet,GfxPalette>`_                   GfxPalette       IntSet                       Convert a list of colors to an IntSet
`joinPalettes<trick/palbuilder.html#joinPalettes,seq[GfxPalette]>`_      seq[GfxPalette]  GfxPalette                   Concatenate several palettes into one (with padding)
=======================================================================  ===============  ===========================  ====================================================

]##

import trick/[common, gfxconvert, bgconvert, palbuilder, mmutil, compress]

export common, gfxconvert, bgconvert, palbuilder, mmutil, compress

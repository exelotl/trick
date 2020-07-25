# Changelog

## [Unreleased]

- Added `Bg8` type for 8bpp paletted backgrounds
- Added `toBg8(bg16)` for direct color to 8bpp paletted conversion
- Added `loadBg8(filepath)` which supports indexed PNGs
  - This allows you to preserve the existing palette when loading an image.
- Added `indexed` parameter to `loadBg4`
  - This provides a stricter way of loading 4bpp backgrounds, expecting a well-formed palette rather than deducing the palettes using `palbuilder`.
- Added `readPng(filepath)` as an easy way to get a useful `nimpng.PNG` object

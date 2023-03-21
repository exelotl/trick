
const rleHeaderTag = 0x30

func createHeader(tag: uint8, size: Natural): array[4, char] =
  let s = size.uint
  result[0] = cast[char](tag)
  result[1] = cast[char]((s) and 255)
  result[2] = cast[char]((s shr 8) and 255)
  result[3] = cast[char]((s shr 16) and 255)

func rleCompress*(src: string): string =
  
  var
    curr: uint
    prev = cast[uint](src[0])
    run = 1'u  # counts a run of repeating bytes
    non = 1'u  # counts stretch of non-repeating bytes
  
  let header = createHeader(rleHeaderTag, src.len)
  result.add header[0]
  result.add header[1]
  result.add header[2]
  result.add header[3]
  
  for i in 1..src.len:
    
    if i != src.len:
      curr = cast[uint](src[i])
    
    if run == 0x82 or i == src.len:
      prev = not curr
    
    if run < 3 and (non+run > 0x80 or i == src.len):
      non += run
      result.add cast[char](non-2)
      result.add src[(i-cast[int](non)+1) ..< i]
      run = 1'u
      non = 1'u
    elif curr == prev:
      inc run
      if run == 3 and non > 1:
        result.add cast[char](non-2)
        result.add src[(i-cast[int](non)-1) ..< (i-2)]
        non = 1'u
    else:
      if run >= 3:
        result.add cast[char](0x80'u or (run - 3))
        result.add src[i-1]
        non = 0
        run = 1
      non += run
      run = 1
    
    prev = curr
  
  # pad output
  while (result.len mod 4) != 0:
    result.add '\0'

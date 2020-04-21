##[
.. include:: doc/styles.rst
`↩ back to overview<../trick.html>`_
]##

import os

# Array Views
# -----------

type
  View*[T] = object
    ## A simpler version of View from `zielmicha/collections.nim<https://github.com/zielmicha/collections.nim>`_
    ##
    ## Allows you to treat arbitrary memory like an array of some type, without copying.
    ##
    ## *Not GC safe!* Do not attempt to use this after the original data has gone out of scope or otherwise been deallocated.
    ##
    len: int
    data: ptr UncheckedArray[T]

proc `[]`*[T](a: View[T], i: int): var T =
  ## Retrieve an element from the View by index.
  assert(i >= 0 and i < a.len)
  a.data[i]

proc `[]=`*[T](a: View[T], i: int, val: T) =
  ## Assign an element in the View by index.
  assert(i >= 0 and i < a.len)
  a.data[i] = val

iterator items*[T](a: View[T]): T =
  ## Iterate over the content of a View.
  for i in 0..<a.len:
    yield a.data[i]

proc viewSeq*[T](s: var seq[T]): View[T] =
  ## Interpret a sequence as a View of the same type.
  result.len = s.len
  result.data = cast[ptr UncheckedArray[T]](addr s[0])

proc viewSeqAs*[A,B](s: var seq[B]): View[A] =
  ## Interpret a sequence of some type as a View of some other type.
  result.len = (s.len * sizeof(B)) div sizeof(A)
  result.data = cast[ptr UncheckedArray[A]](addr s[0])
  
proc viewBytesAs*[T](data: var string): View[T] =
  ## Interpret a string of bytes as a View of a given type.
  ## This may be handy for working with data of a known binary format.
  assert(data.len mod sizeof(T) == 0, "Data length must be a multiple of the desired View type")
  result.len = data.len div sizeof(T)
  result.data = cast[ptr UncheckedArray[T]](addr data[0])

proc toSeq*[T](a: View[T]): seq[T] =
  ## Copy all the elements of a View into a new sequence.
  result.newSeq(a.len)
  for i,v in a:
    result[i] = v

proc toBytes*[T](a: View[T]): string =
  ## Returns a new string containing the raw data of a View.
  result = newString(a.len * sizeof(T))
  copyMem(result, a.data, result.len)

proc toBytes*[T](s: seq[T]): string =
  ## Convert a sequence to a string of bytes.
  result = newString(s.len * sizeof(T))
  copyMem(addr result[0], unsafeAddr s[0], result.len)


# C Strings
# ---------

import strutils, ropes

proc toCChar(c: char; result: var string) =
  case c
  of '\0'..'\x1F', '\x7F'..'\xFF':
    result.add '\\'
    result.add toOctal(c)
  of '\'', '\"', '\\', '?':
    result.add '\\'
    result.add c
  else:
    result.add c

proc makeCString*(data: string): Rope =
  ## Convert binary data into an escaped C string literal.
  ##
  ## This is a utility function borrowed from the Nim compiler.
  ##
  const MaxLineLength = 64
  result = nil
  var res = newStringOfCap(int(data.len.toFloat * 1.1) + 1)
  add(res, "\"")
  for i in 0 ..< len(data):
    if (i + 1) mod MaxLineLength == 0:
      add(res, "\"\L\"")
    toCChar(data[i], res)
  add(res, '\"')
  add(result, rope(res))

export ropes.`$`


func toCamelCase*(str: string, firstUpper = false): string =
  ## Convert a string from `snake_case` to `camelCase`.
  ##
  ## ```nim
  ## echo "foo_bar".toCamelCase()   # fooBar
  ## ```
  ##
  ## If `first` is true, the first character will be capitalized.
  ##
  ## ```nim
  ## echo "foo_bar".toCamelCase(true)   # FooBar
  ## ```
  ##
  ## Note: Uppercase characters in the input will not be changed.
  ## A name in all-caps should first be converted to lowercase like so:
  ##
  ## ```nim
  ## echo "SFX_JUMP".toLowerAscii().toCamelCase() == "sfxJump"
  ## ```
  ##
  var makeUpper = firstUpper
  for i, c in str:
    if c == '_':
      makeUpper = true
    elif makeUpper:
      result.add(c.toUpperAscii())
      makeUpper = false
    else:
      result.add(c)


proc fileToVarName*(name: string, firstUpper = false): string =
  result = splitFile(name)[1]
  # replace non-alphanumeric chars with '_'
  for c in mitems(result):
    if (c notin 'A'..'Z') and (c notin 'a'..'z') and (c notin '0'..'9'):
      c = '_'
  result = result.toCamelCase(firstUpper)

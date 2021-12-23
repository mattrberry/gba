import strutils

import types

proc newTimer*(gba: GBA): Timer =
  new result
  result.gba = gba

proc `[]`*(timer: Timer, address: SomeInteger): uint8 =
  echo "Unmapped Timer read: " & address.toHex(8)
  0

proc `[]=`*(timer: Timer, address: SomeInteger, value: uint8) =
  echo "Unmapped Timer write: ", address.toHex(8), " = ", value.toHex(2)

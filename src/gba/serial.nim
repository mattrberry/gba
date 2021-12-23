import strutils

import types

proc newSerial*(gba: GBA): Serial =
  new result
  result.gba = gba

proc `[]`*(serial: Serial, address: SomeInteger): uint8 =
  echo "Unmapped Serial read: " & address.toHex(8)
  0

proc `[]=`*(serial: Serial, address: SomeInteger, value: uint8) =
  echo "Unmapped Serial write: ", address.toHex(8), " = ", value.toHex(2)

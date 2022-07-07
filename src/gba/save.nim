import types

proc newSave*(gba: GBA): Save =
  new result
  result.gba = gba

proc `[]`*(save: Save, address: SomeInteger): uint8 =
  # echo "Unmapped Save read: ", address.toHex(8)
  0

proc `[]=`*(save: Save, address: SomeInteger, value: uint8) =
  # echo "Unmapped Save write: ", address.toHex(8), " = ", value.toHex(2)
  discard

import types

proc newBus*(gba: GBA, bios: openarray[byte]): Bus =
  new result
  result.gba = gba
  for i in 0 ..< bios.len:
    result.bios[i] = bios[i]

proc `[]`(index: int): uint8 =
  discard



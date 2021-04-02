import strutils

import types, ppu

proc newMMIO*(gba: GBA): MMIO =
  new result
  result.gba = gba

proc `[]`*(mmio: MMIO, address: SomeInteger): uint8 =
  case address
  of 0x000..0x056: result = mmio.gba.ppu[address]
  else: quit "Unmapped MMIO read from 0x" & address.toHex(8)

proc `[]=`*(mmio: MMIO, address: SomeInteger, value: uint8) =
  case address
  of 0x000..0x056: mmio.gba.ppu[address] = value
  else: echo "Unmapped MMIO write to 0x" & address.toHex(8) & ": " & value.toHex(2)
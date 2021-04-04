import strutils

import types, keypad, ppu

proc newMMIO*(gba: GBA): MMIO =
  new result
  result.gba = gba

proc `[]`*(mmio: MMIO, address: SomeInteger): uint8 =
  case address
  of 0x000..0x055: result = mmio.gba.ppu[address and 0xFFF]
  of 0x130..0x133: result = mmio.gba.keypad[address and 0xFFF]
  else: quit "Unmapped MMIO read from 0x" & address.toHex(8)

proc `[]=`*(mmio: MMIO, address: SomeInteger, value: uint8) =
  case address
  of 0x000..0x055: mmio.gba.ppu[address] = value
  of 0x130..0x133: mmio.gba.keypad[address] = value
  else: echo "Unmapped MMIO write to 0x" & address.toHex(8) & ": " & value.toHex(2)

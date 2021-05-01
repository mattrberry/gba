import strutils

import types, keypad, ppu, regs

var
  waitcnt: WAITCNT

proc newMMIO*(gba: GBA): MMIO =
  new result
  result.gba = gba

proc `[]`*(mmio: MMIO, address: SomeInteger): uint8 =
  case address
  of 0x000..0x055: mmio.gba.ppu[address and 0xFFF]
  of 0x130..0x133: mmio.gba.keypad[address and 0xFFF]
  of 0x204..0x205: read(waitcnt, address and 1)
  else: quit "Unmapped MMIO read from 0x" & address.toHex(8)

proc `[]=`*(mmio: MMIO, address: SomeInteger, value: uint8) =
  case address
  of 0x000..0x055: mmio.gba.ppu[address] = value
  of 0x130..0x133: mmio.gba.keypad[address] = value
  of 0x204..0x205: write(waitcnt, value, address and 1)
  else: echo "Unmapped MMIO write to 0x" & address.toHex(8) & ": " & value.toHex(2)

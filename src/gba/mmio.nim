import strutils

import types, interrupts, keypad, ppu, regs

var
  waitcnt: WAITCNT

proc newMMIO*(gba: GBA): MMIO =
  new result
  result.gba = gba

proc `[]`*(mmio: MMIO, address: SomeInteger): uint8 =
  case address
  of 0x000..0x055: mmio.gba.ppu[address]
  of 0x130..0x133: mmio.gba.keypad[address]
  of 0x200..0x203: mmio.gba.interrupts[address]
  of 0x204..0x205: read(waitcnt, address and 1)
  of 0x208..0x209: mmio.gba.interrupts[address]
  else: quit "Unmapped MMIO read from 0x" & address.toHex(8)

proc `[]=`*(mmio: MMIO, address: SomeInteger, value: uint8) =
  case address
  of 0x000..0x055: mmio.gba.ppu[address] = value
  of 0x130..0x133: mmio.gba.keypad[address] = value
  of 0x200..0x203: mmio.gba.interrupts[address] = value
  of 0x204..0x205: write(waitcnt, value, address and 1)
  of 0x208..0x209: mmio.gba.interrupts[address] = value
  else: echo "Unmapped MMIO write to 0x" & address.toHex(8) & ": " & value.toHex(2)

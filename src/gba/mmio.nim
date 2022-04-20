import types, ppu, apu, dma, timer, serial, keypad, interrupts, regs

var
  waitcnt: WAITCNT

proc newMMIO*(gba: GBA): MMIO =
  new result
  result.gba = gba

proc `[]`*(mmio: MMIO, address: SomeInteger): uint8 =
  case address
  of 0x000..0x055: mmio.gba.ppu[address]
  of 0x060..0x0A7: mmio.gba.apu[address]
  of 0x0B0..0x0DF: mmio.gba.dma[address]
  of 0x100..0x10F: mmio.gba.timer[address]
  of 0x120..0x12B: mmio.gba.serial[address]
  of 0x130..0x133: mmio.gba.keypad[address]
  of 0x134..0x159: mmio.gba.serial[address]
  of 0x200..0x203: mmio.gba.interrupts[address]
  of 0x204..0x205: read(waitcnt, address and 1)
  of 0x208..0x209: mmio.gba.interrupts[address]
  of 0x300: 0 # postflg
  of 0x301: 0 # haltcnt (write-only)
  of 0x800..0x803: 0 # internal memory control
  else: 0 # todo: open bus

proc `[]=`*(mmio: MMIO, address: SomeInteger, value: uint8) =
  case address
  of 0x000..0x055: mmio.gba.ppu[address] = value
  of 0x060..0x0A7: mmio.gba.apu[address] = value
  of 0x0B0..0x0DF: mmio.gba.dma[address] = value
  of 0x100..0x10F: mmio.gba.timer[address] = value
  of 0x120..0x12B: mmio.gba.serial[address] = value
  of 0x130..0x133: mmio.gba.keypad[address] = value
  of 0x134..0x159: mmio.gba.serial[address] = value
  of 0x200..0x203: mmio.gba.interrupts[address] = value
  of 0x204..0x205: write(waitcnt, value, address and 1)
  of 0x208..0x209: mmio.gba.interrupts[address] = value
  of 0x300: discard # postflg
  of 0x301:
    if value.bit(7): mmio.gba.cpu.halted = true
  of 0x800..0x803: discard # internal memory control
  else: discard

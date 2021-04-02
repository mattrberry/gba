import strutils

import types, display, scheduler

type
  DISPCNT = object
    mode {.bitsize:3.}: cuint
    cgbMode {.bitsize:1.}: bool
    page {.bitsize:1.}: bool
    hblankOam {.bitsize:1.}: bool
    obj1d {.bitsize:1.}: bool
    forceBlank {.bitsize:1.}: bool
    controlBits {.bitsize:5.}: cuint
    window0 {.bitsize:1.}: bool
    window1 {.bitsize:1.}: bool
    windowObj {.bitsize:1.}: bool

  DISPSTAT = object
    vblank {.bitsize:1.}: bool
    hblank {.bitsize:1.}: bool
    vcount {.bitsize:1.}: bool
    vblankEnable {.bitsize:1.}: bool
    hblankEnable {.bitsize:1.}: bool
    vcountEnable {.bitsize:1.}: bool
    notUsed {.bitsize:2.}: cuint
    vcountTarget {.bitsize:8.}: cuint

  Reg16 = DISPCNT | DISPSTAT

converter toU16(reg: Reg16): uint16 = cast[uint16](reg)
converter toReg16[T: Reg16](num: uint16): T = cast[T](num)
proc put(reg: var Reg16, b: uint16) {.inline.} = reg = b.toReg16[: reg.type]

var
  dispcnt: DISPCNT
  dispstat: DISPSTAT
  vcount: uint8

proc read(reg: Reg16, byteNum: SomeInteger): uint8 =
  result = uint8((toU16(reg) shr (8 * byteNum)) and 0xFF)

proc write(reg: var Reg16, value: uint8, byteNum: SomeInteger) =
  let
    shift = 8 * byteNum
    mask = not(0xFF'u16 shl shift)
  reg.put ((mask and toU16(reg)) or (value shl shift))

proc startLine(ppu: PPU): proc()
proc startHblank(ppu: PPU): proc()
proc endHblank(ppu: PPU): proc()

proc newPPU*(gba: GBA): PPU =
  new result
  result.gba = gba
  result.startLine()()

proc draw(ppu: PPU) =
  for row in 0 ..< 160:
    for col in 0 ..< 240:
      ppu.framebuffer[row * 240 + col] = (cast[ptr array[0x9600, uint16]](addr ppu.vram))[row * 240 + col]
  ppu.gba.display.draw(ppu.framebuffer)

proc startLine(ppu: PPU): proc() = (proc() =
  ppu.gba.scheduler.schedule(960, startHblank(ppu), EventType.ppu))

proc startHblank(ppu: PPU): proc() = (proc() =
  dispstat.hblank = true
  ppu.gba.scheduler.schedule(272, endHblank(ppu), EventType.ppu))

proc endHblank(ppu: PPU): proc() = (proc() =
  dispstat.hblank = false
  vcount = (vcount + 1) mod 228
  dispstat.vcount = dispstat.vcountTarget == vcount
  if vcount == 0:
    dispstat.vblank = false
  elif vcount == 160:
    dispstat.vblank = true
    ppu.draw()
  ppu.gba.scheduler.schedule(0, startLine(ppu), EventType.ppu))

proc `[]`*(ppu: PPU, address: SomeInteger): uint8 =
  result = case address and 0xFF:
    of 0x00..0x01: read(dispcnt, address and 1)
    of 0x04..0x05: read(dispstat, address and 1)
    else: quit "Unmapped PPU read: " & address.toHex(4)

proc `[]=`*(ppu: PPU, address: SomeInteger, value: uint8) =
  case address and 0xFF:
  of 0x00..0x01: write(dispcnt, value, address and 1)
  of 0x04..0x05: write(dispstat, value, address and 1)
  else: echo "Unmapped PPU write: ", address.toHex(4), " -> ", value.toHex(2)

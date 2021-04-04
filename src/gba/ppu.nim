import strutils

import types, display, regs, scheduler

var
  dispcnt: DISPCNT
  dispstat: DISPSTAT
  vcount: uint8

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
  result = case address:
    of 0x00..0x01: read(dispcnt, address and 1)
    of 0x04..0x05: read(dispstat, address and 1)
    else: quit "Unmapped PPU read: " & address.toHex(4)

proc `[]=`*(ppu: PPU, address: SomeInteger, value: uint8) =
  case address:
  of 0x00..0x01: write(dispcnt, value, address and 1)
  of 0x04..0x05: write(dispstat, value, address and 1)
  else: echo "Unmapped PPU write: ", address.toHex(4), " -> ", value.toHex(2)

import types

import display, scheduler

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
  ppu.gba.scheduler.schedule(272, endHblank(ppu), EventType.ppu))

proc endHblank(ppu: PPU): proc() = (proc() =
  ppu.vcount = (ppu.vcount + 1) mod 228
  if ppu.vcount == 0:
    discard
  elif ppu.vcount == 160:
    ppu.draw()
  ppu.gba.scheduler.schedule(0, startLine(ppu), EventType.ppu))

import os
import sdl2

import gba/[bus, cpu, display, ppu, scheduler, types]

if paramCount() != 2:
  quit "Run with ./gba /path/to/bios /path/to/rom"

proc newGBA(bios, rom: string): GBA =
  new result
  result.scheduler = newScheduler()
  result.bus = newBus(result, bios, rom)
  result.display = newDisplay()
  result.cpu = newCPU(result)
  result.ppu = newPPU(result)

discard sdl2.init(INIT_EVERYTHING)

var
  gba = newGBA(paramStr(1), paramStr(2))

while true:
  gba.cpu.tick()
  gba.scheduler.tick(1)

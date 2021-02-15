import os

import gba/[bus, cpu, types]

if paramCount() != 2:
  echo("Run with ./gba /path/to/bios /path/to/rom")
  quit(1)

proc newGBA(bios, rom: string): GBA =
  new result
  result.bus = newBus(result, bios, rom)
  result.cpu = newCPU(result)

var
  gba = newGBA(paramStr(1), paramStr(2))

gba.cpu.tick()
gba.cpu.tick()
gba.cpu.tick()
gba.cpu.tick()
gba.cpu.tick()
gba.cpu.tick()
gba.cpu.tick()

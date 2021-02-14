import os, sequtils

import gba/[bus, cpu, types]

if paramCount() != 2:
  echo("Run with ./gba /path/to/bios /path/to/rom")
  quit(1)

proc readFileAsBytes(path: string): seq[uint8] =
  var file = open(path)
  result = newSeqWith(int(file.getFileSize()), 0'u8)
  discard readBytes(file, result, 0, file.getFileSize())

var
  bios = readFileAsBytes(paramStr(1))
  rom = readFileAsBytes(paramStr(2))

var
  gba = new GBA
  busObj = newBus(gba, bios)
  cpuObj = newCPU(gba)

cpuObj.run()

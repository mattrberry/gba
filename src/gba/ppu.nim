import types

proc newPPU*(gba: GBA): PPU =
  new result
  result.gba = gba

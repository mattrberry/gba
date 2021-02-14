import bitops, strutils

import bus, types

proc newCPU*(gba: GBA): CPU =
  new result
  result.gba = gba
  result.r[15] = 0x08000000
  result.r[15] += 8

proc readInstr(cpu: var CPU): Word =
  cpu.r[15].clearMask(3)
  echo "Getting instruction from " & (cpu.r[15] - 8).toHex(8)
  result = cpu.gba.bus.readWord(cpu.r[15] - 8)

proc clearPipeline(cpu: var CPU) =
  cpu.r[15] += 8

proc setReg*(cpu: var CPU, reg: int, value: uint32) =
  cpu.r[reg] = value
  if reg == 15: cpu.clearPipeline

import arm

proc tick*(cpu: var CPU) =
  let instr = cpu.readInstr()
  exec_arm(cpu.gba, instr)

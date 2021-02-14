import bitops

import arm, bus, types

proc newCPU*(gba: GBA): CPU =
  new result
  result.gba = gba
  result.r[15] = 0x08000000
  result.r[15] += 8

proc readInstr(cpu: var CPU): Word =
  cpu.r[15].clearMask(3)
  result = cpu.gba.bus.readWord(cpu.r[15] - 8)

proc tick*(cpu: var CPU) =
  let instr = cpu.readInstr()
  exec_arm(instr)

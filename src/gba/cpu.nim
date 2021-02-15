import bitops, strutils

import bus, types

proc newCPU*(gba: GBA): CPU =
  new result
  result.gba = gba
  result.cpsr = PSR(mode: Mode.usr)
  result.spsr = PSR(mode: Mode.usr)
  result.r[15] = 0x08000000
  result.r[15] += 8

proc readInstr(cpu: var CPU): uint32 =
  if cpu.cpsr.thumb:
    quit "trying to read an instruction in thumb mode"
  else:
    cpu.r[15].clearMask(3)
    result = cpu.gba.bus.readWord(cpu.r[15] - 8)

proc setNegAndZeroFlags*(cpu: var CPU, value: uint32) =
  cpu.cpsr.negative = value.testBit(31)
  cpu.cpsr.zero = value == 0

proc stepArm*(cpu: var CPU) =
  cpu.r[15] += 4

proc stepThumb*(cpu: var CPU) =
  cpu.r[15] += 2

proc clearPipeline(cpu: var CPU) =
  cpu.r[15] += (if cpu.cpsr.thumb: 4 else: 8)

proc setReg*(cpu: var CPU, reg: uint32, value: uint32) =
  cpu.r[reg] = value
  if reg == 15: cpu.clearPipeline

proc ror*(word, bits: uint32, immediate: bool, carry_out: ptr bool): uint32 =
  if bits == 0: # RRX #1
    if not immediate: return word
    quit "rrx immediate"
    # carry_out[] = word.testBit(0)
    # result = (word shr 1) or (@cpsr.carry.to_unsafe shl 31)
  else:
    var bits = bits and 31  # ROR by n where n is greater than 32 will give the same result and carry out as ROR by n-32
    if bits == 0: bits = 32 # ROR by 32 has result equal to Rm, carry out equal to bit 31 of Rm.
    carry_out[] = word.testBit(bits - 1)
    result = (word shr bits) or (word shl (32 - bits))

import arm

proc printState(cpu: CPU, instr: uint32) =
  for reg in 0 ..< cpu.r.len():
    var val = cpu.r[reg]
    if reg == 15: val -= (if cpu.cpsr.thumb: 2 else: 4)
    stdout.write(val.toHex(8) & " ")
  stdout.write("cpsr: " & cast[uint32](cpu.cpsr).toHex(8) & " | ")
  if cpu.cpsr.thumb:
    echo "    " & instr.toHex(4)
  else:
    echo instr.toHex(8)

proc tick*(cpu: var CPU) =
  let instr = cpu.readInstr()
  when defined(trace): printState(cpu, instr)
  exec_arm(cpu.gba, instr)

import bitops, strutils

import bus, types

proc clearPipeline(cpu: var CPU)

proc newCPU*(gba: GBA): CPU =
  new result
  result.gba = gba
  result.cpsr = PSR(mode: Mode.sys)
  result.spsr = PSR(mode: Mode.sys)
  result.r[13] = 0x03007F00
  result.r[15] = 0x08000000
  result.clearPipeline

proc checkCond*(cpu: CPU, cond: uint32): bool =
  result = case cond
    of 0x0: cpu.cpsr.zero
    of 0x1: not(cpu.cpsr.zero)
    of 0x2: cpu.cpsr.carry
    of 0x3: not(cpu.cpsr.carry)
    of 0x4: cpu.cpsr.negative
    of 0x5: not(cpu.cpsr.negative)
    of 0x6: cpu.cpsr.overflow
    of 0x7: not(cpu.cpsr.overflow)
    of 0x8: cpu.cpsr.carry and not(cpu.cpsr.zero)
    of 0x9: not(cpu.cpsr.carry) or cpu.cpsr.zero
    of 0xA: cpu.cpsr.negative == cpu.cpsr.overflow
    of 0xB: cpu.cpsr.negative != cpu.cpsr.overflow
    of 0xC: not(cpu.cpsr.zero) and cpu.cpsr.negative == cpu.cpsr.overflow
    of 0xD: cpu.cpsr.zero or cpu.cpsr.negative != cpu.cpsr.overflow
    of 0xE: true
    else: quit "Cond 0xF is reserved"

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

proc add*(cpu: var CPU, op1, op2: uint32, setCond: bool): uint32 =
  result = op1 + op2
  if setCond:
    setNegAndZeroFlags(cpu, result)
    cpu.cpsr.carry = result < op1
    cpu.cpsr.overflow = not((op1 xor op2) and (op2 xor result)).testBit(31)

proc sub*(cpu: var CPU, op1, op2: uint32, setCond: bool): uint32 =
  result = op1 - op2
  if setCond:
    setNegAndZeroFlags(cpu, result)
    cpu.cpsr.carry = op1 >= op2
    cpu.cpsr.overflow = ((op1 xor op2) and (op1 xor result)).testBit(31)

proc lsl*(word, bits: uint32, carryOut: ptr bool): uint32 =
  if bits == 0: return word
  carryOut[] = word.testBit(32 - bits)
  result = word shl bits

proc ror*(word, bits: uint32, immediate: bool, carryOut: ptr bool): uint32 =
  if bits == 0: # RRX #1
    if not immediate: return word
    result = (word shr 1) or (uint32(carryOut[]) shl 31)
    carryOut[] = word.testBit(0)
  else:
    var bits = bits and 31  # ROR by n where n is greater than 32 will give the same result and carry out as ROR by n-32
    if bits == 0: bits = 32 # ROR by 32 has result equal to Rm, carry out equal to bit 31 of Rm.
    carryOut[] = word.testBit(bits - 1)
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

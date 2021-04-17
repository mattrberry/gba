import algorithm, bitops, strutils

import bus, types, util

proc bank(mode: Mode): int =
  case mode
  of sys, usr: 0
  of fiq: 1
  of svc: 2
  of abt: 3
  of irq: 4
  of und: 5

var bankedRegs: array[6, array[8, uint32]]
for i in 0 ..< 6: bankedRegs[i][7] = PSR(mode: Mode.sys)

proc clearPipeline(cpu: var CPU)

proc newCPU*(gba: GBA): CPU =
  new result
  result.gba = gba
  result.cpsr = PSR(mode: Mode.sys)
  result.spsr = PSR(mode: Mode.sys)
  bankedRegs[Mode.usr.bank][5] = 0x03007F00
  bankedRegs[Mode.irq.bank][5] = 0x03007FA0
  bankedRegs[Mode.svc.bank][5] = 0x03007FE0
  result.r[13] = bankedRegs[Mode.usr.bank][5]
  result.r[15] = 0x08000000
  result.clearPipeline

proc checkCond*(cpu: CPU, cond: uint32): bool =
  case cond
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
    cpu.r[15].clearMask(1)
    result = cpu.gba.bus.read[:uint16](cpu.r[15] - 4).uint32
  else:
    cpu.r[15].clearMask(3)
    result = cpu.gba.bus.read[:uint32](cpu.r[15] - 8)

proc `mode=`*(cpu: CPU, mode: Mode) =
  let
    curMode = cpu.cpsr.mode
    oldBank = curMode.bank
    newBank = mode.bank
  cpu.cpsr.mode = mode
  if oldBank == newBank: return
  if mode == Mode.fiq or curMode == Mode.fiq:
    for i in 0 ..< 5:
      bankedRegs[oldBank][i] = cpu.r[8 + i]
      cpu.r[8 + i] = bankedRegs[newBank][i]
  bankedRegs[oldBank][5] = cpu.r[13]
  bankedRegs[oldBank][6] = cpu.r[14]
  bankedRegs[oldBank][7] = cpu.spsr
  cpu.r[13] = bankedRegs[newBank][5]
  cpu.r[14] = bankedRegs[newBank][6]
  cpu.spsr = bankedRegs[oldBank][7]

proc stepArm*(cpu: var CPU) =
  cpu.r[15] += 4

proc stepThumb*(cpu: var CPU) =
  cpu.r[15] += 2

proc clearPipeline(cpu: var CPU) =
  cpu.r[15] += (if cpu.cpsr.thumb: 4 else: 8)

proc setReg*(cpu: var CPU, reg: SomeInteger, value: uint32) =
  cpu.r[reg] = value
  if reg == 15: cpu.clearPipeline

proc setNegAndZeroFlags*(cpu: var CPU, value: uint32) =
  cpu.cpsr.negative = value.bitTest(31)
  cpu.cpsr.zero = value == 0

proc add*(cpu: var CPU, op1, op2: uint32, setCond: bool): uint32 =
  result = op1 + op2
  if setCond:
    setNegAndZeroFlags(cpu, result)
    cpu.cpsr.carry = result < op1
    cpu.cpsr.overflow = (not(op1 xor op2) and (op2 xor result)).bitTest(31)

proc sub*(cpu: var CPU, op1, op2: uint32, setCond: bool): uint32 =
  result = op1 - op2
  if setCond:
    setNegAndZeroFlags(cpu, result)
    cpu.cpsr.carry = op1 >= op2
    cpu.cpsr.overflow = ((op1 xor op2) and (op1 xor result)).bitTest(31)

proc adc*(cpu: var CPU, op1, op2: uint32, setCond: bool): uint32 =
  result = op1 + op2 + uint32(cpu.cpsr.carry)
  if setCond:
    setNegAndZeroFlags(cpu, result)
    cpu.cpsr.carry = result < uint64(op1) + uint32(cpu.cpsr.carry)
    cpu.cpsr.overflow = (not(op1 xor op2) and (op2 xor result)).bitTest(31)

proc sbc*(cpu: var CPU, op1, op2: uint32, setCond: bool): uint32 =
  result = op1 - op2 + uint32(cpu.cpsr.carry)
  if setCond:
    setNegAndZeroFlags(cpu, result)
    cpu.cpsr.carry = op1 >= uint64(op2) + 1 - uint32(cpu.cpsr.carry)
    cpu.cpsr.overflow = ((op1 xor op2) and (op1 xor result)).bitTest(31)

proc lsl*(word, bits: uint32, carryOut: var bool): uint32 =
  if bits == 0: return word
  carryOut = word.bitTest(32 - bits)
  result = word << bits

proc lsr*[immediate: static bool](word, bits: uint32, carryOut: var bool): uint32 =
  let bits = if bits == 0:
      if not(immediate): return word
      else: 32'u32
    else: bits
  carryOut = word.bitTest(bits - 1)
  result = word >> bits

proc asr*[immediate: static bool](word, bits: uint32, carryOut: var bool): uint32 =
  let bits = if bits == 0:
      if not(immediate): return word
      else: 32'u32
    else: bits
  carryOut = word.bitTest(bits - 1)
  result = (word >> bits) or ((0xFFFFFFFF'u32 * (word shr 31)) shl (32 - bits))

proc ror*[immediate: static bool](word, bits: uint32, carryOut: var bool): uint32 =
  if bits == 0: # RRX #1
    if not(immediate): return word
    result = (word shr 1) or (uint32(carryOut) shl 31)
    carryOut = word.bitTest(0)
  else:
    var bits = bits and 31  # ROR by n where n is greater than 32 will give the same result and carry out as ROR by n-32
    if bits == 0: bits = 32 # ROR by 32 has result equal to Rm, carry out equal to bit 31 of Rm.
    carryOut = word.bitTest(bits - 1)
    result = (word shr bits) or (word shl (32 - bits))

proc shift*[immediate: static bool](shiftType, word, bits: uint32, carryOut: var bool): uint32 =
  case shiftType
  of 0b00: lsl(word, bits, carryOut)
  of 0b01: lsr[immediate](word, bits, carryOut)
  of 0b10: asr[immediate](word, bits, carryOut)
  of 0b11: ror[immediate](word, bits, carryOut)
  else: quit "Invalid shift[" & $immediate & "](" & $shiftType  & "," & word.toHex(8) & "," & $bits & "," & $carryOut & ")"

import arm, thumb

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
  if cpu.cpsr.thumb:
    execThumb(cpu.gba, instr)
  else:
    execArm(cpu.gba, instr)

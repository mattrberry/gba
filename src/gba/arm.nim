import bitops, strformat, strutils, std/macros

import bus, cpu, types, util, macros as m

type
  AluOp = enum
    AND, EOR, SUB, RSB,
    ADD, ADC, SBC, RSC,
    TST, TEQ, CMP, CMN,
    ORR, MOV, BIC, MVN

const
  LogicOps = {AND, EOR, TST, TEQ, ORR, MOV, BIC, MVN}

proc immediateOffset(instr: uint32, carryOut: var bool): uint32 =
  ror[false](instr.bitsliced(0..7), 2 * instr.bitsliced(8..11), carryOut)

proc rotateRegister[immediate: static bool](cpu: CPU, instr: uint32, carryOut: var bool): uint32 =
  let
    reg = instr.bitsliced(0..3)
    shiftType = instr.bitsliced(5..6)
    shiftAmount = if immediate: instr.bitsliced(7..11)
                  else: cpu.r[instr.bitsliced(8..11)] and 0xFF
  result = shift[immediate](shiftType, cpu.r[reg], shiftAmount, carryOut)

proc unimplemented(gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: 0x" & instr.toHex(8)

proc undefined(gba: GBA, instr: uint32) =
  quit "Undefined instruction: 0x" & instr.toHex(8)

proc multiply[accumulate, setCond: static bool](gba: GBA, instr: uint32) =
  let
    rd = instr.bitsliced(16..19)
    rn = instr.bitsliced(12..15)
    rs = instr.bitsliced(8..11)
    rm = instr.bitsliced(0..3)
  var value = gba.cpu.r[rm] * gba.cpu.r[rs]
  when accumulate: value += gba.cpu.r[rn]
  gba.cpu.setReg(rd, value)
  when setCond: setNegAndZeroFlags(gba.cpu, value)
  if rd != 15: gba.cpu.stepArm()

proc multiplyLong[signed, accumulate, setCond: static bool](gba: GBA, instr: uint32) =
  let
    rdhi = instr.bitsliced(16..19)
    rdlo = instr.bitsliced(12..15)
    rs = instr.bitsliced(8..11)
    rm = instr.bitsliced(0..3)
    op1 = cast[uint64](gba.cpu.r[rm])
    op2 = cast[uint64](gba.cpu.r[rs])
  var value = when signed: signExtend(uint64, op1, 31) * signExtend(uint64, op2, 31)
              else: op1 * op2
  when accumulate: value += (cast[uint64](gba.cpu.r[rdhi]) shl 32) or gba.cpu.r[rdlo]
  gba.cpu.setReg(rdhi, cast[uint32](value shr 32))
  gba.cpu.setReg(rdlo, cast[uint32](value))
  when setCond:
    gba.cpu.cpsr.negative = value.bitTest(63)
    gba.cpu.cpsr.zero = value == 0
  if rdhi != 15 and rdlo != 15: gba.cpu.stepArm()

proc singleDataSwap[byte: static bool](gba: GBA, instr: uint32) =
  let
    rn = instr.bitsliced(16..19)
    rd = instr.bitsliced(12..15)
    rm = instr.bitsliced(0..3)
    address = gba.cpu.r[rn]
  if byte: # swpb
    let tmp = gba.bus.read[:uint8](address)
    gba.bus[address] = cast[uint8](gba.cpu.r[rm])
    gba.cpu.setReg(rd, tmp)
  else: # swp
    let tmp = gba.bus.readRotate[:uint32](address)
    gba.bus[address] = gba.cpu.r[rm]
    gba.cpu.setReg(rd, tmp)
  if rd != 15: gba.cpu.stepArm()

proc branchExchange(gba: GBA, instr: uint32) =
  let address = gba.cpu.r[instr.bitsliced(0..3)]
  gba.cpu.cpsr.thumb = bool(address and 1)
  gba.cpu.setReg(15, address)

proc halfwordDataTransfer[pre, add, immediate, writeback, load: static bool, op: static uint32](gba: GBA, instr: uint32) =
  let
    rn = instr.bitsliced(16..19)
    rd = instr.bitsliced(12..15)
    offsetHigh = instr.bitsliced(8..11)
    rm = instr.bitsliced(0..3)
    offset = if immediate: (offsetHigh shl 4) or rm
             else: gba.cpu.r[rm]
  var address = gba.cpu.r[rn]
  if pre:
    if add: address += offset
    else: address -= offset
  case op
  of 0b00: quit fmt"SWP instruction ({instr.toHex(8)})"
  of 0b01: # LDRH / STRH
    if load:
      gba.cpu.setReg(rd, gba.bus.readRotate[:uint16](address))
    else:
      var value = gba.cpu.r[rd]
      # When R15 is the source register (Rd) of a register store (STR) instruction, the stored
      # value will be address of the instruction plus 12.
      if rd == 15: value += 4
      gba.bus[address] = uint16(value and 0xFFFF)
  of 0b10: # LDRSB
    gba.cpu.setReg(rd, signExtend(uint32, gba.bus.read[:uint8](address), 7))
  else: quit fmt"unhandled halfword transfer op: {op}"
  if not pre:
    if add: address += offset
    else: address -= offset
  # Post-index is always a writeback; don't writeback if value is loaded to base
  if (writeback or not(pre)) and not(load and rn == rd): gba.cpu.setReg(rn, address)
  if not(load and rd == 15): gba.cpu.stepArm()

proc singleDataTransfer[immediate, pre, add, byte, writeback, load, bit4: static bool](gba: GBA, instr: uint32) =
  if immediate and bit4: quit "LDR/STR: Cannot shift by a register. TODO: Probably should throw undefined exception"
  var shifterCarryOut = gba.cpu.cpsr.carry
  let
    rn = instr.bitsliced(16..19)
    rd = instr.bitsliced(12..15)
    offset = if immediate: rotateRegister[not(bit4)](gba.cpu, instr.bitsliced(0..11), shifterCarryOut)
             else: instr.bitsliced(0..11)
  var address = gba.cpu.r[rn]
  if pre:
    if add: address += offset
    else: address -= offset
  if load:
    let value = if byte: gba.bus.read[:uint8](address).uint32
                else: gba.bus.readRotate[:uint32](address)
    gba.cpu.setReg(rd, value)
  else:
    var value = gba.cpu.r[rd]
    # When R15 is the source register (Rd) of a register store (STR) instruction, the stored
    # value will be address of the instruction plus 12.
    if rd == 15: value += 4
    if byte: value = uint8(value and 0xFF)
    gba.bus[address] = value
  if not pre:
    if add: address += offset
    else: address -= offset
  # Post-index is always a writeback; don't writeback if value is loaded to base
  if (writeback or not(pre)) and not(load and rn == rd): gba.cpu.setReg(rn, address)
  if rd != 15: gba.cpu.stepArm()

proc blockDataTransfer[pre, add, psrUser, writeback, load: static bool](gba: GBA, instr: uint32) =
  if load and psrUser and instr.bitTest(15): quit fmt"TODO: Implement LDMS w/ r15 in the list ({instr.toHex(8)})"
  let
    rn = instr.bitsliced(16..19)
    currentMode = gba.cpu.cpsr.mode
  if psrUser: gba.cpu.mode = Mode.usr
  var
    firstTransfer = false
    address = gba.cpu.r[rn]
    list = instr.bitsliced(0..15)
    setBits = countSetBits(list)
  if setBits == 0: # odd behavior on empty list, tested in gba-suite
    setBits = 16
    list = 0x8000
  let
    finalAddress = if add: address + uint32(setBits * 4)
                   else: address - uint32(setBits * 4)
  # compensate for direction and pre-increment
  if add and pre: address += 4
  elif not(add):
    address = finalAddress
    if not(pre): address += 4
  for i in 0'u8 .. 15'u8:
    if list.bitTest(i):
      if load:
        gba.cpu.setReg(i, gba.bus.read[:uint32](address))
      else:
        var value = gba.cpu.r[i]
        if i == 15: value += 4
        gba.bus[address] = gba.cpu.r[i]
      address += 4
      if writeback and not(firstTransfer) and not(load and list.bitTest(rn)): gba.cpu.setReg(rn, finalAddress)
      firstTransfer = true
  if psrUser: gba.cpu.mode = currentMode
  if not(load and list.bitTest(15)): gba.cpu.stepArm()

proc branch[link: static bool](gba: GBA, instr: uint32) =
  var offset = instr.bitsliced(0..23)
  if offset.bitTest(23): offset = offset or 0xFF000000'u32
  if link: gba.cpu.setReg(14, gba.cpu.r[15] - 4)
  gba.cpu.setReg(15, gba.cpu.r[15] + offset * 4)

proc softwareInterrupt(gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: SoftwareInterrupt<>(0x" & instr.toHex(8) & ")"

proc statusTransfer[immediate, spsr, msr: static bool](gba: GBA, instr: uint32) =
  let
    rd = instr.bitsliced(12..15)
    mode = gba.cpu.cpsr.mode
    hasSpsr = mode != Mode.sys and mode != Mode.usr
  when msr:
    var mask: uint32
    if instr.bitTest(19): mask = mask or 0xFF000000'u32
    if instr.bitTest(18): mask = mask or 0x00FF0000'u32
    if instr.bitTest(17): mask = mask or 0x0000FF00'u32
    if instr.bitTest(16): mask = mask or 0x000000FF'u32
    var barrelOut: bool
    let value = when immediate: immediateOffset(instr.bitsliced(0..11), barrelOut)
                else: gba.cpu.r[instr.bitsliced(0..3)]
    when spsr:
      if hasSpsr: gba.cpu.spsr = (gba.cpu.spsr and not(mask)) or (value and mask)
    else:
      let thumb = gba.cpu.cpsr.thumb
      if mode == Mode.usr: mask = mask and 0xFF000000'u32
      elif instr.bitTest(16): gba.cpu.mode = Mode(value and 0x1F)
      gba.cpu.cpsr = (gba.cpu.cpsr and not(mask)) or (value and mask)
      gba.cpu.cpsr.thumb = thumb
  else:
    let value = if spsr and hasSpsr: gba.cpu.spsr
                else: gba.cpu.cpsr
    gba.cpu.setReg(rd, value)
  if not(not(msr) and rd == 15): gba.cpu.stepArm()

proc dataProcessing[immediate: static bool, op: static AluOp, setCond, bit4: static bool](gba: GBA, instr: uint32) =
  # The PC value will be the address of the instruction, plus 8 or 12 bytes due to instruction
  # prefetching. If the shift amount is specified in the instruction, the PC will be 8 bytes
  # ahead. If a register is used to specify the shift amount the PC will be 12 bytes ahead.
  const pc12Ahead = not(immediate) and bit4 # todo: make this not suck
  when pc12Ahead: gba.cpu.r[15] += 4
  var shifterCarryOut = gba.cpu.cpsr.carry
  let
    rn = instr.bitsliced(16..19)
    rd = instr.bitsliced(12..15)
    op1 = gba.cpu.r[rn]
    op2 = when immediate: immediateOffset(instr.bitsliced(0..11), shifterCarryOut)
          else: rotateRegister[not(bit4)](gba.cpu, instr.bitsliced(0..11), shifterCarryOut)
  let value = case op
    of AND: op1 and op2
    of EOR: op1 xor op2
    of SUB: gba.cpu.sub(op1, op2, setCond)
    of RSB: gba.cpu.sub(op2, op1, setCond)
    of ADD: gba.cpu.add(op1, op2, setCond)
    of ADC: gba.cpu.adc(op1, op2, setCond)
    of SBC: gba.cpu.sbc(op1, op2, setCond)
    of RSC: gba.cpu.sbc(op2, op1, setCond)
    of TST: op1 and op2
    of TEQ: op1 xor op2
    of CMP: gba.cpu.sub(op1, op2, setCond)
    of CMN: gba.cpu.add(op1, op2, setCond)
    of ORR: op1 or op2
    of MOV: op2
    of BIC: op1 and not(op2)
    of MVN: not(op2)
  when pc12Ahead: gba.cpu.r[15] -= 4
  when setCond:
    setNegAndZeroFlags(gba.cpu, value)
    when op in LogicOps: gba.cpu.cpsr.carry = shifterCarryOut
  if rd == 15:
    when setCond:
      let spsr = gba.cpu.spsr
      gba.cpu.mode = spsr.mode
      gba.cpu.cpsr = spsr
    when op in {TST, TEQ, CMP, CMN}: # todo: this needs to change once I start reading r15 as 12 ahead
      if gba.cpu.cpsr.thumb: discard # pc should already be 8 ahead of current arm instr, meaning thumb will execute 4 ahead
      else: gba.cpu.stepArm()
    else: gba.cpu.setReg(15, value)
  else:
    when op notin {TST, TEQ, CMP, CMN}: gba.cpu.r[rd] = value
    gba.cpu.stepArm()

# todo: move this back to nice block creation if the compile time is ever reduced...
macro lutBuilder(): untyped =
  result = newTree(nnkBracket)
  for i in 0'u32 ..< 4096'u32:
    result.add:
      checkBits i:
      of "000000..1001": call("multiply", i.testBit(5), i.testBit(4))
      of "00001...1001": call("multiplyLong", i.testBit(6), i.testBit(5), i.testBit(4))
      of "00010.001001": call("singleDataSwap", i.testBit(6))
      of "000100100001": call("branchExchange")
      of "000.....1..1": call("halfwordDataTransfer", i.testBit(8), i.testBit(7), i.testBit(6), i.testBit(5), i.testBit(4), i.bitsliced(1..2))
      of "011........1": call("undefined") # undefined instruction
      of "01..........": call("singleDataTransfer", i.testBit(9), i.testBit(8), i.testBit(7), i.testBit(6), i.testBit(5), i.testBit(4), i.testBit(0))
      of "100.........": call("blockDataTransfer", i.testBit(8), i.testBit(7), i.testBit(6), i.testBit(5), i.testBit(4))
      of "101.........": call("branch", i.testBit(8))
      of "110.........": call("undefined") # coprocessor data transfer
      of "1110.......0": call("undefined") # coprocessor data operation
      of "1110.......1": call("undefined") # coprocessor register transfer
      of "1111........": call("softwareInterrupt")
      of "00.10..0....": call("statusTransfer", i.testBit(9), i.testBit(6), i.testBit(5))
      of "00..........": call("dataProcessing", i.testBit(9), AluOp(i.bitsliced(5..8)), i.testBit(4), i.testBit(0))
      else:              call("unimplemented")

const lut = lutBuilder()

proc execArm*(gba: GBA, instr: uint32) =
  if gba.cpu.checkCond(instr.bitsliced(28..31)):
    lut[((instr shr 16) and 0x0FF0) or ((instr shr 4) and 0xF)](gba, instr)
  else:
    gba.cpu.stepArm()

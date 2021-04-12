import bitops, strformat, strutils, std/macros

import bus, cpu, types, util

type
  DataProcessingOp = enum
    AND, eor, sub, rsb,
    add, adc, sbc, rsc,
    tst, teq, cmp, cmn,
    orr, mov, bic, mvn

const
  LogicOps = {AND, eor, tst, teq, orr, mov, bic, mvn}

proc immediateOffset(instr: uint32, carryOut: var bool): uint32 =
  result = ror[false](instr.bitsliced(0..7), 2 * instr.bitsliced(8..11), carryOut)

proc rotateRegister[immediate: static bool](cpu: CPU, instr: uint32, carryOut: var bool): uint32 =
  let
    reg = instr.bitsliced(0..3)
    shiftType = instr.bitsliced(5..6)
    shiftAmount = if immediate: instr.bitsliced(7..11)
                  else: cpu.r[instr.bitsliced(8..11)] and 0xFF
  result = shift[immediate](shiftType, cpu.r[reg], shiftAmount, carryOut)

proc unimplemented(gba: GBA, instr: uint32) =
  quit "Unimplemented opcode: 0x" & instr.toHex(8)

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
  var value = when signed: signExtend(op1, 31) * signExtend(op2, 31)
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
    gba.cpu.setReg(rd, signExtend[uint32](gba.bus.read[:uint8](address).uint32, 7))
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
  for i in 0 .. 15:
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
  if msr:
    var mask = 0x00000000'u32
    if instr.bitTest(19): mask = mask or 0xFF000000'u32
    if instr.bitTest(16): mask = mask or 0x000000FF'u32
    if not(spsr) and mode == Mode.usr: mask = mask and 0x000000FF'u32
    var
      barrelOut: bool
      value = if immediate: immediateOffset(instr.bitsliced(0..11), barrelOut)
              else: gba.cpu.r[instr.bitsliced(0..3)]
    value = value and mask
    if spsr:
      if hasSpsr:
        gba.cpu.spsr = (gba.cpu.spsr and not(mask)) or value
    else:
      let thumb = gba.cpu.cpsr.thumb
      if instr.bitTest(16): gba.cpu.mode = Mode(value and 0x1F)
      gba.cpu.cpsr = (gba.cpu.cpsr and not(mask)) or value
      gba.cpu.cpsr.thumb = thumb
  else:
    let value = if spsr and hasSpsr: gba.cpu.spsr
                else: gba.cpu.cpsr
    gba.cpu.setReg(rd, value)
  if not(not(msr) and rd == 15): gba.cpu.stepArm()

proc dataProcessing[immediate: static bool, op: static DataProcessingOp, setCond, bit4: static bool](gba: GBA, instr: uint32) =
  var shifterCarryOut = gba.cpu.cpsr.carry
  let
    rn = instr.bitsliced(16..19)
    rd = instr.bitsliced(12..15)
    op1 = gba.cpu.r[rn]
    op2 = when immediate: immediateOffset(instr.bitsliced(0..11), shifterCarryOut)
          else: rotateRegister[not(bit4)](gba.cpu, instr.bitsliced(0..11), shifterCarryOut)
  let value = case op
    of AND: op1 and op2
    of eor: op1 xor op2
    of sub: gba.cpu.sub(op1, op2, setCond)
    of rsb: gba.cpu.sub(op2, op1, setCond)
    of add: gba.cpu.add(op1, op2, setCond)
    of adc: gba.cpu.adc(op1, op2, setCond)
    of sbc: gba.cpu.sbc(op1, op2, setCond)
    of rsc: gba.cpu.sbc(op2, op1, setCond)
    of tst: op1 and op2
    of teq: op1 xor op2
    of cmp: gba.cpu.sub(op1, op2, setCond)
    of cmn: gba.cpu.add(op1, op2, setCond)
    of orr: op1 or op2
    of mov: op2
    of bic: op1 and not(op2)
    of mvn: not(op2)
  when setCond:
    setNegAndZeroFlags(gba.cpu, value)
    when op in LogicOps: gba.cpu.cpsr.carry = shifterCarryOut
    if rd == 15: quit "todo: implement data processing return " & instr.toHex(8)
  when op notin {tst, teq, cmp, cmn}:
    gba.cpu.setReg(rd, value)
    if rd != 15: gba.cpu.stepArm()
  else: gba.cpu.stepArm()

# todo: move this back to nice block creation if the compile time is ever reduced...
macro lutBuilder(): untyped =
  result = newTree(nnkBracket)
  for i in 0'u32 ..< 4096'u32:
    if (i and 0b111111001111) == 0b000000001001:
      result.add newTree(nnkBracketExpr, bindSym"multiply", i.bitTest(5).newLit(), i.bitTest(4).newLit())
    elif (i and 0b111110001111) == 0b000010001001:
      result.add newTree(nnkBracketExpr, bindSym"multiplyLong", i.bitTest(6).newLit(), i.bitTest(5).newLit(), i.bitTest(4).newLit())
    elif (i and 0b111110111111) == 0b000100001001:
      result.add newTree(nnkBracketExpr, bindSym"singleDataSwap", i.bitTest(6).newLit())
    elif (i and 0b111111111111) == 0b000100100001:
      result.add bindSym"branchExchange"
    elif (i and 0b111000001001) == 0b000000001001:
      result.add newTree(nnkBracketExpr, bindSym"halfwordDataTransfer", i.bitTest(8).newLit(), i.bitTest(7).newLit(), i.bitTest(6).newLit(), i.bitTest(5).newLit(), i.bitTest(4).newLit(), newLit (i shr 1) and 0b11)
    elif (i and 0b111000000001) == 0b011000000001:
      result.add newNilLit() # undefined instruction
    elif (i and 0b110000000000) == 0b010000000000:
      result.add newTree(nnkBracketExpr, bindSym"singleDataTransfer", i.bitTest(9).newLit(), i.bitTest(8).newLit(), i.bitTest(7).newLit(), i.bitTest(6).newLit(), i.bitTest(5).newLit(), i.bitTest(4).newLit(), i.bitTest(0).newLit())
    elif (i and 0b111000000000) == 0b100000000000:
      result.add newTree(nnkBracketExpr, bindSym"blockDataTransfer", i.bitTest(8).newLit(), i.bitTest(7).newLit(), i.bitTest(6).newLit(), i.bitTest(5).newLit(), i.bitTest(4).newLit())
    elif (i and 0b111000000000) == 0b101000000000:
      result.add newTree(nnkBracketExpr, bindSym"branch", i.bitTest(8).newLit())
    elif (i and 0b111000000000) == 0b110000000000:
      result.add newNilLit() # coprocessor data transfer
    elif (i and 0b111100000001) == 0b111000000000:
      result.add newNilLit() # coprocessor data operation
    elif (i and 0b111100000001) == 0b111000000001:
      result.add newNilLit() # coprocessor register transfer
    elif (i and 0b111100000000) == 0b111100000000:
      result.add bindSym"softwareInterrupt"
    elif (i and 0b110110010000) == 0b000100000000:
      result.add newTree(nnkBracketExpr, bindSym"statusTransfer", i.bitTest(9).newLit(), i.bitTest(6).newLit(), i.bitTest(5).newLit())
    elif (i and 0b110000000000) == 0b000000000000:
      result.add newTree(nnkBracketExpr, bindSym"dataProcessing", i.bitTest(9).newLit(), newLit(DataProcessingOp((i shr 5) and 0xF)), i.bitTest(4).newLit(), i.bitTest(0).newLit())
    else:
      result.add bindSym"unimplemented"

const lut = lutBuilder()

proc execArm*(gba: GBA, instr: uint32) =
  if gba.cpu.checkCond(instr.bitsliced(28..31)):
    lut[((instr shr 16) and 0x0FF0) or ((instr shr 4) and 0xF)](gba, instr)
  else:
    gba.cpu.stepArm()

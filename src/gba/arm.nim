import bitops, strformat, strutils, std/macros

import bus, cpu, types

proc immediateOffset(instr: uint32, carryOut: ptr bool): uint32 =
  # todo putting "false" here causes the gba-suite tests to pass, but _why_
  result = ror(instr.bitSliced(0..7), 2 * instr.bitSliced(8..11), false, carryOut)

proc rotateRegister(cpu: CPU, instr: uint32, carryOut: ptr bool, allowRegisterShifts: bool): uint32 =
  let
    reg = instr.bitSliced(0..3)
    shiftType = instr.bitSliced(5..6)
    immediate = not(allowRegisterShifts and instr.testBit(4))
    shiftAmount = if immediate: instr.bitSliced(7..11)
                  else: cpu.r[instr.bitSliced(8..11)] and 0xFF
  result = case shiftType
           of 0b00: lsl(cpu.r[reg], shiftAmount, carryOut)
           else: quit fmt"unimplemented shift type: {shiftType}"

converter psrToU32(psr: PSR): uint32 = cast[uint32](psr)

proc unimplemented(gba: GBA, instr: uint32) =
  quit "Unimplemented opcode: 0x" & instr.toHex(8)

proc multiply[accumulate, set_cond: static bool](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: Multiply<" & $accumulate & "," & $set_cond & ">(0x" & instr.toHex(8) & ")"

proc multiply_long[signed, accumulate, set_cond: static bool](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: MultipleLong<" & $signed & "," & $accumulate & "," & $set_cond & ">(0x" & instr.toHex(8) & ")"

proc single_data_swap[word: static bool](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: SingleDataSwap<" & $instr & ">(0x" & instr.toHex(8) & ")"

proc branch_exchange(gba: GBA, instr: uint32) =
  let address = gba.cpu.r[instr.bitsliced(0..3)]
  gba.cpu.cpsr.thumb = bool(address and 1)
  gba.cpu.setReg(15, address)

proc halfword_data_transfer[pre, add, immediate, writeback, load: static bool, op: static int](gba: GBA, instr: uint32) =
  let
    rn = instr.bitSliced(16..19)
    rd = instr.bitSliced(12..15)
    offset_high = instr.bitSliced(8..11)
    rm = instr.bitSliced(0..3)
    offset = if immediate: (offset_high shl 4) or rm
             else: gba.cpu.r[rm]
  var address = gba.cpu.r[rn]
  if pre:
    if add:
      address += offset
    else:
      address -= offset
  case op
  of 0b01:
    if load:
      quit "load halfword"
    else:
      var value = gba.cpu.r[rd]
      # When R15 is the source register (Rd) of a register store (STR) instruction, the stored
      # value will be address of the instruction plus 12.
      if rd == 15: value += 4
      gba.bus[address] = uint16(value) and 0xFFFF'u16
  else: quit fmt"unhandled halfword transfer op: {op}"
  if not pre:
    if add:
      address += offset
    else:
      address -= offset
  if writeback: quit "implement writeback"
  if rd != 15: gba.cpu.stepArm()

proc single_data_transfer[immediate, pre, add, word, writeback, load: static bool](gba: GBA, instr: uint32) =
  var shifterCarryOut = gba.cpu.cpsr.carry
  let
    rn = instr.bitSliced(16..19)
    rd = instr.bitsliced(12..15)
    offset = if immediate: rotateRegister(gba.cpu, instr.bitSliced(0..11), unsafeAddr shifterCarryOut, false)
             else: instr.bitSliced(0..11)
  var address = gba.cpu.r[rn]
  if pre:
    if add: address += offset
    else: address -= offset
  if load:
    let value = if word: gba.bus[address].uint32
                else: gba.bus.readWordRotate(address)
    gba.cpu.setReg(rd, value)
  else:
    var value = gba.cpu.r[rd]
    # When R15 is the source register (Rd) of a register store (STR) instruction, the stored
    # value will be address of the instruction plus 12.
    if rd == 15: value += 4
    if word: value = value and 0xFF'u8
    gba.bus[address] = value
  if not pre:
    if add: address += offset
    else: address -= offset
  if writeback: quit "implement writeback"
  if rd != 15: gba.cpu.stepArm()

proc block_data_transfer[pre, add, psr_user, writeback, load: static bool](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: BlockDataTransfer<" & $pre & "," & $add & "," & $psr_user & "," & $writeback & "," & $load & ">(0x" & instr.toHex(8) & ")"

proc branch[link: static bool](gba: GBA, instr: uint32) =
  var offset = instr.bitSliced(0..23)
  if offset.testBit(23): offset = offset or 0xFF000000'u32
  if link: gba.cpu.setReg(14, gba.cpu.r[15] - 4)
  gba.cpu.setReg(15, gba.cpu.r[15] + offset * 4)

proc software_interrupt(gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: SoftwareInterrupt<>(0x" & instr.toHex(8) & ")"

proc status_transfer[immediate, spsr, msr: static bool](gba: GBA, instr: uint32) =
  let
    rd = instr.bitsliced(12..15)
    mode = gba.cpu.cpsr.mode
    hasSpsr = mode != Mode.sys and mode != Mode.usr
  if msr:
    var mask = 0x00000000'u32
    if instr.testBit(19): mask = mask or 0xFF000000'u32
    if instr.testBit(16): mask = mask or 0x000000FF'u32
    if not(spsr) and mode == Mode.usr: mask = mask and 0x000000FF'u32
    var
      barrelOut: bool
      value = if immediate: immediateOffset(instr.bitSliced(0..11), unsafeAddr barrelOut)
              else: gba.cpu.r[instr.bitsliced(0..3)]
    value = value and mask
    if spsr:
      if hasSpsr:
        gba.cpu.spsr = cast[PSR]((cast[uint32](gba.cpu.spsr) and not(mask)) or value)
    else:
      let thumb = gba.cpu.cpsr.thumb
      if instr.testBit(16): gba.cpu.mode = Mode(value and 0x1F)
      gba.cpu.cpsr = cast[PSR]((cast[uint32](gba.cpu.cpsr) and not(mask)) or value)
      gba.cpu.cpsr.thumb = thumb
  else:
    let value = if spsr and hasSpsr: gba.cpu.spsr
                else: gba.cpu.cpsr
    gba.cpu.setReg(rd, value)
  if not(not(msr) and rd == 15): gba.cpu.stepArm()

proc data_processing[immediate: static bool, op: static int, set_cond: static bool](gba: GBA, instr: uint32) =
  var shifterCarryOut = gba.cpu.cpsr.carry
  let
    rn = instr.bitSliced(16..19)
    rd = instr.bitSliced(12..15)
    op2 = if immediate:
            immediateOffset(instr.bitSliced(0..11), unsafeAddr shifterCarryOut)
          else:
            rotateRegister(gba.cpu, instr.bitSliced(0..11), unsafeAddr shifterCarryOut, true)
  case op
  of 0b0100: # add
    gba.cpu.setReg(rd, gba.cpu.add(gba.cpu.r[rn], op2, set_cond))
    if rd != 15: gba.cpu.stepArm()
  of 0b1010: # cmp
    discard gba.cpu.sub(gba.cpu.r[rn], op2, set_cond)
    gba.cpu.stepArm()
  of 0b1101: # mov
    gba.cpu.setReg(rd, op2)
    if set_cond:
      setNegAndZeroFlags(gba.cpu, gba.cpu.r[rd])
      gba.cpu.cpsr.carry = shifterCarryOut
    if rd != 15: gba.cpu.stepArm()
  else: quit "DataProcessing<" & $immediate & "," & $op & "," & $set_cond & ">(0x" & instr.toHex(8) & ")"

# todo: move this back to nice block creation if the compile time is ever reduced...
macro lutBuilder(): untyped =
  result = newTree(nnkBracket)
  const InstrCount = 4096
  for i in 0 ..< InstrCount:
    if (i and 0b111111001111) == 0b000000001001:
      result.add newTree(nnkBracketExpr, bindSym"multiply", i.testBit(5).newLit(), i.testBit(4).newLit())
    elif (i and 0b111110001111) == 0b000010001001:
      result.add newTree(nnkBracketExpr, bindSym"multiply_long", i.testBit(6).newLit(), i.testBit(5).newLit(), i.testBit(4).newLit())
    elif (i and 0b111110111111) == 0b000100001001:
      result.add newTree(nnkBracketExpr, bindSym"single_data_swap", i.testBit(6).newLit())
    elif (i and 0b111111111111) == 0b000100100001:
      result.add bindSym"branch_exchange"
    elif (i and 0b111000001001) == 0b000000001001:
      result.add newTree(nnkBracketExpr, bindSym"halfword_data_transfer", i.testBit(8).newLit(), i.testBit(7).newLit(), i.testBit(6).newLit(), i.testBit(5).newLit(), i.testBit(4).newLit(), newLit (i shr 1) and 0b11)
    elif (i and 0b111000000001) == 0b011000000001:
      result.add newNilLit() # undefined instruction
    elif (i and 0b110000000000) == 0b010000000000:
      result.add newTree(nnkBracketExpr, bindSym"single_data_transfer", i.testBit(9).newLit(), i.testBit(8).newLit(), i.testBit(7).newLit(), i.testBit(6).newLit(), i.testBit(5).newLit(), i.testBit(4).newLit())
    elif (i and 0b111000000000) == 0b100000000000:
      result.add newTree(nnkBracketExpr, bindSym"block_data_transfer", i.testBit(8).newLit(), i.testBit(7).newLit(), i.testBit(6).newLit(), i.testBit(5).newLit(), i.testBit(4).newLit())
    elif (i and 0b111000000000) == 0b101000000000:
      result.add newTree(nnkBracketExpr, bindSym"branch", i.testBit(8).newLit())
    elif (i and 0b111000000000) == 0b110000000000:
      result.add newNilLit() # coprocessor data transfer
    elif (i and 0b111100000001) == 0b111000000000:
      result.add newNilLit() # coprocessor data operation
    elif (i and 0b111100000001) == 0b111000000001:
      result.add newNilLit() # coprocessor register transfer
    elif (i and 0b111100000000) == 0b111100000000:
      result.add bindSym"software_interrupt"
    elif (i and 0b110110010000) == 0b000100000000:
      result.add newTree(nnkBracketExpr, bindSym"status_transfer", i.testBit(9).newLit(), i.testBit(6).newLit(), i.testBit(5).newLit())
    elif (i and 0b110000000000) == 0b000000000000:
      result.add newTree(nnkBracketExpr, bindSym"data_processing", i.testBit(9).newLit(), newLit((i shr 5) and 0xF), i.testBit(4).newLit())
    else:
      result.add bindSym"unimplemented"

const lut = lutBuilder()

proc execArm*(gba: GBA, instr: uint32) =
  if gba.cpu.checkCond(instr.bitSliced(28..31)):
    lut[((instr shr 16) and 0x0FF0) or ((instr shr 4) and 0xF)](gba, instr)
  else:
    gba.cpu.stepArm()

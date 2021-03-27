import bitops, strutils, std/macros

import bus, cpu, types

proc unimplemented(gba: GBA, instr: uint32) =
  quit "Unimplemented opcode: 0x" & instr.toHex(4)

proc longBranchLink[offset_high: static bool](gba: GBA, instr: uint32) =
  let offset = instr.bitsliced(0..10)
  if offset_high:
    let r15 = gba.cpu.r[15]
    gba.cpu.setReg(15, gba.cpu.r[14] + (offset shl 1))
    gba.cpu.r[14] = (r15 - 2) or 1
  else:
    gba.cpu.r[14] = gba.cpu.r[15] + (offset shl 12)
    gba.cpu.stepThumb()

proc unconditionalBranch(gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: UnconditionalBranch<>(0x" & instr.toHex(4) & ")"

proc softwareInterrupt(gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: SoftwareInterrupt<>(0x" & instr.toHex(4) & ")"

proc conditionalBranch[cond: static uint32](gba: GBA, instr: uint32) =
  if gba.cpu.checkCond(cond):
    let offset = cast[uint32](int32(cast[int8](instr.bitsliced(0..7))) * 2)
    gba.cpu.setReg(15, gba.cpu.r[15] + offset)
  else:
    gba.cpu.stepThumb()

proc multipleLoadStore[load: static bool, rb: static uint32](gba: GBA, instr: uint32) =
  var
    address = gba.cpu.r[rb]
    firstTransfer = false
  let
    list = instr.bitsliced(0..7)
    setBits = countSetBits(list)
    finalAddress = address + uint32(setBits * 4)
  for i in 0 .. 7:
    if list.testBit(i):
      if load:
        gba.cpu.r[i] = gba.bus.readWord(address)
      else:
        gba.bus[address] = gba.cpu.r[i]
        if not(firstTransfer): gba.cpu.r[rb] = finalAddress
        firstTransfer = true
      address += 4
  gba.cpu.r[rb] = finalAddress
  gba.cpu.stepThumb()

proc pushPop[pop, pclr: static bool](gba: GBA, instr: uint32) =
  var
    address = gba.cpu.r[13]
    firstTransfer = false
    list = instr.bitsliced(0..7)
    setBits = countSetBits(list) + int(pclr)
    finalAddress = address + uint32(setBits * (if pop: 4 else: -4))
  if not(pop): address = finalAddress
  for i in 0 .. 7:
    if list.testBit(i):
      if pop:
        gba.cpu.r[i] = gba.bus.readWord(address)
      else:
        gba.bus[address] = gba.cpu.r[i]
        if not(firstTransfer): gba.cpu.r[13] = finalAddress
        firstTransfer = true
      address += 4
  if pclr:
    if pop:
      gba.cpu.setReg(15, gba.bus.readWord(address))
    else:
      gba.bus[address] = gba.cpu.r[13]
  if not(pop and pclr): gba.cpu.stepThumb()
  gba.cpu.r[13] = finalAddress

proc addToStackPointer[negative: static bool](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: AddToStackPointer<" & $negative & ">(0x" & instr.toHex(4) & ")"

proc loadAddress[sp: static bool, rd: static uint32](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: LoadAddress<" & $sp & "," & $rd & ">(0x" & instr.toHex(4) & ")"

proc spRelativeLoadStore[load: static bool, rd: static uint32](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: SpRelativeLoadStore<" & $load & "," & $rd & ">(0x" & instr.toHex(4) & ")"

proc loadStoreHalfword[load: static bool, offset: static uint32](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: LoadStoreHalfword<" & $load & "," & $offset & ">(0x" & instr.toHex(4) & ")"

proc loadStoreImmOffset[bl, offset: static uint32](gba: GBA, instr: uint32) =
  let
    rb = instr.bitsliced(3..5)
    rd = instr.bitsliced(0..2)
    address = gba.cpu.r[rb]
  case bl
  of 0b00: gba.bus[address + (offset shl 2)] = gba.cpu.r[rd]
  of 0b01: gba.cpu.r[rd] = gba.bus.readWord(address + (offset shl 2))
  of 0b10: gba.bus[address + offset] = uint8(gba.cpu.r[rd] and 0xFF)
  of 0b11: gba.cpu.r[rd] = uint32(gba.bus[address + offset])
  else: quit "Unimplemented instruction: LoadStoreImmOffset<" & $bl & "," & $offset & ">(0x" & instr.toHex(4) & ")"
  gba.cpu.stepThumb();

proc loadStoreSignExtended[hs, ro: static uint32](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: LoadStoreSignExtended<" & $hs & "," & $ro & ">(0x" & instr.toHex(4) & ")"

proc loadStoreRegOffset[lb, ro: static uint32](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: LoadStoreRegOffset<" & $lb & "," & $ro & ">(0x" & instr.toHex(4) & ")"

proc pcRelativeLoad[rd: static uint32](gba: GBA, instr: uint32) =
  let immediate = instr.bitsliced(0..7) shl 2
  gba.cpu.r[rd] = gba.bus.readWord((gba.cpu.r[15] and not(2'u32)) + immediate)
  gba.cpu.stepThumb()

proc highRegOps[op: static uint32, h1, h2: static bool](gba: GBA, instr: uint32) =
  let
    rs = instr.bitsliced(3..5) or ((instr and 0x40) shr 3)
    rd = instr.bitsliced(0..2) or ((instr and 0x80) shr 4)
    value = gba.cpu.r[rs]
  case op
  of 0b00: gba.cpu.setReg(rd, gba.cpu.add(gba.cpu.r[rd], value, false))
  of 0b01: discard gba.cpu.sub(gba.cpu.r[rd], value, true)
  of 0b10: gba.cpu.setReg(rd, value)
  of 0b11:
    gba.cpu.cpsr.thumb = value.testBit(0)
    gba.cpu.setReg(15, value)
  else: quit "Unimplemented instruction: HighRegOps<" & $op & "," & $h1 & "," & $h2 & ">(0x" & instr.toHex(4) & ")"
  if op != 0b11 and not((op != 0b01 and rd == 15)): gba.cpu.stepThumb()

proc aluOps[op: static uint32](gba: GBA, instr: uint32) =
  var shifterCarryOut = gba.cpu.cpsr.carry
  let
    rs = instr.bitsliced(3..5)
    rd = instr.bitsliced(0..2)
  case op
  of 0xE:
    gba.cpu.r[rd] = gba.cpu.r[rd] and not(gba.cpu.r[rs])
    gba.cpu.setNegAndZeroFlags(gba.cpu.r[rd])
  else: quit "Unimplemented instruction: AluOps<" & $op & ">(0x" & instr.toHex(4) & ")"
  gba.cpu.stepThumb()

proc moveCompareAddSubtract[op, rd: static uint32](gba: GBA, instr: uint32) =
  let immediate = instr.bitsliced(0..7)
  case op
  of 0b00:
    gba.cpu.r[rd] = immediate
    gba.cpu.setNegAndZeroFlags(immediate)
  of 0b01: discard gba.cpu.sub(gba.cpu.r[rd], immediate, true)
  of 0b10: gba.cpu.r[rd] = gba.cpu.add(gba.cpu.r[rd], immediate, true)
  of 0b11: gba.cpu.r[rd] = gba.cpu.sub(gba.cpu.r[rd], immediate, true)
  else: quit "Unimplemented instruction: MoveCompareAddSubtract<" & $op & "," & $rd & ">(0x" & instr.toHex(4) & ")"
  gba.cpu.stepThumb()

proc addSubtract[immediate, sub: static bool, offset: static uint32](gba: GBA, instr: uint32) =
  let
    rs = instr.bitsliced(3..5)
    rd = instr.bitsliced(0..2)
    value = if immediate: offset
            else: gba.cpu.r[offset]
  gba.cpu.r[rd] = if sub: gba.cpu.sub(gba.cpu.r[rs], value, true)
                  else:   gba.cpu.add(gba.cpu.r[rs], value, true)
  gba.cpu.stepThumb()

proc moveShiftedReg[op, offset: static uint32](gba: GBA, instr: uint32) =
  var shifterCarryOut = gba.cpu.cpsr.carry
  let
    rs = instr.bitsliced(3..5)
    rd = instr.bitsliced(0..2)
    value = case op
      of 0b00: lsl(gba.cpu.r[rs], offset, shifterCarryOut)
      of 0b01: lsr(gba.cpu.r[rs], offset, shifterCarryOut)
      of 0b10: asr(gba.cpu.r[rs], offset, shifterCarryOut)
      else: quit "Unimplemented instruction: MoveShiftedRegister<" & $op & "," & $offset & ">(0x" & instr.toHex(4) & ")"
  gba.cpu.r[rd] = value
  gba.cpu.cpsr.carry = shifterCarryOut
  gba.cpu.setNegAndZeroFlags(value)
  gba.cpu.stepThumb()

macro lutBuilder(): untyped =
  result = newTree(nnkBracket)
  for i in 0'u32 ..< 1024'u32:
    if (i and 0b1111000000) == 0b1111000000:
      result.add newTree(nnkBracketExpr, bindSym"longBranchLink", i.testBit(5).newLit())
    elif (i and 0b1111100000) == 0b1110000000:
      result.add bindSym"unconditionalBranch"
    elif (i and 0b1111111100) == 0b1101111100:
      result.add bindSym"softwareInterrupt"
    elif (i and 0b1111000000) == 0b1101000000:
      result.add newTree(nnkBracketExpr, bindSym"conditionalBranch", newLit((i shr 2) and 0xF))
    elif (i and 0b1111000000) == 0b1100000000:
      result.add newTree(nnkBracketExpr, bindSym"multipleLoadStore", i.testBit(5).newLit(), newLit((i shr 2) and 7))
    elif (i and 0b1111011000) == 0b1011010000:
      result.add newTree(nnkBracketExpr, bindSym"pushPop", i.testBit(5).newLit(), i.testBit(2).newLit())
    elif (i and 0b1111111100) == 0b1011000000:
      result.add newTree(nnkBracketExpr, bindSym"addToStackPointer", i.testBit(1).newLit())
    elif (i and 0b1111000000) == 0b1010000000:
      result.add newTree(nnkBracketExpr, bindSym"loadAddress", i.testBit(5).newLit(), newLit((i shr 2) and 7))
    elif (i and 0b1111000000) == 0b1001000000:
      result.add newTree(nnkBracketExpr, bindSym"spRelativeLoadStore", i.testBit(5).newLit(), newLit((i shr 2) and 7))
    elif (i and 0b1111000000) == 0b1000000000:
      result.add newTree(nnkBracketExpr, bindSym"loadStoreHalfword", i.testBit(5).newLit(), newLit((i and 0x1F)))
    elif (i and 0b1110000000) == 0b0110000000:
      result.add newTree(nnkBracketExpr, bindSym"loadStoreImmOffset", newLit((i shr 5) and 3), newLit((i and 0x1F)))
    elif (i and 0b1111001000) == 0b0101001000:
      result.add newTree(nnkBracketExpr, bindSym"loadStoreSignExtended", newLit((i shr 4) and 3), newLit((i and 7)))
    elif (i and 0b1111001000) == 0b0101000000:
      result.add newTree(nnkBracketExpr, bindSym"loadStoreRegOffset", newLit((i shr 4) and 3), newLit((i and 7)))
    elif (i and 0b1111100000) == 0b0100100000:
      result.add newTree(nnkBracketExpr, bindSym"pcRelativeLoad", newLit(((i shr 2) and 7)))
    elif (i and 0b1111110000) == 0b0100010000:
      result.add newTree(nnkBracketExpr, bindSym"highRegOps", newLit(((i shr 2) and 3)), i.testBit(1).newLit(), i.testBit(0).newLit())
    elif (i and 0b1111110000) == 0b0100000000:
      result.add newTree(nnkBracketExpr, bindSym"aluOps", newLit((i and 0x1F)))
    elif (i and 0b1110000000) == 0b0010000000:
      result.add newTree(nnkBracketExpr, bindSym"moveCompareAddSubtract", newLit((i shr 5) and 3), newLit(((i shr 2) and 7)))
    elif (i and 0b1111100000) == 0b0001100000:
      result.add newTree(nnkBracketExpr, bindSym"addSubtract", i.testBit(4).newLit(), i.testBit(3).newLit(), newLit((i and 7)))
    elif (i and 0b1110000000) == 0b0000000000:
      result.add newTree(nnkBracketExpr, bindSym"moveShiftedReg", newLit((i shr 5) and 3), newLit((i and 0x1F)))
    else:
      result.add bindSym"unimplemented"

const lut = lutBuilder()

proc execThumb*(gba: GBA, instr: uint32) =
  lut[instr shr 6](gba, instr)

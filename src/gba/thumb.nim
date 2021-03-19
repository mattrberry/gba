import bitops, strutils, std/macros

import bus, cpu, types

proc unimplemented(gba: GBA, instr: uint32) =
  quit "Unimplemented opcode: 0x" & instr.toHex(4)

proc longBranchLink[offset_high: static bool](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: LongBranchLink<" & $offset_high & ">(0x" & instr.toHex(4) & ")"

proc unconditionalBranch(gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: UnconditionalBranch<>(0x" & instr.toHex(4) & ")"

proc softwareInterrupt(gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: SoftwareInterrupt<>(0x" & instr.toHex(4) & ")"

proc conditionalBranch[cond: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: ConditionalBranch<" & $cond & ">(0x" & instr.toHex(4) & ")"

proc multipleLoadStore[load: static bool, rb: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: MultipleLoadStore<" & $load & "," & $rb & ">(0x" & instr.toHex(4) & ")"

proc pushPop[load, pclr: static bool](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: PushPop<" & $load & "," & $pclr & ">(0x" & instr.toHex(4) & ")"

proc addToStackPointer[negative: static bool](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: AddToStackPointer<" & $negative & ">(0x" & instr.toHex(4) & ")"

proc loadAddress[sp: static bool, rd: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: LoadAddress<" & $sp & "," & $rd & ">(0x" & instr.toHex(4) & ")"

proc spRelativeLoadStore[load: static bool, rd: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: SpRelativeLoadStore<" & $load & "," & $rd & ">(0x" & instr.toHex(4) & ")"

proc loadStoreHalfword[load: static bool, offset: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: LoadStoreHalfword<" & $load & "," & $offset & ">(0x" & instr.toHex(4) & ")"

proc loadStoreImmOffset[bl, offset: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: LoadStoreImmOffset<" & $bl & "," & $offset & ">(0x" & instr.toHex(4) & ")"

proc loadStoreSignExtended[hs, ro: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: LoadStoreSignExtended<" & $hs & "," & $ro & ">(0x" & instr.toHex(4) & ")"

proc loadStoreRegOffset[lb, ro: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: LoadStoreRegOffset<" & $lb & "," & $ro & ">(0x" & instr.toHex(4) & ")"

proc pcRelativeLoad[rd: static int](gba: GBA, instr: uint32) =
  let immediate = instr.bitsliced(0..7) shl 2
  gba.cpu.r[rd] = gba.bus.readWord((gba.cpu.r[15] and not(2'u32)) + immediate)
  gba.cpu.stepThumb()

proc highRegOps[op: static int, h1, h2: static bool](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: PcRelativeLoad<" & $op & "," & $h1 & "," & $h2 & ">(0x" & instr.toHex(4) & ")"

proc aluOps[op: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: AluOps<" & $op & ">(0x" & instr.toHex(4) & ")"

proc moveCompareAddSubtract[op, rd: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: MoveCompareAddSubtract<" & $op & "," & $rd & ">(0x" & instr.toHex(4) & ")"

proc addSubtract[immediate, sub: static bool, offset: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: AddSubtract<" & $immediate & "," & $sub & "," & $offset & ">(0x" & instr.toHex(4) & ")"

proc moveShiftedReg[op, offset: static int](gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: MoveShiftedRegister<" & $op & "," & $offset & ">(0x" & instr.toHex(4) & ")"

macro lutBuilder(): untyped =
  result = newTree(nnkBracket)
  for i in 0 ..< 1024:
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
    elif (i and 0b1111011000) == 0b1011011000:
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

import bitops, strutils, std/macros

import bus, cpu, types, util, macros as _

type
  AluOp = enum
    AND, EOR, LSL, LSR,
    ASR, ADC, SBC, ROR,
    TST, NEG, CMP, CMN,
    ORR, MUL, BIC, MVN

proc unimplemented(gba: GBA, instr: uint32) =
  quit "Unimplemented opcode: 0x" & instr.toHex(4)

proc longBranchLink[offsetHigh: static bool](gba: GBA, instr: uint32) =
  let offset = instr.bitsliced(0..10)
  if offsetHigh:
    let r15 = gba.cpu.r[15]
    gba.cpu.setReg(15, gba.cpu.r[14] + (offset shl 1))
    gba.cpu.r[14] = (r15 - 2) or 1
  else:
    gba.cpu.r[14] = gba.cpu.r[15] + (signExtend(uint32, offset, 10) shl 12)
    gba.cpu.stepThumb()

proc unconditionalBranch(gba: GBA, instr: uint32) =
  let offset = signExtend(uint32, instr.bitsliced(0..10), 10) shl 1
  gba.cpu.setReg(15, gba.cpu.r[15] + offset)

proc softwareInterrupt(gba: GBA, instr: uint32) =
  quit "Unimplemented instruction: SoftwareInterrupt<>(0x" & instr.toHex(4) & ")"

proc conditionalBranch[cond: static uint32](gba: GBA, instr: uint32) =
  if gba.cpu.checkCond(cond):
    let offset = signExtend(uint32, instr.bitsliced(0..7), 7) * 2
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
  for i in 0'u8 .. 7'u8:
    if list.bit(i):
      if load:
        gba.cpu.r[i] = gba.bus.read[:uint32](address)
      else:
        gba.bus[address] = gba.cpu.r[i]
      address += 4
      if not(firstTransfer) and not(load and list.bit(rb)): gba.cpu.r[rb] = finalAddress
      firstTransfer = true
  gba.cpu.stepThumb()

proc pushPop[pop, pclr: static bool](gba: GBA, instr: uint32) =
  var
    address = gba.cpu.r[13]
  let
    list = instr.bitsliced(0..7)
    setBits = countSetBits(list) + int(pclr)
    finalAddress = address + uint32(setBits * (if pop: 4 else: -4))
  if not(pop): address = finalAddress
  for i in 0'u8 .. 7'u8:
    if list.bit(i):
      if pop:
        gba.cpu.r[i] = gba.bus.read[:uint32](address)
      else:
        gba.bus[address] = gba.cpu.r[i]
      address += 4
  if pclr:
    if pop:
      gba.cpu.setReg(15, gba.bus.read[:uint32](address))
    else:
      gba.bus[address] = gba.cpu.r[14]
  gba.cpu.r[13] = finalAddress
  if not(pop and pclr): gba.cpu.stepThumb()

proc addToStackPointer[subtract: static bool](gba: GBA, instr: uint32) =
  let offset = instr.bitsliced(0..6) shl 2
  if subtract: gba.cpu.r[13] -= offset
  else: gba.cpu.r[13] += offset
  gba.cpu.stepThumb()

proc loadAddress[sp: static bool, rd: static uint32](gba: GBA, instr: uint32) =
  let
    base = if sp: gba.cpu.r[13]
           else: gba.cpu.r[15] and not(2'u32)
    offset = instr.bitsliced(0..7) shl 2
  gba.cpu.r[rd] = base + offset
  gba.cpu.stepThumb()

proc spRelativeLoadStore[load: static bool, rd: static uint32](gba: GBA, instr: uint32) =
  let
    offset = instr.bitsliced(0..7) shl 2
    address = gba.cpu.r[13] + offset
  if load: gba.cpu.r[rd] = gba.bus.readRotate[:uint32](address)
  else: gba.bus[address] = gba.cpu.r[rd]
  gba.cpu.stepThumb()

proc loadStoreHalfword[load: static bool, offset: static uint32](gba: GBA, instr: uint32) =
  let
    rb = instr.bitsliced(3..5)
    rd = instr.bitsliced(0..2)
    address = gba.cpu.r[rb] + (offset shl 2)
  if load: gba.cpu.r[rd] = gba.bus.readRotate[:uint16](address)
  else: gba.bus[address] = cast[uint16](gba.cpu.r[rd])
  gba.cpu.stepThumb()

proc loadStoreImmOffset[bl, offset: static uint32](gba: GBA, instr: uint32) =
  let
    rb = instr.bitsliced(3..5)
    rd = instr.bitsliced(0..2)
    address = gba.cpu.r[rb]
  case bl
  of 0b00: gba.bus[address + (offset shl 2)] = gba.cpu.r[rd]
  of 0b01: gba.cpu.r[rd] = gba.bus.readRotate[:uint32](address + (offset shl 2))
  of 0b10: gba.bus[address + offset] = uint8(gba.cpu.r[rd] and 0xFF)
  of 0b11: gba.cpu.r[rd] = uint32(gba.bus.read[:uint8](address + offset))
  else: quit "Unimplemented instruction: LoadStoreImmOffset<" & $bl & "," & $offset & ">(0x" & instr.toHex(4) & ")"
  gba.cpu.stepThumb()

proc loadStoreSignExtended[hs, ro: static uint32](gba: GBA, instr: uint32) =
  let
    rb = instr.bitsliced(3..5)
    rd = instr.bitsliced(0..2)
    address = gba.cpu.r[rb] + gba.cpu.r[ro]
  case hs
  of 0b00: gba.bus[address] = cast[uint16](gba.cpu.r[rd]) # strh
  of 0b01: gba.cpu.r[rd] = gba.bus.readSigned[:uint8](address) # ldsb
  of 0b10: gba.cpu.r[rd] = gba.bus.readRotate[:uint16](address) # ldrh
  of 0b11: gba.cpu.r[rd] = gba.bus.readSigned[:uint16](address) # ldsh
  else: quit "Unimplemented instruction: LoadStoreSignExtended<" & $hs & "," & $ro & ">(0x" & instr.toHex(4) & ")"
  gba.cpu.stepThumb()

proc loadStoreRegOffset[lb, ro: static uint32](gba: GBA, instr: uint32) =
  let
    rb = instr.bitsliced(3..5)
    rd = instr.bitsliced(0..2)
    address = gba.cpu.r[rb] + gba.cpu.r[ro]
  case lb
  of 0b00: gba.bus[address] = gba.cpu.r[rd]
  of 0b01: gba.bus[address] = cast[uint8](gba.cpu.r[rd])
  of 0b10: gba.cpu.r[rd] = gba.bus.readRotate[:uint32](address)
  of 0b11: gba.cpu.r[rd] = gba.bus.read[:uint8](address)
  else: quit "Unimplemented instruction: LoadStoreRegOffset<" & $lb & "," & $ro & ">(0x" & instr.toHex(4) & ")"
  gba.cpu.stepThumb()

proc pcRelativeLoad[rd: static uint32](gba: GBA, instr: uint32) =
  let immediate = instr.bitsliced(0..7) shl 2
  gba.cpu.r[rd] = gba.bus.readRotate[:uint32]((gba.cpu.r[15] and not(2'u32)) + immediate)
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
    gba.cpu.cpsr.thumb = value.bit(0)
    gba.cpu.setReg(15, value)
  else: quit "Unimplemented instruction: HighRegOps<" & $op & "," & $h1 & "," & $h2 & ">(0x" & instr.toHex(4) & ")"
  if op != 0b11 and not((op != 0b01 and rd == 15)): gba.cpu.stepThumb()

proc aluOps[op: static AluOp](gba: GBA, instr: uint32) =
  var shifterCarryOut = gba.cpu.cpsr.carry
  let
    rs = instr.bitsliced(3..5)
    rd = instr.bitsliced(0..2)
    op2 = gba.cpu.r[rs]
    op1 = gba.cpu.r[rd]
  let value = case op
    of AND: op1 and op2
    of EOR: op1 xor op2
    of LSL: lsl(op1, op2, shifterCarryOut)
    of LSR: lsr[false](op1, op2, shifterCarryOut)
    of ASR: asr[false](op1, op2, shifterCarryOut)
    of ADC: gba.cpu.adc(op1, op2, true)
    of SBC: gba.cpu.sbc(op1, op2, true)
    of ROR: ror[false](op1, op2, shifterCarryOut)
    of TST: op1 and op2
    of NEG: gba.cpu.sub(0, op2, true)
    of CMP: gba.cpu.sub(op1, op2, true)
    of CMN: gba.cpu.add(op1, op2, true)
    of ORR: op1 or op2
    of MUL: op1 * op2
    of BIC: op1 and not(op2)
    of MVN: not(op2)
  when op notin {TST, CMP, CMN}: gba.cpu.r[rd] = value
  when op in {LSL, LSR, ASR, ROR}: gba.cpu.cpsr.carry = shifterCarryOut # carry barrel shifter
  when op notin {ADC, SBC, NEG, CMP, CMN}: gba.cpu.setNegAndZeroFlags(value) # already handled
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
    value = shift[true](op, gba.cpu.r[rs], offset, shifterCarryOut) # op 0b11 encodes thumb add/subtract
  gba.cpu.r[rd] = value
  gba.cpu.cpsr.carry = shifterCarryOut
  gba.cpu.setNegAndZeroFlags(value)
  gba.cpu.stepThumb()

macro lutBuilder(): untyped =
  result = newTree(nnkBracket)
  for i in 0'u32 ..< 1024'u32:
    result.add:
      checkBits i:
      of "1111......": call("longBranchLink", i.bit(5))
      of "11100.....": call("unconditionalBranch")
      of "11011111..": call("softwareInterrupt")
      of "1101......": call("conditionalBranch", i.bitsliced(2..5))
      of "1100......": call("multipleLoadStore", i.bit(5), i.bitsliced(2..4))
      of "1011.10...": call("pushPop", i.bit(5), i.bit(2))
      of "10110000..": call("addToStackPointer", i.bit(1))
      of "1010......": call("loadAddress", i.bit(5), i.bitsliced(2..4))
      of "1001......": call("spRelativeLoadStore", i.bit(5), i.bitsliced(2..4))
      of "1000......": call("loadStoreHalfword", i.bit(5), i.bitsliced(0..4))
      of "011.......": call("loadStoreImmOffset", i.bitsliced(5..6), i.bitsliced(0..4))
      of "0101..1...": call("loadStoreSignExtended", i.bitsliced(4..5), i.bitsliced(0..2))
      of "0101..0...": call("loadStoreRegOffset", i.bitsliced(4..5), i.bitsliced(0..2))
      of "01001.....": call("pcRelativeLoad", i.bitsliced(2..4))
      of "010001....": call("highRegOps", i.bitsliced(2..3), i.bit(1), i.bit(0))
      of "010000....": call("aluOps", AluOp(i.bitsliced(0..4)))
      of "001.......": call("moveCompareAddSubtract", i.bitsliced(5..6), i.bitsliced(2..4))
      of "00011.....": call("addSubtract", i.bit(4), i.bit(3), i.bitsliced(0..2))
      of "000.......": call("moveShiftedReg", i.bitsliced(5..6), i.bitsliced(0..4))
      else:            call("unimplemented")

const lut = lutBuilder()

proc execThumb*(gba: GBA, instr: uint32) =
  lut[instr shr 6](gba, instr)

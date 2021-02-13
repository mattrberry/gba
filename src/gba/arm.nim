import bitops, strutils

import macros, types

proc unimplemented(instr: Word) =
  echo "Unimplemented opcode: 0x" & instr.toHex(8)
  quit 1

proc multiply[accumulate, set_cond: static bool](instr: Word) =
  echo "Unimplemented instruction: Multiply<" & $accumulate & "," & $set_cond & ">(0x" & instr.toHex(8) & ")"

proc multiply_long[signed, accumulate, set_cond: static bool](instr: Word) =
  echo "Unimplemented instruction: MultipleLong<" & $signed & "," & $accumulate & "," & $set_cond & ">(0x" & instr.toHex(8) & ")"

proc single_data_swap[word: static bool](instr: Word) =
  echo "Unimplemented instruction: SingleDataSwap<" & $instr & ">(0x" & instr.toHex(8) & ")"

proc branch_exchange(instr: Word) =
  echo "Unimplemented instruction: BranchExchange<>(0x" & instr.toHex(8) & ")"

proc halfword_data_transfer[pre, add, immediate, writeback, load: static bool, op: static int](instr: Word) =
  echo "Unimplemented instruction: HalfwordDataTransfer<" & $pre & "," & $add & "," & $immediate & "," & $writeback & "," & $load & "," & $op & ">(0x" & instr.toHex(8) & ")"

proc single_data_transfer[immediate, pre, add, word, writeback, load: static bool](instr: Word) =
  echo "Unimplemented instruction: SingleDataTransfer<" & $immediate & "," & $pre & "," & $add & "," & $word & "," & $writeback & "," & $load & ">(0x" & instr.toHex(8) & ")"

proc block_data_transfer[pre, add, psr_user, writeback, load: static bool](instr: Word) =
  echo "Unimplemented instruction: BlockDataTransfer<" & $pre & "," & $add & "," & $psr_user & "," & $writeback & "," & $load & ">(0x" & instr.toHex(8) & ")"

proc branch[link: static bool](instr: Word) =
  echo "Unimplemented instruction: Branch<" & $link & ">(0x" & instr.toHex(8) & ")"

proc software_interrupt(instr: Word) =
  echo "Unimplemented instruction: SoftwareInterrupt<>(0x" & instr.toHex(8) & ")"

proc data_processing[immediate: static bool, op: static int, set_cond: static bool](instr: Word) =
  echo "Unimplemented instruction: DataProcessing<" & $immediate & "," & $op & "," & $set_cond & ">(0x" & instr.toHex(8) & ")"

const lut* = block:
  echo "Filling LUT..."
  var tmp: array[4096, Instruction]
  staticFor i, 0, tmp.len:
    if (i and 0b111111001111) == 0b000000001001:
      tmp[i] = multiply[i.testBit(5), i.testBit(4)]
    elif (i and 0b111110001111) == 0b000010001001:
      tmp[i] = multiply_long[i.testBit(6), i.testBit(5), i.testBit(4)]
    elif (i and 0b111110111111) == 0b000100001001:
      tmp[i] = single_data_swap[i.testBit(6)]
    elif (i and 0b111111111111) == 0b000100100001:
      tmp[i] = branch_exchange
    elif (i and 0b111000001001) == 0b000000001001:
      tmp[i] = halfword_data_transfer[i.testBit(8), i.testBit(7), i.testBit(6), i.testBit(5), i.testBit(4), (i shr 1) and 0b11]
    elif (i and 0b111000000001) == 0b011000000001:
      discard # undefined instruction
    elif (i and 0b110000000000) == 0b010000000000:
      tmp[i] = single_data_transfer[i.testBit(9), i.testBit(8), i.testBit(7), i.testBit(6), i.testBit(5), i.testBit(4)]
    elif (i and 0b111000000000) == 0b100000000000:
      tmp[i] = block_data_transfer[i.testBit(8), i.testBit(7), i.testBit(6), i.testBit(5), i.testBit(4)]
    elif (i and 0b111000000000) == 0b101000000000:
      tmp[i] = branch[i.testBit(8)]
    elif (i and 0b111000000000) == 0b110000000000:
      discard # coprocessor data transfer
    elif (i and 0b111100000001) == 0b111000000000:
      discard # coprocessor data operation
    elif (i and 0b111100000001) == 0b111000000001:
      discard # coprocessor register transfer
    elif (i and 0b111100000000) == 0b111100000000:
      tmp[i] = software_interrupt
    elif (i and 0b110000000000) == 0b000000000000:
      tmp[i] = data_processing[i.testBit(9), (i shr 5) and 0xF, i.testBit(4)]
    else:
      tmp[i] = unimplemented
  tmp

proc exec_arm*(instr: Word) =
    lut[((instr shr 16) and 0x0FF0) or ((instr shr 4) and 0xF)](instr)


import bitops, strutils

import gba/[macros, types]

proc unimplemented(instr: Word) =
  echo "Unimplemented opcode: 0x" & instr.toHex(8)
  quit 1

template multiply(accumulate, set_cond: static bool): Instruction =
  proc `multiply accumulate set_cond`(instr: Word) =
    echo "Unimplemented instruction: Multiply<" & $accumulate & "," & $set_cond & ">(0x" & instr.toHex(8) & ")"
    discard
  `multiply accumulate set_cond`

template multiply_long(signed, accumulate, set_cond: static bool): Instruction =
  proc `multiply_long signed accumulate set_cond`(instr: Word) =
    echo "Unimplemented instruction: MultipleLong<" & $signed & "," & $accumulate & "," & $set_cond & ">(0x" & instr.toHex(8) & ")"
    discard
  `multiply_long signed accumulate set_cond`

template single_data_swap(word: static bool): Instruction =
  proc `single_data_swap word`(instr: Word) =
    echo "Unimplemented instruction: SingleDataSwap<" & $instr & ">(0x" & instr.toHex(8) & ")"
    discard
  `single_data_swap word`

proc branch_exchange(instr: Word) =
  echo "Unimplemented instruction: BranchExchange<>(0x" & instr.toHex(8) & ")"
  discard

template halfword_data_transfer(pre, add, immediate, writeback, load: static bool, op: static int): Instruction =
  proc `halfword_data_transfer pre add immediate write_back load op`(instr: Word) =
    echo "Unimplemented instruction: HalfwordDataTransfer<" & $pre & "," & $add & "," & $immediate & "," & $writeback & "," & $load & "," & $op & ">(0x" & instr.toHex(8) & ")"
    discard
  `halfword_data_transfer pre add immediate write_back load op`

template single_data_transfer(immediate, pre, add, word, writeback, load: static bool): Instruction =
  proc `single_data_transfer immediate pre add word writeback load`(instr: Word) =
    echo "Unimplemented instruction: SingleDataTransfer<" & $immediate & "," & $pre & "," & $add & "," & $word & "," & $writeback & "," & $load & ">(0x" & instr.toHex(8) & ")"
    discard
  `single_data_transfer immediate pre add word writeback load`

template block_data_transfer(pre, add, psr_user, writeback, load: static bool): Instruction =
  proc `block_data_transfer pre add psr_user writeback load`(instr: Word) =
    echo "Unimplemented instruction: BlockDataTransfer<" & $pre & "," & $add & "," & $psr_user & "," & $writeback & "," & $load & ">(0x" & instr.toHex(8) & ")"
    discard
  `block_data_transfer pre add psr_user writeback load`

template branch(link: static bool): Instruction =
  proc `branch link`(instr: Word) =
    echo "Unimplemented instruction: Branch<" & $link & ">(0x" & instr.toHex(8) & ")"
    discard
  `branch link`

proc software_interrupt(instr: Word) =
  echo "Unimplemented instruction: SoftwareInterrupt<>(0x" & instr.toHex(8) & ")"
  discard

const lut = block:
  echo "Filling LUT..."
  var tmp: array[4096, Instruction]
  staticFor i, 0, tmp.len:
    if (i and 0b111111001111) == 0b000000001001:
      tmp[i] = multiply(i.testBit(5), i.testBit(4))
    elif (i and 0b111110001111) == 0b000010001001:
      tmp[i] = multiply_long(i.testBit(6), i.testBit(5), i.testBit(4))
    elif (i and 0b111110111111) == 0b000100001001:
      tmp[i] = single_data_swap(i.testBit(6))
    elif (i and 0b111111111111) == 0b000100100001:
      tmp[i] = branch_exchange
    elif (i and 0b111000001001) == 0b000000001001:
      tmp[i] = halfword_data_transfer(i.testBit(8), i.testBit(7), i.testBit(6), i.testBit(5), i.testBit(4), (i shr 1) and 0b11)
    elif (i and 0b111000000001) == 0b011000000001:
      discard # undefined instruction
    elif (i and 0b110000000000) == 0b010000000000:
      tmp[i] = single_data_transfer(i.testBit(9), i.testBit(8), i.testBit(7), i.testBit(6), i.testBit(5), i.testBit(4))
    elif (i and 0b111000000000) == 0b100000000000:
      tmp[i] = block_data_transfer(i.testBit(8), i.testBit(7), i.testBit(6), i.testBit(5), i.testBit(4))
    elif (i and 0b111000000000) == 0b101000000000:
      tmp[i] = branch(i.testBit(8))
    elif (i and 0b111000000000) == 0b110000000000:
      discard # coprocessor data transfer
    elif (i and 0b111100000001) == 0b111000000000:
      discard # coprocessor data operation
    elif (i and 0b111100000001) == 0b111000000001:
      discard # coprocessor register transfer
    elif (i and 0b111100000000) == 0b111100000000:
      tmp[i] = software_interrupt
    else:
      tmp[i] = unimplemented
  tmp

lut[0b000000001001](0xDEADBEEF'u32)
lut[0b000101011101](0x00C0FFEE'u32)

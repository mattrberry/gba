import strutils

import gba/[macros, types]

proc unimplemented(value: Word) =
  echo "Unimplemented opcode: 0x" & value.toHex(8)
  quit 1

template branch(foo: static int): Instruction =
  proc `branch foo`(value: Word) =
    if foo mod 2 == 0:
      echo "even,value:", value
    else:
      echo "odd,value:", value
  `branch foo`

const lut = block:
  echo "Filling LUT..."
  var tmp: array[4096, Instruction]
  staticFor i, 0, tmp.len:
    tmp[i] = unimplemented
    if (i and 0b111000000000) == 0b101000000000:
      tmp[i] = branch(i)
  tmp

lut[0b101000000000](0xDEADBEEF'u32)
lut[0b101000000001](0xDEADBEEF'u32)
lut[0b000000000000](0xDEADBEEF'u32)

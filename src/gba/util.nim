proc signExtend*[T: SomeUnsignedInt](value: T, bit: int): T =
  if value.testBit(bit):
    result = value or (high(typeof(value)) shl bit)
  else:
    result = value

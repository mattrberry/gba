proc bitTest*(value: SomeUnsignedInt, bit: SomeInteger): bool {.inline.} = bool((value shr bit) and 1)

proc signExtend*[T: SomeUnsignedInt](value: T, bit: int): T =
  if value.bitTest(bit):
    result = value or (high(typeof(value)) shl bit)
  else:
    result = value

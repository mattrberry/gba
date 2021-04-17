proc bitTest*(value: SomeUnsignedInt, bit: SomeInteger): bool {.inline.} = bool((value shr bit) and 1)

proc signExtend*[T: SomeUnsignedInt](value: T, bit: int): T =
  if value.bitTest(bit):
    result = value or (high(typeof(value)) shl bit)
  else:
    result = value

proc `<<`*[T: SomeUnsignedInt](value: T, count: SomeUnsignedInt): T

# Right shift operator supporting negative and large shift amounts
proc `>>`*[T: SomeUnsignedInt](value: T, count: SomeUnsignedInt): T =
  if likely(count < sizeof(T) * 8): value shr count
  else: 0

# Left shift operator supporting negative and large shift amounts
proc `<<`*[T: SomeUnsignedInt](value: T, count: SomeUnsignedInt): T =
  if likely(count < sizeof(T) * 8): value shl count
  else: 0

proc bitTest*(value: SomeUnsignedInt, bit: SomeInteger): bool {.inline.} = bool((value shr bit) and 1)

proc signExtend*(T: typedesc, value, bit: SomeUnsignedInt): T =
  result = cast[T](value)
  if value.bitTest(bit): result = result or (high(T) shl bit)

proc `<<`*[T: SomeUnsignedInt](value: T, count: SomeUnsignedInt): T

# Right shift operator supporting negative and large shift amounts
proc `>>`*[T: SomeUnsignedInt](value: T, count: SomeUnsignedInt): T =
  if likely(count < sizeof(T) * 8): value shr count
  else: 0

# Left shift operator supporting negative and large shift amounts
proc `<<`*[T: SomeUnsignedInt](value: T, count: SomeUnsignedInt): T =
  if likely(count < sizeof(T) * 8): value shl count
  else: 0

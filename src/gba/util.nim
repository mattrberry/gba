func `<<`*[T: SomeUnsignedInt](value: T, count: SomeUnsignedInt): T

# Right shift operator supporting negative and large shift amounts
func `>>`*[T: SomeUnsignedInt](value: T, count: SomeUnsignedInt): T =
  if likely(count < sizeof(T) * 8): value shr count
  else: 0

# Left shift operator supporting negative and large shift amounts
func `<<`*[T: SomeUnsignedInt](value: T, count: SomeUnsignedInt): T =
  if likely(count < sizeof(T) * 8): value shl count
  else: 0

func bit*(value, bit: SomeUnsignedInt): bool {.inline.} = bool((value >> bit) and 1)

func signExtend*(T: typedesc, value, bit: SomeUnsignedInt): T =
  result = cast[T](value)
  if value.bit(bit): result = result or (high(T) shl bit)

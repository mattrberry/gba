func `<<`*[T: SomeUnsignedInt](value: T, count: Natural): T

# Right shift operator supporting negative and large shift amounts
func `>>`*[T: SomeUnsignedInt](value: T, count: Natural): T =
  if likely(count < sizeof(T) * 8): value shr count
  else: 0

# Left shift operator supporting negative and large shift amounts
func `<<`*[T: SomeUnsignedInt](value: T, count: Natural): T =
  if likely(count < sizeof(T) * 8): value shl count
  else: 0

func bit*(value: SomeUnsignedInt, bit: Natural): bool {.inline.} = bool((value >> bit) and 1)

func signExtend*(T: typedesc, value: SomeUnsignedInt, bit: Natural): T =
  result = cast[T](value)
  if value.bit(bit): result = result or (high(T) shl bit)

# pointer arithmetic
func `+`[T](p: ptr T, offset: int): ptr T {.inline.} = cast[ptr T](cast[int](p) + offset * sizeof(T))
func `[]`[T](p: ptr T, offset: int): T {.inline.} = (p + offset)[]
func `[]=`[T](p: ptr T, offset: int, val: T) {.inline.} = (p + offset)[] = val

func read*[K](T: typedesc, val: openarray[K], a, b: SomeInteger): T {.inline.} =
  cast[ptr T](cast[ptr K](unsafeAddr(val)) + a.int)[b.int]

func write*[K](T: typedesc, val: openarray[K], a, b: SomeInteger, value: any) {.inline.} =
  cast[ptr T](cast[ptr K](unsafeAddr(val)) + a.int)[b.int] = cast[T](value)

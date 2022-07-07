import posix
import times

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

func signExtend*[T: SomeUnsignedInt](value: SomeUnsignedInt, bit: Natural): T =
  result = cast[T](value)
  if value.bit(bit): result = result or (high(T) shl bit)

# pointer arithmetic
func `+`*[T](p: ptr T, offset: int): ptr T {.inline.} = cast[ptr T](cast[int](p) + offset * sizeof(T))
func `[]`*[T](p: ptr T, offset: int): T {.inline.} = (p + offset)[]
func `[]=`*[T](p: ptr T, offset: int, val: T) {.inline.} = (p + offset)[] = val

func read*[T: SomeUnsignedInt](val: openarray[auto], a, b: SomeInteger): T {.inline.} =
  cast[ptr T](unsafeAddr(val[a.int]))[b.int]

func write*[T: SomeUnsignedInt](val: openarray[auto], a, b: SomeInteger, value: T) {.inline.} =
  cast[ptr T](unsafeAddr(val[a.int]))[b.int] = value

func readByte*(val: SomeUnsignedInt, pos: SomeInteger): uint8 =
  cast[uint8](val shr (pos * 8))

func writeByte*[T: SomeUnsignedInt](val: var T, pos: SomeInteger, b: byte) =
  let
    shift = pos * 8
    mask = not(cast[T](0xFF) shl shift)
    toWrite = cast[T](b) shl shift
  val = (val and mask) or toWrite

proc nanosleep(nanoseconds: SomeInteger) =
  var a, b: Timespec
  a.tv_nsec = int(nanoseconds)
  discard posix.nanosleep(a, b)

const nanosPerFrame = 1_000_000_000 div 60
var lastTime = times.getTime()
proc sleepUntilEndOfFrame*() =
  let
    currentTime = times.getTime()
    duration = nanosPerFrame - (currentTime - lastTime).inNanoseconds()
  if duration > 0:
    var a, b: Timespec
    a.tv_nsec = int(duration)
    discard posix.nanosleep(a, b)
  lastTime = times.getTime()

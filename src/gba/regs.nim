type
  Reg16 = KeypadRegs | PPURegs

  KeypadRegs = KEYINPUT | KEYCNT

  KEYINPUT* = object
    a* {.bitsize:1.}: bool
    b* {.bitsize:1.}: bool
    select* {.bitsize:1.}: bool
    start* {.bitsize:1.}: bool
    right* {.bitsize:1.}: bool
    left* {.bitsize:1.}: bool
    up* {.bitsize:1.}: bool
    down* {.bitsize:1.}: bool
    r* {.bitsize:1.}: bool
    l* {.bitsize:1.}: bool
    notUsed* {.bitsize:6.}: cuint

  KEYCNT* = object
    a* {.bitsize:1.}: bool
    b* {.bitsize:1.}: bool
    select* {.bitsize:1.}: bool
    start* {.bitsize:1.}: bool
    right* {.bitsize:1.}: bool
    left* {.bitsize:1.}: bool
    up* {.bitsize:1.}: bool
    down* {.bitsize:1.}: bool
    r* {.bitsize:1.}: bool
    l* {.bitsize:1.}: bool
    notUsed* {.bitsize:4.}: cuint
    irqEnable* {.bitsize:1.}: bool
    irqCondition* {.bitsize:1.}: bool

  PPURegs = DISPCNT | DISPSTAT

  DISPCNT* = object
    mode* {.bitsize:3.}: cuint
    cgbMode* {.bitsize:1.}: bool
    page* {.bitsize:1.}: bool
    hblankOam* {.bitsize:1.}: bool
    obj1d* {.bitsize:1.}: bool
    forceBlank* {.bitsize:1.}: bool
    controlBits* {.bitsize:5.}: cuint
    window0* {.bitsize:1.}: bool
    window1* {.bitsize:1.}: bool
    windowObj* {.bitsize:1.}: bool

  DISPSTAT* = object
    vblank* {.bitsize:1.}: bool
    hblank* {.bitsize:1.}: bool
    vcount* {.bitsize:1.}: bool
    vblankEnable* {.bitsize:1.}: bool
    hblankEnable* {.bitsize:1.}: bool
    vcountEnable* {.bitsize:1.}: bool
    notUsed* {.bitsize:2.}: cuint
    vcountTarget* {.bitsize:8.}: cuint

converter toU16(reg: Reg16): uint16 = cast[uint16](reg)
converter toReg16[T: Reg16](num: uint16): T = cast[T](num)
proc put(reg: var Reg16, b: uint16) {.inline.} = reg = b.toReg16[: reg.type]

proc read*(reg: Reg16, byteNum: SomeInteger): uint8 =
  result = uint8((toU16(reg) shr (8 * byteNum)) and 0xFF)

proc write*(reg: var Reg16, value: uint8, byteNum: SomeInteger) =
  let
    shift = 8 * byteNum
    mask = not(0xFF'u16 shl shift)
  reg.put ((mask and toU16(reg)) or (value shl shift))

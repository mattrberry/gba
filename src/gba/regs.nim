type
  Reg16 = PPURegs | DMARegs | KeypadRegs | MiscRegs

  PPURegs = DISPCNT | DISPSTAT | BGCNT | BGOFS

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

  BGCNT* = object
    priority* {.bitsize:2.}: cuint
    charBase* {.bitsize:2.}: cuint
    notUsed* {.bitsize:2.}: cuint
    mosaic* {.bitsize:1.}: bool
    colorMode* {.bitsize:1.}: bool
    screenBase* {.bitsize:5.}: cuint
    affineWrap* {.bitsize:1.}: bool
    screenSize* {.bitsize:2.}: cuint

  BGOFS* = object
    offset* {.bitsize:9.}: cuint
    notUsed* {.bitsize:7.}: cuint

  DMARegs = DMACNT

  DMACNT* = object
    notUsed* {.bitsize:5.}: cuint
    dstCtrl* {.bitsize:2.}: cuint
    srcCtrl* {.bitsize:2.}: cuint
    repeat* {.bitsize:1.}: bool
    word* {.bitsize:1.}: bool
    gamepak* {.bitsize:1.}: bool
    timing* {.bitsize:2.}: cuint
    irq* {.bitsize:1.}: bool
    enable* {.bitsize:1.}: bool

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

  MiscRegs = INTERRUPT | WAITCNT

  INTERRUPT* = object
    vblank* {.bitsize:1.}: bool
    hblank* {.bitsize:1.}: bool
    vcount* {.bitsize:1.}: bool
    timer0* {.bitsize:1.}: bool
    timer1* {.bitsize:1.}: bool
    timer2* {.bitsize:1.}: bool
    timer3* {.bitsize:1.}: bool
    serial* {.bitsize:1.}: bool
    dma0* {.bitsize:1.}: bool
    dma1* {.bitsize:1.}: bool
    dma2* {.bitsize:1.}: bool
    dma3* {.bitsize:1.}: bool
    keypad* {.bitsize:1.}: bool
    gamepak* {.bitsize:1.}: bool
    notUsed* {.bitsize:2.}: cuint

  WAITCNT* = object
    sramWaitControl* {.bitsize:2.}: cuint
    waitState0FirstAccess* {.bitsize:2.}: cuint
    waitState0SecondAccess* {.bitsize:1.}: cuint
    waitState1FirstAccess* {.bitsize:2.}: cuint
    waitState1SecondAccess* {.bitsize:1.}: cuint
    waitState2FirstAccess* {.bitsize:2.}: cuint
    waitState2SecondAccess* {.bitsize:1.}: cuint
    phiTerminalOutput* {.bitsize:2.}: cuint
    notUsed* {.bitsize:1.}: bool
    gamepackPrefetchBuffer* {.bitsize:1.}: bool
    gamepackTypeFlag* {.bitsize:1.}: bool

converter toU16*(reg: Reg16): uint16 = cast[uint16](reg)
converter toReg16*[T: Reg16](num: uint16): T = cast[T](num)
proc put(reg: var Reg16, b: uint16) {.inline.} = reg = b.toReg16[: reg.type]

proc read*(reg: Reg16, byteNum: SomeInteger): uint8 =
  uint8((toU16(reg) shr (8 * byteNum)) and 0xFF)

proc write*(reg: var Reg16, value: uint8, byteNum: SomeInteger) =
  let
    shift = 8 * byteNum
    mask = not(0xFF'u16 shl shift)
  reg.put ((mask and toU16(reg)) or (value.uint16 shl shift))

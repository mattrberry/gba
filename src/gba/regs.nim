type
  ColorEffect* = enum
    none, blend, bright, dark

  DmaAddressControl* = enum
    increment, decrement, fixed, reload

  DmaChunkSize* = enum
    halfword, word

  DmaStartTiming* = enum
    immediate, vblank, hblank, special

type
  Reg16 = PPURegs | DMARegs | TimerRegs | KeypadRegs | MiscRegs

  PPURegs = DISPCNT | DISPSTAT | BGCNT | BGOFS | WINBOUND | WININ | WINOUT | MOSAIC | BLDCNT | BLDALPHA | BLDY

  DISPCNT* {.packed.} = object
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

  DISPSTAT* {.packed.} = object
    vblank* {.bitsize:1.}: bool
    hblank* {.bitsize:1.}: bool
    vcount* {.bitsize:1.}: bool
    vblankEnable* {.bitsize:1.}: bool
    hblankEnable* {.bitsize:1.}: bool
    vcountEnable* {.bitsize:1.}: bool
    notUsed* {.bitsize:2.}: cuint
    vcountTarget* {.bitsize:8.}: cuint

  BGCNT* {.packed.} = object
    priority* {.bitsize:2.}: cuint
    charBase* {.bitsize:2.}: cuint
    notUsed* {.bitsize:2.}: cuint
    mosaic* {.bitsize:1.}: bool
    colorMode* {.bitsize:1.}: bool
    screenBase* {.bitsize:5.}: cuint
    affineWrap* {.bitsize:1.}: bool
    screenSize* {.bitsize:2.}: cuint

  BGOFS* {.packed.} = object
    offset* {.bitsize:9.}: cuint
    notUsed* {.bitsize:7.}: cuint

  WINBOUND* {.packed.} = object
    endPos* {.bitsize:8.}: cuint
    startPos* {.bitsize:8}: cuint

  WININ* {.packed.} = object
    win0enable* {.bitsize:5.}: cuint
    win0effects* {.bitsize:1.}: bool
    notUsed1* {.bitsize:2.}: cuint
    win1enable* {.bitsize:5.}: cuint
    win1effects* {.bitsize:1.}: bool
    notUsed2* {.bitsize:2}: cuint

  WINOUT* {.packed.} = object
    winOutEnable* {.bitsize:5.}: cuint
    winOutEffects* {.bitsize:1.}: bool
    notUsed1* {.bitsize:2.}: cuint
    winObjEnable* {.bitsize:5.}: cuint
    winObjEffects* {.bitsize:1.}: bool
    notUsed2* {.bitsize:2.}: cuint

  MOSAIC* {.packed.} = object
    bgHSize* {.bitsize:4.}: cuint
    bgVSize* {.bitsize:4.}: cuint
    objHSize* {.bitsize:4.}: cuint
    objVSize* {.bitsize:4.}: cuint

  BLDCNT* {.packed.} = object # Probably can make a set aswell
    bg0First* {.bitsize:1.}: bool
    bg1First* {.bitsize:1.}: bool
    bg2First* {.bitsize:1.}: bool
    bg3First* {.bitsize:1.}: bool
    objFirst* {.bitsize:1.}: bool
    bdFirst* {.bitsize:1.}: bool
    effect* {.bitsize:2.}: ColorEffect
    bg0Second* {.bitsize:1.}: bool
    bg1Second* {.bitsize:1.}: bool
    bg2Second* {.bitsize:1.}: bool
    bg3Second* {.bitsize:1.}: bool
    objSecond* {.bitsize:1.}: bool
    bdSecond* {.bitsize:1.}: bool
    notUsed* {.bitsize:2.}: cuint

  BLDALPHA* {.packed.} = object
    eva* {.bitsize:5.}: cuint
    notUsed1* {.bitsize:3.}: cuint
    evb* {.bitsize:5.}: cuint
    notUsed2* {.bitsize:3.}: cuint

  BLDY* {.packed.} = object
    evy* {.bitsize:5.}: cuint
    notUsed {.bitsize:11.}: cuint

  DMARegs = DMACNT

  DMACNT* {.packed.} = object
    notUsed* {.bitsize:5.}: cuint
    dstCtrl* {.bitsize:2.}: DmaAddressControl
    srcCtrl* {.bitsize:2.}: DmaAddressControl
    repeat* {.bitsize:1.}: bool
    transfer* {.bitsize:1.}: DmaChunkSize
    gamepak* {.bitsize:1.}: bool
    timing* {.bitsize:2.}: DmaStartTiming
    irq* {.bitsize:1.}: bool
    enable* {.bitsize:1.}: bool

  TimerRegs = TMCNT

  TMCNT* {.packed.} = object
    freq* {.bitsize:2}: cuint
    cascade* {.bitsize:1.}: bool
    notUsed1* {.bitsize:3.}: cuint
    irq* {.bitsize:1.}: bool
    enable* {.bitsize:1.}: bool
    notUsed2* {.bitsize:8.}: cuint

  KeypadRegs = KeyInputs | KEYCNT

  KeyInput* = enum
    a
    b
    select
    start
    right
    left
    up
    down
    r
    l

  KeyInputs* = set[KeyInput]

  KEYCNT* {.packed.} = object
    inputs: KeyInputs
    notUsed* {.bitsize:4.}: cuint
    irqEnable* {.bitsize:1.}: bool
    irqCondition* {.bitsize:1.}: bool

  MiscRegs = InterruptFlags | WAITCNT

  Interrupt* = enum
    vblank
    hblank
    vcount
    timer0
    timer1
    timer2
    timer3
    serial
    dma0
    dma1
    dma2
    dma3
    keypad
    gamepak

  InterruptFlags* = set[Interrupt]

  WAITCNT* {.packed.} = object
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
  cast[uint8]((toU16(reg) shr (8 * byteNum)))

proc write*(reg: var Reg16, value: uint8, byteNum: SomeInteger) =
  let
    shift = 8 * byteNum
    mask = not(0xFF'u16 shl shift)
  reg.put ((mask and toU16(reg)) or (value.uint16 shl shift))

proc read*[T: uint16 | uint32](reg: T, byteNum: SomeInteger): uint8 =
  cast[uint8](reg shr (8 * byteNum))

proc write*[T: uint16 | uint32](reg: var T, value: uint8, byteNum: SomeInteger) =
  let
    shift = 8 * byteNum
    mask = not(0xFF.T shl shift)
  reg = (mask and reg) or (value.T shl shift)

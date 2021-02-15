type
  Instruction* = proc(value: uint32)

type
  GBA* = ref object
    bus*: Bus
    cpu*: CPU

  Bus* = ref object
    gba*: GBA
    bios*: array[0x4000, uint8]
    iwram*: array[0x40000, uint8]
    ewram*: array[0x08000, uint8]
    rom*: array[0x02000000, uint8]

  CPU* = ref object
    gba*: GBA
    r*: array[16, uint32]
    cpsr*: PSR
    spsr*: PSR

  Mode* = enum
    usr = 0b10000
    fiq = 0b10001
    irq = 0b10010
    svc = 0b10011
    abt = 0b10111
    und = 0b11011
    sys = 0b11111

  PSR* = object
    mode* {.bitsize:5.}: Mode
    thumb* {.bitsize:1.}: bool
    fiq_disable* {.bitsize:1.}: bool
    irq_disable* {.bitsize:1.}: bool
    reserved* {.bitsize:20.}: cuint
    overflow*{.bitsize:1.}: bool
    carry* {.bitsize:1.}: bool
    zero* {.bitsize:1.}: bool
    negative* {.bitsize:1.}: bool

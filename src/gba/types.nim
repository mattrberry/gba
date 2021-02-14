type
  Word* = uint32
  Instruction* = proc(value: Word)

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
    r*: array[16, Word]
import bitops, strutils, types

proc newBus*(gba: GBA, bios: openarray[byte]): Bus =
  new result
  result.gba = gba
  for i in 0 ..< bios.len:
    result.bios[i] = bios[i]

proc newBus*(gba: GBA, biosPath, romPath: string): Bus =
  new result
  result.gba = gba
  for i in 0 ..< result.rom.len:
    var oob = 0xFFFF and (i shr 1)
    result.rom[i] = uint8((oob shr (8 * (i and 1))))
  var
    biosFile = open(biosPath)
    romFile = open(romPath)
  discard readBytes(biosFile, result.bios, 0, len(result.bios))
  discard readBytes(romFile, result.rom, 0, len(result.rom))
  close(biosFile)
  close(romFile)

proc `[]`(bus: Bus, index: uint32): uint8 =
  result = case bitsliced(index, 24..27)
    of 0x0: bus.bios[index and 0x3FFF]
    of 0x2: bus.iwram[index and 0x3FFFF]
    of 0x3: bus.ewram[index and 0x7FFF]
    of 0x8, 0x9,
       0xA, 0xB,
       0xC, 0xD: bus.rom[index and 0x01FFFFFF]
    else: quit "Unmapped read: " & index.toHex(8)

proc readWord*(bus: Bus, index: uint32): uint32 =
  let aligned = index.clearMasked(3)
  bus[aligned].uint32 or
    (bus[aligned + 1].uint32 shl 8) or
    (bus[aligned + 2].uint32 shl 16) or
    (bus[aligned + 3].uint32 shl 24)
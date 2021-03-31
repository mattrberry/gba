import bitops, strutils

import types

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

proc `[]`*(bus: Bus, index: uint32): uint8 =
  result = case bitsliced(index, 24..27)
    of 0x0: bus.bios[index and 0x3FFF]
    of 0x2: bus.iwram[index and 0x3FFFF]
    of 0x3: bus.ewram[index and 0x7FFF]
    of 0x5: bus.gba.ppu.pram[index and 0x3FF]
    of 0x6:
      var address = index and 0x1FFFF
      if address > 0x17FFF: address -= 0x8000
      bus.gba.ppu.vram[address]
    of 0x7: bus.gba.ppu.oam[index and 0x3FF]
    of 0x8, 0x9,
       0xA, 0xB,
       0xC, 0xD: bus.rom[index and 0x01FFFFFF]
    else: quit "Unmapped read: " & index.toHex(8)

proc readHalfSlow(bus: Bus, index: uint32): uint16 =
  bus[index].uint16 or (bus[index + 1].uint16 shl 8)

proc readHalf*(bus: Bus, index: uint32): uint16 =
  let aligned = index.clearMasked(1)
  result = case index.bitsliced(24..27)
    of 0x0: cast[ptr uint16](addr bus.bios[aligned and 0x3FFF])[]
    of 0x2: cast[ptr uint16](addr bus.iwram[aligned and 0x3FFFF])[]
    of 0x3: cast[ptr uint16](addr bus.ewram[index and 0x7FFF])[]
    of 0x5: cast[ptr uint16](addr bus.gba.ppu.pram[aligned and 0x3FF])[]
    of 0x6:
      var address = aligned and 0x1FFFF
      if address > 0x17FFF: address -= 0x8000
      cast[ptr uint16](addr bus.gba.ppu.vram[address])[]
    of 0x7: cast[ptr uint16](addr bus.gba.ppu.oam[aligned and 0x3FF])[]
    of 0x8, 0x9,
       0xA, 0xB,
       0xC, 0xD: cast[ptr uint16](addr bus.rom[aligned and 0x01FFFFFF])[]
    else: quit "Unmapped read: " & aligned.toHex(8)

proc readHalfRotate*(bus: Bus, index: SomeInteger): uint32 =
  let
    half = bus.readHalf(index).uint32
    bits = (index and 1) shl 3
  result = (half shr bits) or (half shl (32 - bits))

proc readWordSlow(bus: Bus, index: uint32): uint32 =
  bus[index].uint32 or
    (bus[index + 1].uint32 shl 8) or
    (bus[index + 2].uint32 shl 16) or
    (bus[index + 3].uint32 shl 24)

proc readWord*(bus: Bus, index: uint32): uint32 =
  let aligned = index.clearMasked(3)
  result = case index.bitsliced(24..27)
    of 0x0: cast[ptr uint32](addr bus.bios[aligned and 0x3FFF])[]
    of 0x2: cast[ptr uint32](addr bus.iwram[aligned and 0x3FFFF])[]
    of 0x3: cast[ptr uint32](addr bus.ewram[index and 0x7FFF])[]
    of 0x5: cast[ptr uint32](addr bus.gba.ppu.pram[aligned and 0x3FF])[]
    of 0x6:
      var address = aligned and 0x1FFFF
      if address > 0x17FFF: address -= 0x8000
      cast[ptr uint32](addr bus.gba.ppu.vram[address])[]
    of 0x7: cast[ptr uint32](addr bus.gba.ppu.oam[aligned and 0x3FF])[]
    of 0x8, 0x9,
       0xA, 0xB,
       0xC, 0xD: cast[ptr uint32](addr bus.rom[aligned and 0x01FFFFFF])[]
    else: quit "Unmapped read: " & aligned.toHex(8)

proc readWordRotate*(bus: Bus, index: uint32): uint32 =
  let
    word = bus.readWord(index)
    bits = (index and 3) shl 3
  result = (word shr bits) or (word shl (32 - bits))

proc `[]=`*(bus: Bus, index: uint32, value: uint8) =
  case bitsliced(index, 24..27)
  of 0x2: bus.iwram[index and 0x3FFFF] = value
  of 0x3: bus.ewram[index and 0x7FFF] = value
  of 0x4: echo "Writing to I/O: " & index.toHex(8) & " ~> " & value.toHex(2)
  of 0x5: bus.gba.ppu.pram[index and 0x3FF] = value
  of 0x6:
    var address = index and 0x1FFFF
    if address > 0x17FFF: address -= 0x8000
    bus.gba.ppu.vram[address] = value
  of 0x7: bus.gba.ppu.oam[index and 0x3FF] = value
  else: quit "Unmapped write: " & index.toHex(8)

proc `[]=`*(bus: Bus, index: uint32, value: uint16) =
  let aligned = index.clearMasked(1)
  bus[aligned] = uint8(value)
  bus[aligned + 1] = uint8(value shr 8)

proc `[]=`*(bus: Bus, index: uint32, value: uint32) =
  let aligned = index.clearMasked(1)
  bus[aligned] = uint8(value)
  bus[aligned + 1] = uint8(value shr 8)
  bus[aligned + 2] = uint8(value shr 16)
  bus[aligned + 3] = uint8(value shr 24)

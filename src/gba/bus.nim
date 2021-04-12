import bitops, strutils

import types, util, mmio

proc newBus*(gba: GBA, biosPath, romPath: string): Bus =
  new result
  result.gba = gba
  result.mmio = newMMIO(gba)
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

proc read*[T: uint8 | uint16 | uint32](bus: Bus, index: uint32): T =
  let aligned = index.clearMasked(sizeof(T) - 1) # uint32:3, uint16:1
  result = case index.bitsliced(24..27)
    of 0x0: cast[ptr T](addr bus.bios[aligned and 0x3FFF])[]
    of 0x2: cast[ptr T](addr bus.iwram[aligned and 0x3FFFF])[]
    of 0x3: cast[ptr T](addr bus.ewram[aligned and 0x7FFF])[]
    of 0x4:
      let mmioAddr = index and 0xFFFFFF
      when T is uint8: bus.mmio[mmioAddr]
      elif T is uint16: bus.mmio[mmioAddr].T or (bus.mmio[mmioAddr + 1].T shl 8)
      elif T is uint32: bus.mmio[mmioAddr].T or (bus.mmio[mmioAddr + 1].T shl 8) or
                        (bus.mmio[mmioAddr + 2].T shl 16) or (bus.mmio[mmioAddr + 3].T shl 24)
    of 0x5: cast[ptr T](addr bus.gba.ppu.pram[aligned and 0x3FF])[]
    of 0x6:
      var address = aligned and 0x1FFFF
      if address > 0x17FFF: address -= 0x8000
      cast[ptr T](addr bus.gba.ppu.vram[address])[]
    of 0x7: cast[ptr T](addr bus.gba.ppu.oam[aligned and 0x3FF])[]
    of 0x8, 0x9,
       0xA, 0xB,
       0xC, 0xD: cast[ptr T](addr bus.rom[aligned and 0x01FFFFFF])[]
    else: quit "Unmapped " & $T & " read: " & aligned.toHex(8)

proc `[]=`*[T: uint8 | uint16 | uint32](bus: Bus, index: uint32, value: T) =
  let aligned = index.clearMasked(sizeof(T) - 1) # uint32:3, uint16:1
  case bitsliced(index, 24..27)
  of 0x2: cast[ptr T](addr bus.iwram[aligned and 0x3FFFF])[] = value
  of 0x3: cast[ptr T](addr bus.ewram[aligned and 0x7FFF])[] = value
  of 0x4:
      let mmioAddr = index and 0xFFFFFF
      bus.mmio[mmioAddr] = cast[uint8](value)
      when T is uint16 or T is uint32:
        bus.mmio[mmioAddr + 1] = cast[uint8](value shr 8)
      when T is uint32:
        bus.mmio[mmioAddr + 2] = cast[uint8](value shr 16)
        bus.mmio[mmioAddr + 3] = cast[uint8](value shr 24)
  of 0x5: cast[ptr T](addr bus.gba.ppu.pram[aligned and 0x3FF])[] = value
  of 0x6:
    var address = aligned and 0x1FFFF
    if address > 0x17FFF: address -= 0x8000
    cast[ptr T](addr bus.gba.ppu.vram[address])[] = value
  of 0x7: cast[ptr T](addr bus.gba.ppu.oam[aligned and 0x3FF])[] = value
  else: quit "Unmapped " & $T & " write: " & index.toHex(8) & " -> " & value.toHex(sizeof(T) * 2)

proc readRotate*[T: uint16 | uint32](bus: Bus, index: uint32): uint32 =
  let
    value = bus.read[:T](index).uint32
    shift = (index and (sizeof(T) - 1)) shl 3
  result = (value shr shift) or (value shl (32 - shift))

# LDRSH Rd,[odd] --> LDRSB Rd,[odd] ;sign-expand BYTE value
proc readSigned*[T: uint8 | uint16](bus: Bus, index: uint32): uint32 =
  result = if T is uint8 or index.bitTest(0):
             signExtend(cast[uint32](bus.read[:uint8](index)), 7)
           else:
             signExtend(cast[uint32](bus.read[:uint16](index)), 15)

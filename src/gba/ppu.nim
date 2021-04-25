import bitops, strutils

import types, util, display, regs, scheduler

const
  width = 240
  height = 160

type
  Buffer[width, height: static int, T] = array[width * height, T]
  FrameBuffer = Buffer[width, height, uint16]
  Scanline = array[width, uint16]

var
  framebuffer: FrameBuffer
  layerBuffers: array[4, Scanline]

  dispcnt: DISPCNT
  dispstat: DISPSTAT
  vcount: uint8
  bgcnts: array[4, BGCNT]

proc startLine(ppu: PPU): proc()
proc startHblank(ppu: PPU): proc()
proc endHblank(ppu: PPU): proc()

proc newPPU*(gba: GBA): PPU =
  new result
  result.gba = gba
  result.startLine()()

proc renderTextLayer(vram: array[0x18000, uint8], layer: SomeInteger) =
  if not(dispcnt.controlBits.bit(layer.uint8)): return
  let
    bgcnt = bgcnts[layer]
    screenBase = bgcnt.screenBase * 0x800
    charBase = bgcnt.charBase * 0x4000
  for col in 0'u32 ..< width.uint32:
    let
      screenEntry = (cast[ptr uint16](unsafeAddr vram[screenBase + ((col shr 3) + (vcount.uint32 shr 3) * 32) * 2]))[]
      tileId = screenEntry.bitsliced(0..9)
      paletteBank = screenEntry.bitsliced(12..15).uint8
      x = col and 7
      y = vcount and 7
    var paletteIndex = (vram[charBase + tileId * 0x20 + y * 4 + (x shr 1)] shr ((x and 1) * 4)) and 0xF
    if paletteIndex > 0: paletteIndex += paletteBank shl 4
    layerBuffers[layer][col] = paletteIndex

proc calculateColor(pram: array[0x400, uint8], col: SomeInteger): uint16 =
  for priority in 0'u32 ..< 4'u32:
    for layer in 0 ..< 4:
      let bgcnt = bgcnts[layer]
      if bgcnt.priority == priority:
        let palette = layerBuffers[layer][col]
        if palette > 0:
          return read(uint16, pram, 0'u16, palette)
  return 0

proc composite(pram: array[0x400, uint8], scanline: ptr Scanline) =
  for col in 0 ..< width:
    scanline[col] = calculateColor(pram, col)

proc getLine(buffer: var FrameBuffer, row: SomeInteger): ptr Scanline =
  result = cast[ptr array[buffer.width, buffer.T]](addr buffer[buffer.width * row])
  for pixel in result[].mitems: pixel = 0

proc draw(ppu: PPU) =
  ppu.gba.display.draw(framebuffer)

proc scanline(ppu: PPU) =
  let
    row = int(vcount)
    rowBase = row * width
  var scanline = framebuffer.getLine(row)
  for layer in 0 ..< 4:
    for pixel in layerBuffers[layer].mitems:
      pixel = 0
  case dispcnt.mode
  of 0:
    for layer in 0 ..< 4:
      renderTextLayer(ppu.vram, layer)
    composite(ppu.pram, scanline)
  of 3:
    for col in 0 ..< width:
      scanline[col] = cast[ptr FrameBuffer](addr ppu.vram)[rowBase + col]
  of 4:
    let base = if dispcnt.page: 0xA000 else: 0
    for col in 0 ..< width:
      let palIdx = ppu.vram[base + rowBase + col]
      scanline[col] = cast[ptr FrameBuffer](addr ppu.pram)[palIdx]
  else: echo "Unsupported background mode " & $dispcnt.mode

proc startLine(ppu: PPU): proc() = (proc() =
  ppu.gba.scheduler.schedule(960, startHblank(ppu), EventType.ppu))

proc startHblank(ppu: PPU): proc() = (proc() =
  dispstat.hblank = true
  if vcount < height: ppu.scanline()
  ppu.gba.scheduler.schedule(272, endHblank(ppu), EventType.ppu))

proc endHblank(ppu: PPU): proc() = (proc() =
  dispstat.hblank = false
  vcount = (vcount + 1) mod 228
  dispstat.vcount = dispstat.vcountTarget == vcount
  if vcount == 0:
    dispstat.vblank = false
  elif vcount == height:
    dispstat.vblank = true
    ppu.draw()
  ppu.gba.scheduler.schedule(0, startLine(ppu), EventType.ppu))

proc `[]`*(ppu: PPU, address: SomeInteger): uint8 =
  case address:
  of 0x00..0x01: read(dispcnt, address and 1)
  of 0x04..0x05: read(dispstat, address and 1)
  of 0x06..0x07: (if address.bit(0): 0'u8 else: vcount)
  of 0x08..0x0F: read(bgcnts[(address - 0x08) div 2], address and 1)
  else: quit "Unmapped PPU read: " & address.toHex(4)

proc `[]=`*(ppu: PPU, address: SomeInteger, value: uint8) =
  case address:
  of 0x00..0x01: write(dispcnt, value, address and 1)
  of 0x04..0x05: write(dispstat, value, address and 1)
  of 0x06..0x07: discard # vcount
  of 0x08..0x0F: write(bgcnts[(address - 0x08) div 2], value, address and 1)
  else: echo "Unmapped PPU write: ", address.toHex(4), " -> ", value.toHex(2)

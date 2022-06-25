import bitops, strutils

import types, util, display, interrupts, regs, scheduler

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
  greenSwap: uint16
  dispstat: DISPSTAT
  vcount: uint8
  bgcnts: array[4, BGCNT]
  bghofs: array[4, BGOFS]
  bgvofs: array[4, BGOFS]
  bgaff: array[2, array[4, uint16]]
  bgref: array[2, array[2, uint32]]
  win0h: WINBOUND
  win1h: WINBOUND
  win0v: WINBOUND
  win1v: WINBOUND
  winin: WININ
  winout: WINOUT
  mosaic: MOSAIC
  bldcnt: BLDCNT
  bldalpha: BLDALPHA
  bldy: BLDY

proc startLine(ppu: PPU): proc()
proc startHblank(ppu: PPU): proc()
proc endHblank(ppu: PPU): proc()

proc newPPU*(gba: GBA): PPU =
  new result
  result.gba = gba
  result.startLine()()

proc isBitmap*(): bool = dispcnt.mode >= 3

# from tonc https://www.coranac.com/tonc/text/regbg.htm
proc seIndex(tileX, tileY, screenSize: SomeInteger): SomeInteger =
  result = tileX + tileY * 32
  if tileX >= 32: result += 0x03E0
  if tileY >= 32 and screenSize == 0b11: result += 0x0400

proc renderTextLayer(vram: array[0x18000, uint8], layer: SomeInteger) =
  if not(dispcnt.controlBits.bit(layer)): return
  let
    bgcnt = bgcnts[layer]
    bghof = bghofs[layer].offset
    bgvof = bgvofs[layer].offset
    screenBase = bgcnt.screenBase * 0x800
    charBase = bgcnt.charBase * 0x4000
    (bgWidth, bgHeight) = case bgcnt.screenSize
      of 0: (0x100'u32, 0x100'u32) # 32x32 tiles
      of 1: (0x200'u32, 0x100'u32) # 64x32 tiles
      of 2: (0x100'u32, 0x200'u32) # 32x64 tiles
      of 3: (0x200'u32, 0x200'u32) # 64x64 tiles
      else: quit "Invalid bgcnt screensize " & $bgcnt.screenSize
    effectiveY = (vcount.uint32 + bgvof) mod bgHeight
    tileY = effectiveY shr 3
  for col in 0'u32 ..< width.uint32:
    let
      effectiveX = (col + bghof) mod bgWidth
      tileX = effectiveX shr 3
      screenEntry = read[uint16](vram, screenBase, seIndex(tileX, tileY, bgcnt.screenSize))
      tileId = screenEntry.bitsliced(0..9)
      paletteBank = screenEntry.bitsliced(12..15).uint8
      x = (effectiveX and 7) xor (7 * screenEntry.bitsliced(10..10))
      y = (effectiveY and 7) xor (7 * screenEntry.bitsliced(11..11))
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
          return read[uint16](pram, 0'u16, palette)
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
  of 1:
    for layer in 0..<3:
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
  if dispstat.hblankEnable:
    ppu.gba.interrupts.regIf.hblank = true
    ppu.gba.interrupts.scheduleCheck()
  if vcount < height: ppu.scanline()
  ppu.gba.scheduler.schedule(272, endHblank(ppu), EventType.ppu))

proc endHblank(ppu: PPU): proc() = (proc() =
  dispstat.hblank = false
  vcount = (vcount + 1) mod 228
  dispstat.vcount = dispstat.vcountTarget == vcount
  if dispstat.vcountEnable and dispstat.vcount: ppu.gba.interrupts.regIf.vcount = true
  if vcount == 0:
    dispstat.vblank = false
  elif vcount == height:
    dispstat.vblank = true
    if dispstat.vblankEnable: ppu.gba.interrupts.regIf.vblank = true
    ppu.draw()
  ppu.gba.interrupts.scheduleCheck()
  ppu.gba.scheduler.schedule(0, startLine(ppu), EventType.ppu))

proc `[]`*(ppu: PPU, address: SomeInteger): uint8 =
  case address:
  of 0x00..0x01: read(dispcnt, address and 1)
  of 0x02..0x03: read(greenSwap, address and 1)
  of 0x04..0x05: read(dispstat, address and 1)
  of 0x06..0x07: (if address.bit(0): 0'u8 else: vcount)
  of 0x08..0x0F: read(bgcnts[(address - 0x08) div 2], address and 1)
  of 0x10..0x1F:
    let layer = (address - 0x10) div 4
    if address.bit(1): read(bgvofs[layer], address and 1)
    else:              read(bghofs[layer], address and 1)
  of 0x20..0x3F:
    let
      bgNum = (address - 0x20) div 16
      offset = address and 0xF
    if offset < 8: read(bgaff[bgNum][offset div 2], address and 1)
    else:          read(bgref[bgNum][(offset - 8) div 4], address and 3)
  of 0x40..0x41: read(win0h, address and 1)
  of 0x42..0x43: read(win1h, address and 1)
  of 0x44..0x45: read(win0v, address and 1)
  of 0x46..0x47: read(win1v, address and 1)
  of 0x48..0x49: read(winin, address and 1)
  of 0x4A..0x4B: read(winout, address and 1)
  of 0x4C..0x4D: read(mosaic, address and 1)
  of 0x50..0x51: read(bldcnt, address and 1)
  of 0x52..0x53: read(bldalpha, address and 1)
  of 0x54..0x55: read(bldy, address and 1)
  else: echo "Unmapped PPU read: " & address.toHex(4); 0

proc `[]=`*(ppu: PPU, address: SomeInteger, value: uint8) =
  case address:
  of 0x00..0x01: write(dispcnt, value, address and 1)
  of 0x02..0x03: write(greenSwap, value, address and 1)
  of 0x04..0x05: write(dispstat, value, address and 1)
  of 0x06..0x07: discard # vcount
  of 0x08..0x0F: write(bgcnts[(address - 0x08) div 2], value, address and 1)
  of 0x10..0x1F:
    let layer = (address - 0x10) div 4
    if address.bit(1): write(bgvofs[layer], value, address and 1)
    else:              write(bghofs[layer], value, address and 1)
  of 0x20..0x3F:
    let
      bgNum = (address - 0x20) div 16
      offset = address and 0xF
    if offset < 8: write(bgaff[bgNum][offset div 2], value, address and 1)
    else:          write(bgref[bgNum][(offset - 8) div 4], value, address and 3)
  of 0x40..0x41: write(win0h, value, address and 1)
  of 0x42..0x43: write(win1h, value, address and 1)
  of 0x44..0x45: write(win0v, value, address and 1)
  of 0x46..0x47: write(win1v, value, address and 1)
  of 0x48..0x49: write(winin, value, address and 1)
  of 0x4A..0x4B: write(winout, value, address and 1)
  of 0x4C..0x4D: write(mosaic, value, address and 1)
  of 0x50..0x51: write(bldcnt, value, address and 1)
  of 0x52..0x53: write(bldalpha, value, address and 1)
  of 0x54..0x55: write(bldy, value, address and 1)
  else: echo "Unmapped PPU write: ", address.toHex(8), " = ", value.toHex(2)

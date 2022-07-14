import types, regs, interrupts, bus

const
  transferBytes: array[DmaChunkSize, uint32] = [2'u32, 4]
  addressAdjustments: array[DmaAddressControl, uint32] = [1'u32, 0xFFFFFFFF'u32, 0, 1]

var
  dmasad: array[4, uint32]
  dmadad: array[4, uint32]
  dmacnt_l: array[4, uint16]
  dmacnt_h: array[4, DMACNT]
  src: array[4, uint32]
  dst: array[4, uint32]

proc newDMA*(gba: GBA): DMA =
  new result
  result.gba = gba

proc trigger(gba: GBA, channel: SomeInteger) =
  let dmacnt = dmacnt_h[channel]
  var len = dmacnt_l[channel]
  var transfer = dmacnt.transfer
  var dstCtrl = dmacnt.dstCtrl

  if dmacnt.srcCtrl == DmaAddressControl.reload:
    echo "Prohibited source address control"

  if dmacnt.timing == special:
    if channel == 1 or channel == 2: # dma audio
      echo "DMA: Audio on channel ", channel
      len = 4
      transfer = DmaChunkSize.word
      dstCtrl = fixed
    elif channel == 3:
      echo "todo: video capture dma"
    else:
      echo "Prohibited special dma"

  let
    transferSize = transferBytes[transfer]
    srcDelta  = transferSize * addressAdjustments[dmacnt.srcCtrl]
    dstDelta  = transferSize * addressAdjustments[dstCtrl]

  for idx in 0 ..< int(len):
    if transfer == DmaChunkSize.halfword:
      gba.bus[dst[channel]] = gba.bus.read[:uint16](src[channel])
    else:
      gba.bus[dst[channel]] = gba.bus.read[:uint32](src[channel])
    src[channel] += srcDelta
    dst[channel] += dstDelta

  if dmacnt.dstCtrl == DmaAddressControl.reload:
    dst[channel] = dmadad[channel]
  if not dmacnt.repeat or dmacnt.timing == DmaStartTiming.immediate:
    dmacnt_h[channel].enable = false
  if dmacnt.irq:
    case channel:
    of 0: gba.interrupts.regIf.dma0 = true
    of 1: gba.interrupts.regIf.dma1 = true
    of 2: gba.interrupts.regIf.dma2 = true
    of 3: gba.interrupts.regIf.dma3 = true
    else: quit "Bad dma channel. Impossible case."
    gba.interrupts.scheduleCheck()

proc triggerFifo*(gba: GBA, audioChannel: SomeInteger) =
  echo "triggering fifo"
  let dmacnt = dmacnt_h[audioChannel + 1]
  if dmacnt.enable and dmacnt.timing == special:
    echo "  channel ", audioChannel + 1
    trigger(gba, audioChannel + 1)

proc `[]`*(dma: DMA, address: SomeInteger): uint8 =
  let
    dmaAddr = address - 0xB0
    channel = dmaAddr div 12
    reg = dmaAddr mod 12
  case reg:
  of 0..3: read(dmasad[channel], address and 3)
  of 4..7: read(dmadad[channel], address and 3)
  of 8..9: read(dmacnt_l[channel], address and 1)
  of 10..11: read(dmacnt_h[channel], address and 1)
  else: echo "Unmapped DMA read: ", address.toHex(8); 0

proc `[]=`*(dma: DMA, address: SomeInteger, value: uint8) =
  let
    dmaAddr = address - 0xB0
    channel = dmaAddr div 12
    reg = dmaAddr mod 12
  case reg:
  of 0..3: write(dmasad[channel], value, address and 3)
  of 4..7: write(dmadad[channel], value, address and 3)
  of 8..9: write(dmacnt_l[channel], value, address and 1)
  of 10..11:
    let wasEnabled = dmacnt_h[channel].enable
    write(dmacnt_h[channel], value, address and 1)
    if dmacnt_h[channel].enable and not wasEnabled:
      src[channel] = dmasad[channel]
      dst[channel] = dmadad[channel]
      if dmacnt_h[channel].timing == immediate: trigger(dma.gba, channel)
  else: echo "Unmapped DMA write: ", address.toHex(8), " = ", value.toHex(2)

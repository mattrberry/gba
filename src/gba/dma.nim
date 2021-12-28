import strutils

import types, regs

var
  dmasad: array[4, uint32]
  dmadad: array[4, uint32]
  dmacnt_l: array[4, uint16]
  dmacnt_h: array[4, DMACNT]

proc newDMA*(gba: GBA): DMA =
  new result
  result.gba = gba

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
  else: echo "Unmapped DMA read: " & address.toHex(8); 0

proc `[]=`*(dma: DMA, address: SomeInteger, value: uint8) =
  let
    dmaAddr = address - 0xB0
    channel = dmaAddr div 12
    reg = dmaAddr mod 12
    mask = 0xFF'u32 shl (8 * reg)
  case reg:
  of 0..3: write(dmasad[channel], value, address and 3)
  of 4..7: write(dmadad[channel], value, address and 3)
  of 8..9: write(dmacnt_l[channel], value, address and 1)
  of 10..11: # dmacnt_h
    let wasEnabled = dmacnt_h[channel].enable
    write(dmacnt_h[channel], value, address and 1)
    if dmacnt_h[channel].enable and not wasEnabled:
      echo "Triggered DMA on channel ", $channel
  else: echo "Unmapped DMA write: ", address.toHex(8), " = ", value.toHex(2)

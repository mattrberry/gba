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
  of 0..3: cast[uint8](dmasad[channel] shr (8 * reg))
  of 4..7: cast[uint8](dmadad[channel] shr (8 * (reg - 4)))
  of 8..9: cast[uint8](dmacnt_l[channel] shr (8 * (reg - 8)))
  of 10..11: read(dmacnt_h[channel], reg - 10)
  else: echo "Unmapped DMA read: " & address.toHex(8); 0

proc `[]=`*(dma: DMA, address: SomeInteger, value: uint8) =
  let
    dmaAddr = address - 0xB0
    channel = dmaAddr div 12
    reg = dmaAddr mod 12
    mask = 0xFF'u32 shl (8 * reg)
  case reg:
  of 0..3: # dmasad
    let
      shift = 8 * reg
      mask = 0xFF'u32 shl shift
      value = value shl shift
    dmasad[channel] = dmasad[channel].clearMasked(mask) or value
  of 4..7: # dmadad
    let
      shift = (8 * (reg - 4))
      mask = 0xFF'u32 shl shift
      value = value shl shift
    dmadad[channel] = dmadad[channel].clearMasked(mask) or value
  of 8..9: # dmacnt_l
    let
      shift = (8 * (reg - 8))
      mask = 0xFF'u16 shl shift
      value = value shl shift
    dmacnt_l[channel] = dmacnt_l[channel].clearMasked(mask) or value
  of 10..11: # dmacnt_h
    let wasEnabled = dmacnt_h[channel].enable
    write(dmacnt_h[channel], value, reg - 10)
    if dmacnt_h[channel].enable and not wasEnabled:
      echo "Triggered DMA on channel ", $channel
  else: echo "Unmapped DMA write: ", address.toHex(8), " = ", value.toHex(2)

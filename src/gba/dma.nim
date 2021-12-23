import strutils

import types

proc newDMA*(gba: GBA): DMA =
  new result
  result.gba = gba

proc `[]`*(dma: DMA, address: SomeInteger): uint8 =
  echo "Unmapped DMA read: " & address.toHex(8)
  0

proc `[]=`*(dma: DMA, address: SomeInteger, value: uint8) =
  echo "Unmapped DMA write: ", address.toHex(8), " = ", value.toHex(2)

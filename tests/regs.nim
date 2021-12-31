import unittest
import strutils

import ../src/gba/regs

suite "regs":
  var
    dispcnt: DISPCNT
    dmacnt: DMACNT

  setUp:
    dispcnt = cast[DISPCNT](0x0110) # page 1, control bits 1
    dmacnt = cast[DMACNT](0x8000)

  test "read fields":
    check(dispcnt.mode == 0)
    check(dispcnt.controlBits == 1)
    check(dispcnt.windowObj == false)
    check(dispcnt.page == true)
    # check bitfield reads with many enums
    check(dmacnt.dstCtrl == DmaAddressControl.increment)
    check(dmacnt.srcCtrl == DmaAddressControl.increment)
    check(dmacnt.repeat == false)
    check(dmacnt.transfer == DmaChunkSize.halfword)
    check(dmacnt.gamepak == false)
    check(dmacnt.timing == DmaStartTiming.immediate)
    check(dmacnt.irq == false)
    check(dmacnt.enable == true)

  test "set fields":
    dispcnt.mode = 3
    dispcnt.page = false
    check(dispcnt.mode == 3)
    check(dispcnt.controlBits == 1)
    check(dispcnt.windowObj == false)
    check(dispcnt.page == false)
    # check bitfield writes with many enums
    dmacnt.dstCtrl = DmaAddressControl.decrement
    dmacnt.srcCtrl = DmaAddressControl.reload
    dmacnt.transfer = DmaChunkSize.word
    dmacnt.timing = DmaStartTiming.hblank
    check(dmacnt.dstCtrl == DmaAddressControl.decrement)
    check(dmacnt.srcCtrl == DmaAddressControl.reload)
    check(dmacnt.repeat == false)
    check(dmacnt.transfer == DmaChunkSize.word)
    check(dmacnt.gamepak == false)
    check(dmacnt.timing == DmaStartTiming.hblank)
    check(dmacnt.irq == false)
    check(dmacnt.enable == true)

  test "read":
    check(read(dispcnt, 0) == 0x10)
    check(read(dispcnt, 1) == 0x01)
    # check bitfield reads with many enums
    check(read(dmacnt, 0) == 0x00)
    check(read(dmacnt, 1) == 0x80)

  test "write":
    write(dispcnt, 0x07, 0)
    write(dispcnt, 0xFA, 1)
    check(read(dispcnt, 0) == 0x07)
    check(read(dispcnt, 1) == 0xFA)
    check(dispcnt.mode == 7)
    check(dispcnt.page == false)
    # check bitfield writes with many enums
    write(dmacnt, 0x07, 0)
    write(dmacnt, 0xFA, 1)
    check(read(dmacnt, 0) == 0x07)
    check(read(dmacnt, 1) == 0xFA)
    check(dmacnt.dstCtrl == DmaAddressControl.increment)
    check(dmacnt.srcCtrl == DmaAddressControl.increment)
    check(dmacnt.repeat == true)
    check(dmacnt.transfer == DmaChunkSize.halfword)
    check(dmacnt.gamepak == true)
    check(dmacnt.timing == DmaStartTiming.special)
    check(dmacnt.irq == true)
    check(dmacnt.enable == true)

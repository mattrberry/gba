import unittest

import ../src/gba/regs

suite "regs":
  var dispcnt: DISPCNT

  setUp:
    dispcnt = cast[DISPCNT](0x0110) # page 1, control bits 1

  test "read fields":
    check(dispcnt.mode == 0)
    check(dispcnt.controlBits == 1)
    check(dispcnt.windowObj == false)
    check(dispcnt.page == true)

  test "set fields":
    dispcnt.mode = 3
    dispcnt.page = false
    check(dispcnt.mode == 3)
    check(dispcnt.controlBits == 1)
    check(dispcnt.windowObj == false)
    check(dispcnt.page == false)

  test "read":
    check(read(dispcnt, 0) == 0x10)
    check(read(dispcnt, 1) == 0x01)

  test "write":
    write(dispcnt, 0x07, 0)
    write(dispcnt, 0xFA, 1)
    check(read(dispcnt, 0) == 0x07)
    check(read(dispcnt, 1) == 0xFA)
    check(dispcnt.mode == 7)
    check(dispcnt.page == false)

import unittest

import ../src/gba/util

suite ">>":
  test ">> in range":
    check(0xF'u8 >> 2 == 0x3)

  test ">> zero":
    check(0xF'u8 >> 0 == 0xF'u8)

  test ">> out of range":
    check(0xF'u8 >> 100 == 0)

suite "<<":
  test "<< in range":
    check(0xF'u8 << 2 == 0x3C)

  test "<< zero":
    check(0xF'u8 << 0 == 0xF'u8)

  test "<< out of range":
    check(0xF'u8 << 100 == 0)

suite "bit":
  test "set in range":
    check(bit(0b1010'u8, 1) == true)

  test "clear in range":
    check(bit(0b1010'u8, 2) == false)

  test "set zero":
    check(bit(0b1011'u8, 0) == true)

  test "clear zero":
    check(bit(0b1010'u8, 0) == false)

  test "out of range":
    check(bit(0b1010'u8, 100) == false)

suite "signExtend":
  test "positive":
    check(signExtend(uint8, 0b00000101'u8, 3) == 0b00000101)

  test "negative":
    check(signExtend(uint8, 0b00000101'u8, 2) == 0b11111101)

  test "positive type up":
    check(signExtend(uint16, 0x07'u8, 3) == 0x07)

  test "negative type up":
    check(signExtend(uint16, 0x07'u8, 2) == 0xFFFF'u16)

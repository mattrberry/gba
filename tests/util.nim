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

suite "read":
  let a = [0x01'u8, 0x02'u8, 0x03'u8, 0x04'u8, 0x05'u8, 0x06'u8]

  test "same type no offset":
    check(read(uint8, a, 0, 0) == 0x01)

  test "same type base offset":
    check(read(uint8, a, 1, 0) == 0x02)

  test "same type type offset":
    check(read(uint8, a, 0, 1) == 0x02)

  test "same type both offset":
    check(read(uint8, a, 1, 1) == 0x03)

  test "diff type no offset":
    check(read(uint16, a, 0, 0) == 0x0201)

  test "diff type base offset":
    check(read(uint16, a, 1, 0) == 0x0302)

  test "diff type type offset":
    check(read(uint16, a, 0, 1) == 0x0403)

  test "diff type both offset":
    check(read(uint16, a, 1, 1) == 0x0504)


suite "write":
  var a: array[6, uint8]

  setUp:
    a = [0x01'u8, 0x02'u8, 0x03'u8, 0x04'u8, 0x05'u8, 0x06'u8]

  test "same type no offset":
    write(uint8, a, 0, 0, 0x10)
    check(a == [0x10'u8, 0x02'u8, 0x03'u8, 0x04'u8, 0x05'u8, 0x06'u8])

  test "same type base offset":
    write(uint8, a, 1, 0, 0x20)
    check(a == [0x01'u8, 0x20'u8, 0x03'u8, 0x04'u8, 0x05'u8, 0x06'u8])

  test "same type type offset":
    write(uint8, a, 0, 1, 0x20)
    check(a == [0x01'u8, 0x20'u8, 0x03'u8, 0x04'u8, 0x05'u8, 0x06'u8])

  test "same type both offset":
    write(uint8, a, 1, 1, 0x30)
    check(a == [0x01'u8, 0x02'u8, 0x30'u8, 0x04'u8, 0x05'u8, 0x06'u8])

  test "diff type no offset":
    write(uint16, a, 0, 0, 0x2010)
    check(a == [0x10'u8, 0x20'u8, 0x03'u8, 0x04'u8, 0x05'u8, 0x06'u8])

  test "diff type base offset":
    write(uint16, a, 1, 0, 0x3020)
    check(a == [0x01'u8, 0x20'u8, 0x30'u8, 0x04'u8, 0x05'u8, 0x06'u8])

  test "diff type type offset":
    write(uint16, a, 0, 1, 0x4030)
    check(a == [0x01'u8, 0x02'u8, 0x30'u8, 0x40'u8, 0x05'u8, 0x06'u8])

  test "diff type both offset":
    write(uint16, a, 1, 1, 0x5040)
    check(a == [0x01'u8, 0x02'u8, 0x03'u8, 0x40'u8, 0x50'u8, 0x06'u8])

import unittest

import ../src/gba/cpu

suite "asr":
  var carryOut: bool

  setup:
    carryOut = false

  test "positive standard amount":
    let positive = 0x84'u32
    let result = asr[true](positive, 3, carryOut)
    check(result == 0x10'u32)
    check(carryOut == true)

  test "negative standard amount":
    let negative = 0x80000000'u32
    let result = asr[true](negative, 4, carryOut)
    check(result == 0xF8000000'u32)
    check(carryOut == false)

  test "zero bits immediate":
    let toShift = 0xDEADBEEF'u32
    let result = asr[true](toShift, 0, carryOut)
    check(result == 0xFFFFFFFF'u32)
    check(carryOut == true)

  test "zero bits register":
    let toShift = 0xDEADBEEF'u32
    let result = asr[false](toShift, 0, carryOut)
    check(result == toShift)
    check(carryOut == false)

  test "zero bits register doesn't touch carry":
    carryOut = true
    let toShift = 0xDEADBEEF'u32
    let result = asr[false](toShift, 0, carryOut)
    check(result == toShift)
    check(carryOut == true)

  test "positive large shift":
    let toShift = 0x80'u32
    let result = asr[true](toShift, 80, carryOut)
    check(result == 0'u32)
    check(carryOut == false)

  test "negative large shift":
    let toShift = 0xDEADBEEF'u32
    let result = asr[true](toShift, 80, carryOut)
    check(result == 0xFFFFFFFF'u32)
    check(carryOut == true)

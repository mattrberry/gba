import arm, types

proc newCPU*(gba: GBA): CPU =
  new result
  result.gba = gba
  result.r[15] = 0x08000000

proc run*(cpu: var CPU) =
  echo "running"
  exec_arm(0xE3A0E102'u32)
  exec_arm(0xE18EE82E'u32)
  exec_arm(0xE58FE000'u32)

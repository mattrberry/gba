import sdl2

import types, regs

var
  keyinput = cast[KEYINPUT](0xFFFF'u16)
  keycnt = cast[KEYCNT](0xFFFF'u16)

proc newKeypad*(gba: GBA): Keypad =
  new result
  result.gba = gba

proc `[]`*(keypad: Keypad, address: SomeInteger): uint8 =
  case address:
  of 0x130..0x131: read(keyinput, address and 1)
  of 0x132..0x133: read(keycnt, address and 1)
  else: echo "Unmapped Keypad read: " & address.toHex(8); 0

proc `[]=`*(keypad: Keypad, address: SomeInteger, value: uint8) =
  case address:
  of 0x130..0x131: discard # read only
  of 0x132..0x133: write(keycnt, value, address and 1)
  else: echo "Unmapped Keypad write: ", address.toHex(8), " = ", value.toHex(2)

proc keyEvent*(keypad: Keypad, event: KeyboardEventObj) =
  let bit = not(bool(event.state))
  case event.keysym.scancode
  of SDL_SCANCODE_E: keyinput.up = bit
  of SDL_SCANCODE_D: keyinput.down = bit
  of SDL_SCANCODE_S: keyinput.left = bit
  of SDL_SCANCODE_F: keyinput.right = bit
  of SDL_SCANCODE_W: keyinput.l = bit
  of SDL_SCANCODE_R: keyinput.r = bit
  of SDL_SCANCODE_J: keyinput.b = bit
  of SDL_SCANCODE_K: keyinput.a = bit
  of SDL_SCANCODE_L: keyinput.select = bit
  of SDL_SCANCODE_SEMICOLON: keyinput.start = bit
  of SDL_SCANCODE_Q: quit "quit q"
  else: discard

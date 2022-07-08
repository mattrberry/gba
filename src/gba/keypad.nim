import sdl2

import types, regs

var
  keyinput = {KeyInput.low..KeyInput.high}
  keycnt = cast[KEYCNT](0xFFFF'u16)
static: assert sizeof(KeyInputs) == sizeof(uint16)

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
  of SDL_SCANCODE_E: keyinput.incl up
  of SDL_SCANCODE_D: keyinput.incl down
  of SDL_SCANCODE_S: keyinput.incl left
  of SDL_SCANCODE_F: keyinput.incl right
  of SDL_SCANCODE_W: keyinput.incl l
  of SDL_SCANCODE_R: keyinput.incl r
  of SDL_SCANCODE_J: keyinput.incl b
  of SDL_SCANCODE_K: keyinput.incl a
  of SDL_SCANCODE_L: keyinput.incl select
  of SDL_SCANCODE_SEMICOLON: keyinput.incl start
  of SDL_SCANCODE_Q: quit "quit q"
  else: discard

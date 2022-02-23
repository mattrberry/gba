import os
import sdl2

import gba/[types, display, scheduler, bus, cpu, ppu, apu, dma, timer, serial, keypad, interrupts, util]

proc newGBA(bios, rom: string): GBA =
  new result
  result.display = newDisplay()
  result.scheduler = newScheduler()
  result.bus = newBus(result, bios, rom)
  result.cpu = newCPU(result)
  result.ppu = newPPU(result)
  result.apu = newAPU(result)
  result.dma = newDMA(result)
  result.timer = newTimer(result)
  result.serial = newSerial(result)
  result.keypad = newKeypad(result)
  result.interrupts = newInterrupts(result)

var cycleCount = 0
const cyclesPerFrame = 280896

# Run long enough to produce the next frame, then return.
proc runFrame(gba: GBA) =
  while likely(cycleCount < cyclesPerFrame):
    let accessCycles = gba.cpu.tick()
    gba.scheduler.tick(accessCycles)
    cycleCount += accessCycles
  cycleCount -= cyclesPerFrame

proc checkKeyInput(gba: GBA) =
  var event = sdl2.defaultEvent
  while pollEvent(event):
    case event.kind
    of QuitEvent: quit "quit event"
    of KeyDown, KeyUp: gba.keypad.keyEvent(cast[KeyboardEventObj](event))
    else: discard

proc loop(gba: GBA) {.cdecl.} =
  runFrame(gba)
  checkKeyInput(gba)

discard sdl2.init(INIT_EVERYTHING)

when defined(emscripten):
  type em_arg_callback_func = proc(data: pointer) {.cdecl.}
  proc emscripten_set_main_loop(fun: proc() {.cdecl.}, fps, simulate_infinite_loop: cint) {.header: "<emscripten.h>".}
  proc emscripten_set_main_loop_arg(fun: em_arg_callback_func, arg: pointer, fps, simulate_infinite_loop: cint) {.header: "<emscripten.h>".}
  proc emscripten_cancel_main_loop() {.header: "<emscripten.h>".}
  proc initFromEmscripten() {.exportc.} =
    var gba = newGBA("bios.bin", "rom.gba")
    emscripten_set_main_loop_arg(cast[em_arg_callback_func](loop), cast[pointer](gba), -1, 1)
else:
  if paramCount() != 2: quit "Run with ./gba /path/to/bios /path/to/rom"
  var gba = newGBA(paramStr(1), paramStr(2))
  while true:
    loop(gba)
    sleepUntilEndOfFrame()

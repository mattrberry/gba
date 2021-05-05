import types, regs, scheduler

proc newInterrupts*(gba: GBA): Interrupts =
  new result
  result.gba = gba

proc checkInterrupts(interrupts: Interrupts): proc() = (proc() =
  if (interrupts.regIe and interrupts.regIf) > 0:
    interrupts.gba.cpu.halted = false
    if interrupts.ime: interrupts.gba.cpu.interrupt(interrupts.gba.cpu))

proc scheduleCheck*(interrupts: Interrupts) {.gcsafe locks: 0.} =
  interrupts.gba.scheduler.schedule(0, checkInterrupts(interrupts), EventType.interrupt)

proc `[]`*(interrupts: Interrupts, address: SomeInteger): uint8 =
  case address:
  of 0x200..0x201: read(interrupts.regIe, address and 1)
  of 0x202..0x203: read(interrupts.regIf, address and 1)
  of 0x208: uint8(interrupts.ime)
  of 0x209: 0'u8
  else: quit "Unmapped interrupts read: " & address.toHex(4)

proc `[]=`*(interrupts: Interrupts, address: SomeInteger, value: uint8) =
  case address:
  of 0x200..0x201: write(interrupts.regIe, value, address and 1)
  of 0x202..0x203: write(interrupts.regIf, (interrupts.regIf.toU16 shr ((address and 1) * 8)).uint8 and not(value), address and 1)
  of 0x208: interrupts.ime = value.bit(0)
  of 0x209: discard
  else: echo "Unmapped interrupts write: ", address.toHex(4), " -> ", value.toHex(2)
  interrupts.scheduleCheck()

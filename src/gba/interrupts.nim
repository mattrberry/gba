import types, regs, scheduler

var
  ime: bool
  regIe: INTERRUPT
  regIf: INTERRUPT

proc newInterrupts*(gba: GBA): Interrupts =
  new result
  result.gba = gba

proc checkInterrupts(interrupts: Interrupts): proc()

proc scheduleCheck*(interrupts: Interrupts){.gcsafe locks: 0.} =
  interrupts.gba.scheduler.schedule(0, checkInterrupts(interrupts), EventType.interrupt)

proc `[]`*(interrupts: Interrupts, address: SomeInteger): uint8 =
  case address:
  of 0x200..0x201: read(regIe, address and 1)
  of 0x202..0x203: read(regIf, address and 1)
  of 0x208: uint8(ime)
  of 0x209: 0'u8
  else: quit "Unmapped interrupts read: " & address.toHex(4)

proc `[]=`*(interrupts: Interrupts, address: SomeInteger, value: uint8) =
  case address:
  of 0x200..0x201: write(regIe, value, address and 1)
  of 0x202..0x203: discard #write(regIf, regIf and not(value), address and 1) Just commented out due to compile error
  of 0x208: ime = value.bit(0)
  of 0x209: discard
  else: echo "Unmapped interrupts write: ", address.toHex(4), " -> ", value.toHex(2)
  interrupts.scheduleCheck()

proc checkInterrupts(interrupts: Interrupts): proc() = (proc() =
   if (regIe and regIf) > 0:
     interrupts.gba.cpu.halted = false
     if ime: interrupts.gba.cpu.interrupt(interrupts.gba.cpu))
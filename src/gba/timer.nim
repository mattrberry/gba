import types, interrupts, regs, scheduler

const
  periods = [1'u16, 64, 256, 1024]
  events = [EventType.timer0, EventType.timer1, EventType.timer2, EventType.timer3]

var
  reload: array[4, uint16]
  tmcnt: array[4, TMCNT]
  counter: array[4, uint16]
  cycleEnabled: array[4, uint64]

proc overflow(timer: Timer, num: SomeInteger): proc()

proc newTimer*(gba: GBA): Timer =
  new result
  result.gba = gba
  result.overflowProcs = [overflow(result, 0), overflow(result, 1), overflow(result, 2), overflow(result, 3)]

proc cyclesUntilOverflow(num: SomeInteger): uint64 =
  periods[tmcnt[num].freq].uint64 * (0x10000'u64 - reload[num])

proc scheduleTimer(timer: Timer, num: SomeInteger) =
  cycleEnabled[num] = timer.gba.scheduler.cycles
  timer.gba.scheduler.schedule(cyclesUntilOverflow(num), timer.overflowProcs[num], events[num])

proc overflow(timer: Timer, num: SomeInteger): proc() = (proc() =
  counter[num] = reload[num]
  if num < 3 and tmcnt[num + 1].cascade and tmcnt[num + 1].enable:
    counter[num + 1] += 1
    if counter[num + 1] == 0: timer.overflowProcs[num + 1]()
  # todo: handle apu logic
  if tmcnt[num].irq:
    case num:
    of 0: timer.gba.interrupts.regIf.timer0 = true
    of 1: timer.gba.interrupts.regIf.timer1 = true
    of 2: timer.gba.interrupts.regIf.timer2 = true
    of 3: timer.gba.interrupts.regIf.timer3 = true
    else: quit "Bad timer number. Impossible case."
    timer.gba.interrupts.scheduleCheck()
  if not tmcnt[num].cascade:
    scheduleTimer(timer, num))

proc getCurrentCounter(timer: Timer, num: SomeInteger): uint16 =
  result = counter[num]
  if tmcnt[num].enable and not tmcnt[num].cascade:
    let cycles = uint16(timer.gba.scheduler.cycles - cycleEnabled[num])
    result += cycles div periods[tmcnt[num].freq]

proc updateCounter(timer: Timer, num: SomeInteger) =
  counter[num] = getCurrentCounter(timer, num)
  cycleEnabled[num] = timer.gba.scheduler.cycles

proc `[]`*(timer: Timer, address: SomeInteger): uint8 =
  let
    num = (address - 0x100) div 4
    val16 = if not address.bit(1): getCurrentCounter(timer, num)
            else:                  tmcnt[num]
  read(val16, address and 1)

proc `[]=`*(timer: Timer, address: SomeInteger, value: uint8) =
  let num = (address - 0x100) div 4
  if not address.bit(1):
    write(reload[num], value, address and 1)
  elif not address.bit(0): # top 8 bits aren't used
    # todo: this doesn't behave as expected. see cascade in tonc tmr_demo
    updateCounter(timer, num)
    let
      wasEnabled = tmcnt[num].enable
      wasCascade = tmcnt[num].cascade
    write(tmcnt[num], value, address and 1)
    if tmcnt[num].enable:
      if tmcnt[num].cascade:
        timer.gba.scheduler.clear(events[num])
      elif not wasEnabled or wasCascade:
        if not wasEnabled: counter[num] = reload[num]
        scheduleTimer(timer, num)
    elif wasEnabled:
      timer.gba.scheduler.clear(events[num])

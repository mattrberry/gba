import heapqueue

import types

proc `<`(a, b: Event): bool = a.cycles < b.cycles

proc newScheduler*(): Scheduler =
  new result
  result.events = initHeapQueue[Event]()
  for i in 0..<10: result.events.push(Event())
  for i in 0..<10: discard result.events.pop()
  result.nextEvent = high(uint64)

proc schedule*(scheduler: var Scheduler, cycles: uint64, callback: proc(), eventType = EventType.default) =
  let event = Event(cycles: cycles + scheduler.cycles, callback: callback, eventType: eventType)
  scheduler.events.push(event)
  scheduler.nextEvent = scheduler.events[0].cycles

proc tick*(scheduler: var Scheduler, cycles: int) =
  for _ in 0 ..< cycles:
    scheduler.cycles += 1
    while scheduler.nextEvent <= scheduler.cycles:
      scheduler.events.pop().callback()
      scheduler.nextEvent = if scheduler.events.len() > 0: scheduler.events[0].cycles else: high(uint64)

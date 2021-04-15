import ../scheduler, ../types

const
  waveDuty: array[4, array[8, int16]] = [
    [-8'i16, -8'i16, -8'i16, -8'i16, -8'i16, -8'i16, -8'i16, +8'i16], # 12.5%
    [+8'i16, -8'i16, -8'i16, -8'i16, -8'i16, -8'i16, -8'i16, +8'i16], # 25%
    [+8'i16, -8'i16, -8'i16, -8'i16, -8'i16, +8'i16, +8'i16, +8'i16], # 50%
    [-8'i16, +8'i16, +8'i16, +8'i16, +8'i16, +8'i16, +8'i16, -8'i16], # 75%
  ]

type
  Channel1* = ref object of Channel
    duty: int
    waveDutyPosition: int
    lengthLoad: int
    lengthCounter: int
    frequency: uint32

proc newChannel1*(scheduler: Scheduler): Channel1 =
  new result
  result.scheduler = scheduler
  result.duty = 3
  result.waveDutyPosition = 0
  result.lengthLoad = 0b110000
  result.lengthCounter = result.lengthLoad
  result.frequency = 0b1000000000'u32

proc scheduleReload*(channel: Channel1)

proc step(channel: Channel1): proc() = (proc() =
  channel.waveDutyPosition = (channel.waveDutyPosition + 1) and 7
  channel.scheduleReload())

proc lengthStep*(channel: Channel1) =
  discard # ignoring length counter

proc frequencyTimer*(channel: Channel1): uint32 =
  (0x800'u32 - channel.frequency) * 4 * 4

proc scheduleReload*(channel: Channel1) =
  channel.scheduler.schedule(channel.frequencyTimer(), channel.step(), EventType.apuChannel1)

# proc getAmplitude*(channel: Channel1): int16 =
#   waveDuty[channel.duty][channel.waveDutyPosition] * 0xF

proc getAmplitude*(channel: Channel1): float32 =
  waveDuty[channel.duty][channel.waveDutyPosition] / 8

proc trigger*(channel: Channel1) =
  channel.scheduleReload()

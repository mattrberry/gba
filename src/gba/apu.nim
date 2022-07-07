import math, sdl2/audio, system

import util, scheduler, types

const
  cpuClock = 2 ^ 24
  channels = 2 # Left / Right
  bufferSize = 1024 * 2
  sampleRate = 32768 # Hz
  samplePeriod = cpuClock div sampleRate # 512 Hz

var
  audioSpec: AudioSpec
  obtainedSpec: AudioSpec

  buffer = newSeq[float32]()

  soundbias: uint16

proc getSample(apu: APU): proc()

const
  freq = 1000 # hz
  
var x: float32 = 0
var y: float32 = 0

proc audioCallback(userdata: pointer, stream: ptr uint8, len: cint) {.cdecl.} =
  echo "Audio callback"
  
  if isNil(stream):
    echo "Stream is nil!"
    return

  if len div 4 div 2 != obtainedSpec.samples.int:
    echo "Len is wrong. ", obtainedSpec.samples.int, ", ", len
    # return

  # var stream = cast[ptr UncheckedArray[float32]](stream)

  # let targetSamples = obtainedSpec.samples.int
  # let actualSamples = buffer.len
  # echo "Target: ", targetSamples, ", actual: ", actualSamples
  # buffer.setLen(0)

  # sine wave
  # for i in 0 ..< obtainedSpec.samples.int:
  #   let sample = sin(x)
  #   stream[i * 2] = sample
  #   stream[i * 2 + 1] = sample
  #   x += 2 * PI / (obtainedSpec.freq / freq)

proc newAPU*(gba: GBA): APU =
  new result
  result.gba = gba

  audioSpec.freq = sampleRate
  audioSpec.format = AUDIO_F32
  audioSpec.channels = channels
  audioSpec.samples = bufferSize
  audioSpec.padding = 0
  audioSpec.callback = audioCallback
  audioSpec.userdata = nil

  if openAudio(addr audioSpec, addr obtainedSpec) != 0:
    quit "Couldn't open audio device."
  pauseAudio(0)

  echo audioSpec
  echo obtainedSpec

  # gba.scheduler.schedule(samplePeriod, result.getSample(), EventType.apu)

proc timerOverflow*(gba: GBA, timer: int) = discard

proc getSample(apu: APU): proc() = (proc() =
  apu.gba.scheduler.schedule(samplePeriod, apu.getSample(), EventType.apu)

  let sample = sin(y)
  buffer.add(sample) # left
  buffer.add(sample) # right
  y += 2 * PI / (obtainedSpec.freq / 1000)
)

proc `[]`*(apu: APU, address: SomeInteger): uint8 =
  case address
  of 0x88..0x89: readByte(soundBias, address and 1)
  of 0xA0..0xA7: 0 # dma channels
  else: echo "Unmapped APU read: ", address.toHex(8); 0

proc `[]=`*(apu: APU, address: SomeInteger, value: uint8) =
  case address
  of 0x88..0x89: writeByte(soundBias, address and 1, value)
  of 0xA0..0xA7:
    echo "Wrote ", value.toHex(8), " to ", address.toHex(8)
    let channel = bit(address, 2).uint
  else: discard # echo "Unmapped APU write: ", address.toHex(8), " = ", value.toHex(2)

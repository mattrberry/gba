import math, sdl2/audio, system, std/locks

import util, scheduler, types

const
  cpuClock = 2 ^ 24
  channels = 1 # todo support stereo
  bufferSize = 1024 * 2
  sampleRate = 32768 # Hz
  samplePeriod = cpuClock div sampleRate # 512 Hz

var
  audioSpec: AudioSpec
  obtainedSpec: AudioSpec
  bufferLock: Lock

  buffer = newSeq[float32]()

  soundbias: uint16

proc getSample(apu: APU): proc()

const
  freq = 1000 # hz

var x: float32 = 0
var y: float32 = 0

proc resample[From, To](fromBuf: openarray[From], toBuf: var openarray[To]) =
  let ratio = fromBuf.len / toBuf.len
  var
    points: array[4, From]
    mu: float32
    pos: int
  for idx, sample in fromBuf:
    points[0] = points[1]
    points[1] = points[2]
    points[2] = points[3]
    points[3] = sample
    while mu <= 1:
      let
        a = points[3] - points[2] - points[0] + points[1]
        b = points[0] - points[1] - a
        c = points[2] - points[0]
        d = points[1]
      let newSample = a * mu ^ 3 + b * mu ^ 2 + c * mu + d
      toBuf[pos] = newSample
      pos += 1
      if pos >= toBuf.len: return
      mu += ratio
    mu -= 1

proc audioCallback(userdata: pointer, stream: ptr uint8, len: cint) {.cdecl.} =
  if isNil(stream): quit "Stream is nil!"
  if len div sizeof(float32) div channels != obtainedSpec.samples.int:
    echo "Len is wrong. ", obtainedSpec.samples.int, ", ", len

  var stream = cast[ptr UncheckedArray[float32]](stream)
  acquire(bufferLock)
  resample(buffer, stream.toOpenArray(0, obtainedSpec.samples.int - 1))
  buffer.setLen(0)
  release(bufferLock)

  # sine wave
  # for i in 0 ..< obtainedSpec.samples.int:
  #   let sample = sin(x)
  #   stream[i * 2] = sample
  #   stream[i * 2 + 1] = sample
  #   x += 2 * PI / (obtainedSpec.freq / freq)

proc newAPU*(gba: GBA): APU =
  new result
  result.gba = gba

  initLock(bufferLock)

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

  # echo audioSpec
  # echo obtainedSpec

  gba.scheduler.schedule(samplePeriod, result.getSample(), EventType.apu)

proc timerOverflow*(gba: GBA, timer: int) = discard

proc getSample(apu: APU): proc() = (proc() =
  apu.gba.scheduler.schedule(samplePeriod, apu.getSample(), EventType.apu)

  let sample = sin(y) * 0.5
  acquire(bufferLock)
  buffer.add(sample) # todo support stereo
  release(bufferLock)
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

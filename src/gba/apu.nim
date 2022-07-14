import math, sdl2/audio, system, std/locks, times
import easywave
import util, scheduler, types, regs, dma

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

  soundcnt_l: SOUNDCNT_L
  soundcnt_h: SOUNDCNT_H
  soundcnt_x: SOUNDCNT_X
  soundbias: SOUNDBIAS

var original_riffwriter, resampled_riffwriter: RiffWriter

proc getSample(apu: APU): proc()

var
  points: array[4, float32]
  mu: float32
  lastTime: float = epochTime()

proc resample[From, To](fromBuf: openarray[From], toBuf: var openarray[To]) =
  let curTime = epochTime()
  let delta = int((curTime - lastTime) * 1000)
  lastTime = curTime
  # echo "(", delta, "ms) Resamping ", fromBuf.len, " ", From, " samples to ", toBuf.len, " ", To, " samples"
  let ratio = fromBuf.len / toBuf.len
  var pos: int
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
  original_riffwriter.write(buffer, 0, buffer.len)
  resampled_riffwriter.write(stream.toOpenArray(0, obtainedSpec.samples.int - 1), 0, obtainedSpec.samples.int)
  buffer.setLen(0)
  release(bufferLock)

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

  echo audioSpec
  echo obtainedSpec

  gba.scheduler.schedule(samplePeriod, result.getSample(), EventType.apu)

  original_riffwriter = createRiffFile("original.wav", FourCC_WAVE, littleEndian)
  resampled_riffwriter = createRiffFile("resampled.wav", FourCC_WAVE, littleEndian)

  original_riffwriter.writeFormatChunk(WaveFormat(
    sampleFormat: sfFloat,
    bitsPerSample: sizeof(float32) * 8,
    sampleRate: sampleRate,
    numChannels: channels,
  ))
  original_riffwriter.beginChunk(FourCC_WAVE_data)
  resampled_riffwriter.writeFormatChunk(WaveFormat(
    sampleFormat: sfFloat,
    bitsPerSample: sizeof(float32) * 8,
    sampleRate: obtainedSpec.freq,
    numChannels: channels,
  ))
  resampled_riffwriter.beginChunk(FourCC_WAVE_data)

proc close_wav_files*() =
  original_riffwriter.endChunk()
  resampled_riffwriter.endChunk()
  original_riffwriter.close()
  resampled_riffwriter.close()

var
  sizes: array[2, int32]
  positions: array[2, int32]
  latches: array[2, int32]
  fifos: array[2, array[32, int8]]
proc timerOverflow*(gba: GBA, timer: SomeInteger) =
  var timers = [soundcnt_h.timerDmaA.int, soundcnt_h.timerDmaB.int]
  echo "timer overflow"
  for channel in 0 .. 1:
    if timer == timers[channel]:
      if sizes[channel] > 0:
        echo "timer overflow good; channel:", channel, ", timer:", timer
      else:
        echo "timer overflow but empty; channel:", channel, ", timer:", timer
        latches[channel] = 0
    if sizes[channel] < 16:
      gba.triggerFifo(channel)

# var y: float32 = 0
proc getSample(apu: APU): proc() = (proc() =
  apu.gba.scheduler.schedule(samplePeriod, apu.getSample(), EventType.apu)

  let dma_a = latches[0] shl soundcnt_h.volDmaA
  let dma_b = latches[1] shl soundcnt_h.volDmaB
  let sampleInt8 = dma_a + dma_b
  let sample = float32(sampleInt8) / 128
  acquire(bufferLock)
  buffer.add(sample)
  release(bufferLock)

  # let sample = sin(y) * 0.5
  # acquire(bufferLock)
  # buffer.add(sample) # todo support stereo
  # release(bufferLock)
  # y += 2 * PI / (obtainedSpec.freq / 1000)
)

proc `[]`*(apu: APU, address: SomeInteger): uint8 =
  case address
  of 0x80..0x81: read(soundcnt_l, address and 1)
  of 0x82..0x83: read(soundcnt_h, address and 1)
  of 0x84..0x85: read(soundcnt_x, address and 1)
  of 0x88..0x89: read(soundBias, address and 1)
  of 0xA0..0xA7: 0 # dma channels
  else: echo "Unmapped APU read: ", address.toHex(8); 0

proc `[]=`*(apu: APU, address: SomeInteger, value: uint8) =
  case address
  of 0x80..0x81: write(soundcnt_l, value, address and 1)
  of 0x82..0x83: write(soundcnt_h, value, address and 1)
  of 0x84..0x85: write(soundcnt_x, value, address and 1)
  of 0x88..0x89: write(soundBias, value, address and 1)
  of 0xA0..0xA7:
    echo "Wrote ", value.toHex(8), " to ", address.toHex(8)
    let channel = bit(address, 2).uint
    if sizes[channel] < 32:
      echo "writing to fifo"
      fifos[channel][(positions[channel] + sizes[channel]) mod 32] = int8(value)
      sizes[channel] += 1
    else:
      echo "writing ", value, " to fifo ", char(channel + 65), ", but it's already full"
  else: discard # echo "Unmapped APU write: ", address.toHex(8), " = ", value.toHex(2)

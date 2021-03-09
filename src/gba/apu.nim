import math, sdl2/audio, system
from sdl2 import delay

import scheduler, types
import apu/[resampler, channel1]

const
  cpuClock = 2 ^ 24
  channels = 1 # Left / Right
  bufferSize = 1024
  sampleRate = 32768 # Hz
  samplePeriod = cpuClock div sampleRate
  frameSequencerRate = 512 # Hz
  frameSequencerPeriod = cpuClock div frameSequencerRate

var
  buffer: array[bufferSize, float32]
  bufferPos: int
  frameSequencerStage = 0

  audioSpec: AudioSpec
  obtainedSpec: AudioSpec

  dev: AudioDeviceID

  buf = newSeq[float32]()
  resample = newResampler[float32](buf)

  lastFreq = sampleRate

proc getSample(apu: APU): proc()
proc tickFrameSequencer(apu: APU): proc()

proc newAPU*(gba: GBA): APU =
  new result
  result.gba = gba
  result.channel1 = newChannel1(gba.scheduler)
  cast[Channel1](result.channel1).trigger()

  audioSpec.freq = sampleRate
  audioSpec.format = AUDIO_F32
  audioSpec.channels = channels
  audioSpec.samples = bufferSize
  audioSpec.callback = nil
  audioSpec.userdata = nil

  dev = openAudioDevice(nil, 0, addr audioSpec, addr obtainedSpec, SDL_AUDIO_ALLOW_FREQUENCY_CHANGE)
  pauseAudioDevice(dev, 0)

  resample.setFreqs(sampleRate, obtainedSpec.freq)

  gba.scheduler.schedule(samplePeriod, result.getSample(), EventType.apu)
  gba.scheduler.schedule(frameSequencerPeriod, result.tickFrameSequencer(), EventType.apu)

proc getSample(apu: APU): proc() = (proc() =
  apu.gba.scheduler.schedule(samplePeriod, apu.getSample(), EventType.apu)
  let channel1Amp = cast[Channel1](apu.channel1).getAmplitude()
  buffer[bufferPos] = channel1Amp
  bufferPos += 1
  resample.write(channel1Amp)

  if bufferPos >= bufferSize:
    # echo "Remaining queue: " & $getQueuedAudioSize(dev) & ", pushing: " & $(resample.output.len * sizeof(float32))
    when defined(emscripten):
      let
        maxDelta = 0.005
        fillLevel = getQueuedAudioSize(dev)
        # newFreq = int(((1.0 - maxDelta) + 2.0 * float(fillLevel) * maxDelta) * float(obtainedSpec.freq))
        newFreq = int((float(fillLevel) / bufferSize) * float(lastFreq))
      lastFreq = min(max(lastFreq - 10, newFreq), lastFreq + 10)
      resample.setFreqs(lastFreq, obtainedSpec.freq)
    else:
      while getQueuedAudioSize(dev) > bufferSize * sizeof(float32) * 2:
        delay(1)
    discard queueAudio(dev, unsafeAddr resample.output[0], uint32(resample.output.len * sizeof(float32)))
    bufferPos = 0
    resample.output.setLen(0)
)

proc tickFrameSequencer(apu: APU): proc() = (proc() =
  apu.gba.scheduler.schedule(frameSequencerPeriod, apu.tickFrameSequencer(), EventType.apu)
  case frameSequencerStage
  of 0:
    cast[Channel1](apu.channel1).lengthStep()
  of 2:
    cast[Channel1](apu.channel1).lengthStep()
  of 4:
    cast[Channel1](apu.channel1).lengthStep()
  of 6:
    cast[Channel1](apu.channel1).lengthStep()
  else: discard
  frameSequencerStage = (frameSequencerStage + 1) and 7)

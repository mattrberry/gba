import math, sdl2/audio
from sdl2 import delay

import scheduler, types
import apu/channel1

const
  cpuClock = 2 ^ 24
  channels = 2 # Left / Right
  bufferSize = 1024
  sampleRate = 32768 # Hz
  samplePeriod = cpuClock div sampleRate
  frameSequencerRate = 512 # Hz
  frameSequencerPeriod = cpuClock div frameSequencerRate

var
  buffer: array[bufferSize, int16]
  bufferPos: int
  frameSequencerStage = 0

  audioSpec: AudioSpec
  obtainedSpec: AudioSpec

  dev: AudioDeviceID

proc getSample(apu: APU): proc()
proc tickFrameSequencer(apu: APU): proc()

proc newAPU*(gba: GBA): APU =
  new result
  result.gba = gba
  result.channel1 = newChannel1(gba.scheduler)
  cast[Channel1](result.channel1).trigger()

  audioSpec.freq = sampleRate
  audioSpec.format = AUDIO_S16
  audioSpec.channels = channels
  audioSpec.samples = bufferSize
  audioSpec.callback = nil
  audioSpec.userdata = nil

  # if openAudio(addr audioSpec, addr obtainedSpec) > 0: quit "Failed to open audio"
  # pauseAudio(0)
  dev = openAudioDevice(nil, 0, addr audioSpec, addr obtainedSpec, SDL_AUDIO_ALLOW_FREQUENCY_CHANGE)
  pauseAudioDevice(dev, 0)
  
  gba.scheduler.schedule(samplePeriod, result.getSample(), EventType.apu)
  gba.scheduler.schedule(frameSequencerPeriod, result.tickFrameSequencer(), EventType.apu)

proc getSample(apu: APU): proc() = (proc() =
  apu.gba.scheduler.schedule(samplePeriod, apu.getSample(), EventType.apu)
  let
    channel1Amp = cast[Channel1](apu.channel1).getAmplitude()
    psgLeft = channel1Amp * 4
    psgRight = channel1Amp * 4
  buffer[bufferPos] = psgLeft * 32
  buffer[bufferPos + 1] = psgRight * 32
  bufferPos += 2

  if bufferPos >= bufferSize:
    while getQueuedAudioSize(dev) > bufferSize * sizeof(int16) * 2:
      delay(1)
    discard queueAudio(dev, addr buffer, bufferSize * sizeof(int16))
    bufferPos = 0
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

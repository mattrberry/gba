import algorithm

type
  Resampler*[T] = object
    data: array[4, T]
    ratio: float32
    mu: float32
    output*: seq[T]

proc newResampler*[T](output: seq[T]): Resampler[T] =
  result.mu = 0
  result.ratio = 1
  result.output = output

proc setFreqs*[T](resampler: var Resampler[T], inputFreq, outputFreq: int) =
  echo "input freq: " & $inputFreq & ", output freq: " & $outputFreq & ", ratio: " & $resampler.ratio & " -> " & $float32(inputFreq / outputFreq)
  resampler.ratio = float32(inputFreq / outputFreq)

proc reset*[T](resampler: var Resampler[T], inputFreq, outputFreq: int) =
  resampler.setFreqs(inputFreq, outputFreq)
  resampler.mu = 0
  resampler.data.fill(cast[T](0))
  resampler.output.setLen(0)

proc write*[T](resampler: var Resampler[T], sample: T) =
  resampler.data[0] = resampler.data[1]
  resampler.data[1] = resampler.data[2]
  resampler.data[2] = resampler.data[3]
  resampler.data[3] = sample
  while resampler.mu <= 1:
    let
      a = resampler.data[3] - resampler.data[2] - resampler.data[0] + resampler.data[1]
      b = resampler.data[0] - resampler.data[1] - a
      c = resampler.data[2] - resampler.data[0]
      d = resampler.data[1]
    resampler.output.add(a * resampler.mu * resampler.mu * resampler.mu + b * resampler.mu * resampler.mu + c * resampler.mu + d)
    resampler.mu += resampler.ratio
  resampler.mu -= 1

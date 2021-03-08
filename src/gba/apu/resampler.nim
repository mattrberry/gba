type
  Resampler[T] = ref object of RootObj

  CubicResampler[T] = ref object of Resampler
    data: array[4, T]

proc write[T]*(resampler: CubicResampler, sample: T) =
  discard


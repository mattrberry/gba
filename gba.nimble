# Package

version       = "0.1.0"
author        = "Matthew Berry"
description   = "A proof-of-concept gba emulator in nim"
license       = "MIT"
srcDir        = "src"
bin           = @["gba"]

# Dependencies

requires "nim >= 1.6.0"
requires "sdl2 >= 1.0"

task native, "native":
  exec "nim c -o:gba -d:release --gc:orc --threads:on --threadAnalysis:off src/gba.nim"

task wasm, "wasm":
  exec "nim c -d:emscripten -d:wasm -d:release src/gba.nim"

task test, "test":
  exec "nim c -r tests/runner.nim"
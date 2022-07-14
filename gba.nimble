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
requires "https://github.com/johnnovak/nim-riff"
requires "https://github.com/johnnovak/easywave"

task native, "native":
  exec "nim c -o:gba -d:release --gc:orc --threads:on src/gba.nim"

task wasm, "wasm":
  exec "nim c -d:emscripten -d:wasm -d:release src/gba.nim"

task test, "test":
  exec "nim c -r tests/runner.nim"
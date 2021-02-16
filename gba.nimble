# Package

version       = "0.1.0"
author        = "Matthew Berry"
description   = "A proof-of-concept gba emulator in nim"
license       = "MIT"
srcDir        = "src"
bin           = @["gba"]


# Dependencies

requires "nim >= 1.4.0"
requires "sdl2 >= 1.0"

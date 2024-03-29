when defined(emscripten):
  --os:linux
  --cpu:wasm32
  --gc:arc
  --cc:clang
  --clang.exe:emcc
  --clang.linkerexe:emcc
  --dynlibOverride:SDL2

  switch("passL", "-s WASM=1 -s USE_SDL=2 -s EXPORTED_RUNTIME_METHODS=ccall,cwrap -s EXPORTED_FUNCTIONS=_initFromEmscripten -s LINKABLE=1 -s EXPORT_ALL=1 -s ASSERTIONS=1 -s ALLOW_MEMORY_GROWTH=1 -O3 -o web/em.js --preload-file bios.bin")

const readToEmscriptenFileSystem = (filename, filter = "") => {
  return new Promise((resolve, reject) => {
    let input = document.createElement("input");
    input.type = "file";
    input.accept = filter;
    input.addEventListener("input", () => {
      if (input.files?.length > 0) {
        let reader = new FileReader();
        reader.addEventListener("load", () => {
          let bytes = new Uint8Array(reader.result);
          let stream = FS.open(filename, "w+");
          FS.write(stream, bytes, 0, bytes.length, 0);
          FS.close(stream);
          resolve(bytes);
        });
        reader.readAsArrayBuffer(input.files[0]);
      }
    });
    input.click();
  });
};

const pressButton = (keyCode, down = true) => {
  let event = new Event(down ? "keydown" : "keyup", {
    bubbles: true,
    cancelable: "true",
  });
  event.keyCode = keyCode;
  event.which = keyCode;
  document.dispatchEvent(event);
};

const reportFps = (fps) => {
  let element = document.getElementById("fps");
  element.innerHTML = `FPS: ${fps}`;
};

document
  .getElementById("open-bios")
  .addEventListener("click", () => readToEmscriptenFileSystem("bios.bin"));

document
  .getElementById("open-rom")
  .addEventListener("click", () =>
    readToEmscriptenFileSystem("rom.gba", ".gba").then(() =>
      Module.ccall("initFromEmscripten", null, [], [])
    )
  );

var currentDpad = null;

document.getElementById("dpad").addEventListener("touchstart", (event) => {
  let element = event.target;
  if (currentDpad == null && element.hasAttribute("button")) {
    let keyCode = element.getAttribute("button");
    pressButton(keyCode, true);
    currentDpad = keyCode;
  }
});

document.getElementById("dpad").addEventListener("touchend", (event) => {
  let touch = event.changedTouches[0];
  let element = document.elementFromPoint(touch.clientX, touch.clientY);
  if (element.hasAttribute("button")) {
    pressButton(element.getAttribute("button"), false);
    currentDpad = null;
  }
});

document.getElementById("dpad").addEventListener("touchmove", (event) => {
  event.preventDefault();
  let touch = event.touches[0];
  let element = document.elementFromPoint(touch.clientX, touch.clientY);
  if (element.hasAttribute("button")) {
    let keyCode = element.getAttribute("button");
    if (keyCode != currentDpad) {
      pressButton(currentDpad, false);
      pressButton(keyCode, true);
      currentDpad = keyCode;
    }
  } else if (currentDpad != null) {
    pressButton(currentDpad, false);
    currentDpad = null;
  }
});

document.querySelectorAll("[button]").forEach((element) =>
  element.addEventListener("touchstart", (event) => {
    pressButton(element.getAttribute("button"), true);
  })
);

document.querySelectorAll("[button]").forEach((element) =>
  element.addEventListener("touchend", (event) => {
    pressButton(element.getAttribute("button"), false);
  })
);

var Module = {
  canvas: (() => document.getElementById("canvas"))(),
};

// Make mobile Safari respond to button :active
document.addEventListener("touchstart", function () {}, false);

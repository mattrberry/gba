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

document.getElementById("open-bios").addEventListener("click",
    () => readToEmscriptenFileSystem("bios.bin"));

document.getElementById("open-rom").addEventListener("click",
    () => readToEmscriptenFileSystem("rom.gba", ".gba").then(
        () => Module.ccall('initFromEmscripten', null, [], [])));

var Module = {
    print: (() => {
        let element = document.getElementById('output');
        return text => element.innerHTML += text.replace('\n', '<br>', 'g') + '<br>'
    })(),
    canvas: (() => document.getElementById('canvas'))()
};
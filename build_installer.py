from pathlib import Path

URL_TEMPLATE = "https://github.com/MrVoustache/TurtleExplorerAPI/raw/refs/heads/main/source/{src_path}"
DOWNLOAD_COMMAND = "shell.run('wget {URL} /{src_path}')"
MKDIR_COMMAND = "fs.makeDir('/{src_path}')"





SRC_DIR = Path(__file__).parent / "source"
lines : list[str] = []

def include_dir(dir : Path):
    for file in dir.iterdir():
        file_path = str(file.relative_to(SRC_DIR)).replace("\\", "/")
        if file.is_file():
            lines.append(DOWNLOAD_COMMAND.format(src_path = file_path, URL = URL_TEMPLATE.format(src_path = file_path)))
        if file.is_dir():
            lines.append(MKDIR_COMMAND.format(src_path = file_path))
            include_dir(file)





include_dir(SRC_DIR)

with (Path(__file__).parent / "install.lua").open("w") as f:
    for line in lines:
        f.write(f"{line}\n")
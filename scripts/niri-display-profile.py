import hashlib
import json
import subprocess
import sys
import tempfile
import time
from collections import Counter
from pathlib import Path


def connected_outputs():
    return json.loads(subprocess.check_output(
        ["niri", "msg", "--json", "outputs"], text=True, timeout=5,
    ))


def profile_path(directory, outputs):
    identities = [
        [name, output["make"], output["model"], output["serial"], output["physical_size"]]
        for name, output in sorted(outputs.items())
    ]
    key = hashlib.sha256(json.dumps(identities).encode()).hexdigest()
    return directory / f"{key}.kdl"


def render_outputs(outputs, save_settings):
    selectors = {
        name: f"{output['make']} {output['model']} {output['serial']}"
        if output["serial"] else name
        for name, output in outputs.items()
    }
    counts = Counter(selectors.values())
    lines = []
    for name, output in sorted(outputs.items()):
        selector = selectors[name]
        if counts[selector] != 1:
            selector = name
        lines.append(f"output {json.dumps(selector, ensure_ascii=False)} {{")
        if save_settings:
            logical = output["logical"]
            index = output["current_mode"]
            if logical is None or index is None:
                lines.append("    off")
            else:
                mode = output["modes"][index]
                hz = mode["refresh_rate"] / 1000
                custom = " custom=true" if output["is_custom_mode"] else ""
                lines.extend([
                    f'    mode{custom} "{mode["width"]}x{mode["height"]}@{hz:.3f}"',
                    f'    scale {logical["scale"]}',
                    f'    position x={logical["x"]} y={logical["y"]}',
                    f'    transform "{logical["transform"].lower().replace("flipped", "flipped-").rstrip("-")}"',
                ])
                if output["vrr_enabled"]:
                    lines.append("    variable-refresh-rate")
        lines.append("}")
    return "\n".join(lines) + "\n"


def write_config(path, contents, validate=False):
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
        temporary = Path(file.name)
        file.write(contents)
    try:
        if validate:
            subprocess.run(["niri", "validate", "--config", temporary], check=True)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def watch(directory, active):
    previous = None
    while True:
        outputs = connected_outputs()
        profile = profile_path(directory, outputs)
        try:
            contents = profile.read_text()
        except FileNotFoundError:
            # Include an empty output section per display to clear the previous
            # layout on a topology change while letting Niri pick the defaults.
            contents = render_outputs(outputs, save_settings=False)
        current = profile, contents
        if current != previous:
            write_config(active, contents)
            previous = current
        time.sleep(2)


def save(directory):
    outputs = connected_outputs()
    if not any(output["logical"] is not None for output in outputs.values()):
        raise ValueError("켜져 있는 모니터가 없습니다.")
    profile = profile_path(directory, outputs)
    write_config(profile, render_outputs(outputs, save_settings=True), validate=True)
    print(profile)


def notify(message):
    subprocess.run(["notify-send", "모니터 설정", message], check=False)


def main(directory, action):
    active = directory / "active.kdl"
    if action == "clear":
        active.unlink(missing_ok=True)
        return
    directory.mkdir(parents=True, exist_ok=True)
    if action == "watch":
        watch(directory, active)
    elif action == "save":
        try:
            save(directory)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            notify(f"모니터 배치를 저장하지 못했습니다. {error}")
            raise
        notify("현재 연결 조합의 모니터 배치를 저장했습니다.")


if __name__ == "__main__":
    main(Path(sys.argv[1]), sys.argv[2])

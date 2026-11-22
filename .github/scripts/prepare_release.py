import re
import sys
from datetime import datetime
from pathlib import Path


def prepare_release(branch: str, output: Path) -> None:
    channel = re.fullmatch(r"([1-9][0-9]*)\.x", branch)
    if not channel:
        raise SystemExit("Релизы публикуются из веток вида X.x.")

    component = r"(?:0|[1-9][0-9]*)"
    root = Path(__file__).resolve().parents[2]
    config = (root / "vm_menu/bash_scripts/config.sh").read_text(encoding="utf-8")
    config_versions = re.findall(r'^BS_VERSION_MENU="([^"\n]+)"[ \t]*$', config, re.MULTILINE)
    version_pattern = rf"{channel[1]}\.{component}\.{component}"
    if len(config_versions) != 1 or not re.fullmatch(version_pattern, config_versions[0]):
        raise SystemExit(f"Укажите в BS_VERSION_MENU версию формата {channel[1]}.Y.Z для ветки {branch}.")
    version = config_versions[0]

    changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8").splitlines()
    headings = [index for index, line in enumerate(changelog) if line.startswith("## ")]
    matching = [index for index in headings if changelog[index].startswith(f"## {version} - ")]
    if len(matching) != 1:
        raise SystemExit(f"Добавьте ровно один раздел для версии {version} в CHANGELOG.md.")

    start = matching[0]
    end = next((index for index in headings if index > start), len(changelog))
    title = changelog[start][3:].rstrip()
    heading = re.fullmatch(
        rf"{re.escape(version)} - ([0-9]{{2}}\.[0-9]{{2}}\.[0-9]{{4}}) - (\S.*)", title
    )
    if not heading:
        raise SystemExit("Заголовок раздела должен иметь формат «X.Y.Z - ДД.ММ.ГГГГ - Название».")
    try:
        datetime.strptime(heading[1], "%d.%m.%Y")
    except ValueError:
        raise SystemExit("Укажите действительную дату релиза в CHANGELOG.md.") from None
    if not any(line.strip() for line in changelog[start + 1 : end]):
        raise SystemExit(f"Добавьте описание версии {version} в CHANGELOG.md.")

    output.mkdir(parents=True, exist_ok=True)
    (output / "title.txt").write_text(title + "\n", encoding="utf-8", newline="\n")
    notes = "\n".join(changelog[start:end]).rstrip() + "\n"
    (output / "notes.md").write_text(notes, encoding="utf-8", newline="\n")
    (output / "tag.txt").write_text(f"v{version}-stable\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Использование: prepare_release.py <ветка> <каталог результата>")
    prepare_release(sys.argv[1], Path(sys.argv[2]))

"""Entry point for the `nolo-apps` console command.

Runs the bundled Bash TUI with the terminal attached, so the interactive
menu, arrow keys and sudo prompts all work as they do when run directly.
"""

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).with_name("nolo-apps.sh")


def main() -> int:
    if sys.platform != "darwin":
        print("nolo-apps only runs on macOS.", file=sys.stderr)
        return 1
    try:
        return subprocess.call(["/bin/bash", str(SCRIPT), *sys.argv[1:]])
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())

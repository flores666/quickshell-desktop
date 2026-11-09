"""A pkexec boundary that cannot reach the real administrator helper."""
import os
from pathlib import Path

location = os.environ.get("TEST_BIN", "")
if not location:
    raise RuntimeError("Run through tools/test.sh")
directory = Path(location)
path = directory / "pkexec"
path.write_text('#!/usr/bin/python3 -I\nimport json\nimport os\nfrom pathlib import Path\nimport sys\np = Path(os.environ["TEST_BIN"])\nwith (p / "requests").open("a") as output:\n    output.write(json.dumps(sys.argv[1:]) + "\\n")\nsys.exit(int((p / "answer").read_text()))\n')
path.chmod(0o755)
(directory / "answer").write_text("0")

from __future__ import annotations

import importlib.util
import inspect
from pathlib import Path
import sys
import traceback

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def load_module(path: Path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    failures = 0
    tests_run = 0
    for path in sorted(Path(__file__).parent.glob("test_*.py")):
        module = load_module(path)
        for name, func in sorted(inspect.getmembers(module, inspect.isfunction)):
            if not name.startswith("test_"):
                continue
            tests_run += 1
            try:
                func()
            except Exception:
                failures += 1
                print(f"FAILED {path.name}::{name}")
                traceback.print_exc()
    if failures:
        print(f"{tests_run - failures} passed, {failures} failed")
        return 1
    print(f"{tests_run} passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

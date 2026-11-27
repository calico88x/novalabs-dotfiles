
#!/usr/bin/env python3
"""Validate NovaLabs bootstrap presentation using real pseudo-terminals.

Development-only regression suite. Uses Python's standard library.
No enrollment, installation or system mutation is performed.
"""

import errno
import fcntl
import os
import pty
import re
import select
import signal
import struct
import subprocess
import termios
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TIMEOUT = 15
CURSOR_UP = b"\x1b[7A"
ESCAPE = b"\x1b"

PROBE = """
. ./scripts/lib/bootstrap-ui.sh
nl_ui_init "$PWD"

printf 'COLOR=%s\\n' "$NL_UI_COLOR_MODE"
printf 'COLUMNS=%s\\n' "$NL_UI_COLUMNS"
printf 'ROWS=%s\\n' "$NL_UI_ROWS"
printf 'GEOMETRY=%s\\n' "$NL_UI_GEOMETRY_KNOWN"
printf 'ANIMATION=%s\\n' "$NL_UI_ANIMATE"

nl_ui_animate_logo
printf 'RENDER_COMPLETE\\n'
"""

passed = 0


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def passed_test(name):
    global passed
    passed += 1
    print(f"PASS: {name}")


def set_geometry(fd, columns, rows):
    fcntl.ioctl(
        fd,
        termios.TIOCSWINSZ,
        struct.pack("HHHH", rows, columns, 0, 0),
    )


def run_terminal(
    columns=100,
    rows=30,
    overrides=None,
    resize=False,
    probe=PROBE,
):
    env = os.environ.copy()

    # Isolate the test from inherited presentation overrides.
    for name in (
        "NO_COLOR",
        "CI",
        "COLORTERM",
        "COLUMNS",
        "LINES",
        "NL_UI_PLAIN",
        "NL_UI_NO_ANIMATION",
    ):
        env.pop(name, None)

    env.update({
        "TERM": "xterm-256color",
        "LC_ALL": "C.UTF-8",
    })

    if overrides:
        env.update(overrides)

    master, slave = pty.openpty()

    process = None
    output = bytearray()
    resized = False
    resize_redraw_count = 0

    try:
        set_geometry(slave, columns, rows)

        process = subprocess.Popen(
            ["sh", "-eu", "-c", probe],
            cwd=ROOT,
            env=env,
            stdin=slave,
            stdout=slave,
            stderr=slave,
            start_new_session=True,
        )

        os.close(slave)
        slave = None

        deadline = time.monotonic() + TIMEOUT

        while True:
            remaining = deadline - time.monotonic()

            if remaining <= 0:
                raise TimeoutError(
                    "Presentation probe exceeded timeout"
                )

            readable, _, _ = select.select(
                [master],
                [],
                [],
                min(0.1, remaining),
            )

            if not readable:
                if process.poll() is not None:
                    break
                continue

            try:
                chunk = os.read(master, 65536)
            except OSError as exc:
                if exc.errno == errno.EIO:
                    break
                raise

            if not chunk:
                break

            output.extend(chunk)

            if (
                resize
                and not resized
                and CURSOR_UP in output
            ):
                resize_redraw_count = output.count(CURSOR_UP)

                set_geometry(master, 40, 12)
                resized = True

        status = process.wait(timeout=2)

        require(
            status == 0,
            f"Presentation probe exited with status {status}",
        )

        result = bytes(output).replace(b"\r\n", b"\n")

        require(
            b"RENDER_COMPLETE\n" in result,
            "Presentation did not complete",
        )

        return result, resized, resize_redraw_count

    finally:
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()

        if slave is not None:
            os.close(slave)

        os.close(master)


def check_field(output, name, value):
    expected = f"{name}={value}".encode()

    require(
        expected in output.splitlines(),
        f"Expected terminal field: {expected!r}",
    )


def check_animated(output):
    require(
        output.count(CURSOR_UP) == 22,
        "Expected exactly 22 cursor redraw operations",
    )

    check_field(output, "ANIMATION", "true")


def check_static(output):
    require(
        CURSOR_UP not in output,
        "Unexpected cursor redraw in static presentation",
    )


def main():
    print("NovaLabs pseudo-terminal presentation validation")
    print("=" * 60)

    # 1. Actual terminal geometry and ANSI 256-color animation.
    output, _, _ = run_terminal(177, 28)

    check_field(output, "COLOR", "256")
    check_field(output, "COLUMNS", "177")
    check_field(output, "ROWS", "28")
    check_field(output, "GEOMETRY", "true")
    check_animated(output)

    require(
        b"\x1b[38;5;" in output,
        "ANSI 256-color gradient missing",
    )

    passed_test("Live geometry and ANSI 256-color animation")

    # 2. Truecolor animation.
    output, _, _ = run_terminal(
        overrides={"COLORTERM": "truecolor"},
    )

    check_field(output, "COLOR", "truecolor")
    check_animated(output)

    require(
        b"\x1b[38;2;" in output,
        "Truecolor gradient missing",
    )

    passed_test("Truecolor animation")

    # 3. Minimum animation geometry.
    output, _, _ = run_terminal(68, 10)

    check_field(output, "COLUMNS", "68")
    check_field(output, "ROWS", "10")
    check_animated(output)

    passed_test("Minimum animation geometry")

    # 4. Narrow terminal.
    output, _, _ = run_terminal(40, 24)

    check_field(output, "COLUMNS", "40")
    check_field(output, "ANIMATION", "false")
    check_static(output)

    passed_test("Narrow terminal static fallback")

    # 5. Insufficient terminal height.
    output, _, _ = run_terminal(100, 9)

    check_field(output, "ROWS", "9")
    check_field(output, "ANIMATION", "false")
    check_static(output)

    passed_test("Insufficient terminal height fallback")

    # 6. Explicit animation opt-out.
    output, _, _ = run_terminal(
        overrides={"NL_UI_NO_ANIMATION": "true"},
    )

    check_field(output, "ANIMATION", "false")
    check_static(output)

    require(
        b"\x1b[38;5;" in output,
        "Static color rendering was lost",
    )

    passed_test("Explicit animation opt-out")

    # 7. NO_COLOR compatibility.
    output, _, _ = run_terminal(
        overrides={"NO_COLOR": "1"},
    )

    check_field(output, "COLOR", "plain")
    check_field(output, "ANIMATION", "false")

    require(
        ESCAPE not in output,
        "ANSI escapes found in NO_COLOR presentation",
    )

    passed_test("NO_COLOR compatibility")

    # 8. CI compatibility.
    output, _, _ = run_terminal(
        overrides={"CI": "true"},
    )

    check_field(output, "COLOR", "plain")
    check_field(output, "ANIMATION", "false")

    require(
        ESCAPE not in output,
        "ANSI escapes found in CI presentation",
    )

    passed_test("CI plain-text compatibility")

    # 9. Unsupported Unicode locale.
    output, _, _ = run_terminal(
        overrides={"LC_ALL": "C"},
    )

    check_static(output)

    require(
        "█".encode() not in output,
        "Unicode bitmap rendered in the C locale",
    )

    require(
        b"NovaLabs\nDECLARATIVE INFRASTRUCTURE\n" in output,
        "Textual branding fallback missing",
    )

    passed_test("Non-UTF-8 branding fallback")

    # 10. Live terminal resize.
    output, resized, redraw_count = run_terminal(
        resize=True,
    )

    require(resized, "Resize test did not trigger")

    # One additional redraw may already be in flight when
    # the geometry changes. Further playback must stop.
    require(
        output.count(CURSOR_UP) <= redraw_count + 1,
        "Animation continued after terminal resize",
    )

    require(
        output.count(CURSOR_UP) < 22,
        "Animation did not terminate early after resize",
    )

    passed_test("Live terminal resize protection")

    # 11. Final animation frame matches the static frame.
    animated, _, _ = run_terminal()

    static, _, _ = run_terminal(
        overrides={"NL_UI_NO_ANIMATION": "true"},
    )

    final_frame = animated.rsplit(CURSOR_UP, 1)[1]
    final_frame = final_frame.lstrip(b"\r")

    static_body = static.split(
        b"ANIMATION=false\n",
        1,
    )[1].lstrip(b"\n")

    final_frame = re.sub(
        rb"\x1b\[[0-9;]*m",
        b"",
        final_frame,
    )

    static_body = re.sub(
        rb"\x1b\[[0-9;]*m",
        b"",
        static_body,
    )

    final_frame = final_frame.split(
        b"RENDER_COMPLETE",
        1,
    )[0].rstrip()

    static_body = static_body.split(
        b"RENDER_COMPLETE",
        1,
    )[0].rstrip()

    require(
        final_frame == static_body,
        "Final animation geometry differs from static branding",
    )

    passed_test("Final animation frame consistency")

    # Production entry point; no apply arguments are used.
    for args, overrides, animated_expected, color, name in (
        ("", {}, True, b"\x1b[38;5;", "Production 256-color animation"),
        ("", {"COLORTERM": "truecolor"}, True, b"\x1b[38;2;", "Production truecolor animation"),
        ("--no-animation", {}, False, b"\x1b[38;5;", "Production static color"),
        ("--plain", {}, False, None, "Production plain CLI"),
        ("", {"NO_COLOR": "1"}, False, None, "Production NO_COLOR"),
        ("", {"CI": "true"}, False, None, "Production CI plain mode"),
    ):
        output, _, _ = run_terminal(
            177, 28, overrides=overrides,
            probe=f"sh ./install.sh {args}\nprintf 'RENDER_COMPLETE\\n'\n",
        )
        if animated_expected:
            require(output.count(CURSOR_UP) == 22, "Production animation redraw count differs")
        else:
            check_static(output)
        if color is None:
            require(ESCAPE not in output, "Production plain mode contains ANSI")
        else:
            require(color in output, "Production gradient missing")
        visible = re.sub(rb"\x1b\[[0-9;]*m", b"", output)
        for marker in (b"BOOTSTRAP PREVIEW", b"SYSTEM IDENTITY", b"PREVIEW COMPLETE", b"No changes were made."):
            require(marker in visible, f"Production preview missing {marker!r}")
        passed_test(name)

    print("=" * 60)
    print(f"PASS: All {passed} PTY checkpoints validated")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, TimeoutError, OSError) as exc:
        raise SystemExit(f"FAIL: {exc}")

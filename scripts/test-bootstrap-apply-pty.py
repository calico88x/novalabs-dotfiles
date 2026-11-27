#!/usr/bin/env python3
"""Run the isolated full apply fixture in a real controlling PTY (Linux)."""
import errno
import os
import pty
import re
import select
import signal
import struct
import sys
import termios
import fcntl
import time
from pathlib import Path


def main():
    fixture, home, bin_dir, tmp, trace, output, scenario = sys.argv[1:]
    if scenario not in ('success', 'interrupt'):
        raise ValueError('unknown scenario')
    env = dict(PATH=bin_dir + ':/usr/bin:/bin', HOME=home, TMPDIR=tmp,
               TRACE=trace, FIXTURE=fixture, FIXTURE_BIN=bin_dir,
               LC_ALL='C.UTF-8', TERM='xterm-256color')
    pid, fd = pty.fork()
    if pid == 0:
        try:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack('HHHH', 30, 100, 0, 0))
            attrs = termios.tcgetattr(0)
            attrs[3] |= termios.ISIG
            attrs[6][termios.VINTR] = b'\x03'
            termios.tcsetattr(0, termios.TCSANOW, attrs)
            os.execve('/bin/sh', ['sh', fixture + '/install.sh', '--apply', '--no-animation'] + (['--prune'] if scenario == 'interrupt' else []), env)
        finally:
            os._exit(98)
    data = bytearray()
    sent = False
    reaped = False
    try:
        deadline = time.monotonic() + 25
        while time.monotonic() < deadline:
            if not select.select([fd], [], [], 0.1)[0]:
                continue
            try:
                chunk = os.read(fd, 65536)
            except OSError as exc:
                if exc.errno == errno.EIO:
                    break
                raise
            if not chunk:
                break
            data.extend(chunk)
            if scenario == 'interrupt' and not sent and b'NATIVE_AUDIT_OUTPUT' in data:
                os.write(fd, b'\x03')
                sent = True
        else:
            raise TimeoutError('apply PTY timeout')
        while time.monotonic() < deadline:
            done, wait_status = os.waitpid(pid, os.WNOHANG)
            if done:
                reaped = True
                break
            time.sleep(0.02)
        else:
            raise TimeoutError('apply child did not exit')
        status = os.waitstatus_to_exitcode(wait_status)
        expected = 130 if scenario == 'interrupt' else 0
        assert status == expected, (status, expected)
        visible = re.sub(rb'\x1b\[[0-9;]*m', b'', data)
        assert b'\x1b[38;5;' in data, 'color missing'
        assert data.rstrip().endswith(b'\x1b[0m'), 'final reset missing'
        assert (b'BOOTSTRAP FAILED' if sent else b'BOOTSTRAP COMPLETE') in visible
        if scenario == 'interrupt':
            assert sent and b'interrupted by INT' in visible
            assert b'NATIVE_PRUNE_OUTPUT' not in visible
        assert b'BLOCKED:' not in Path(trace).read_bytes()
    finally:
        Path(output).write_bytes(data)
        if not reaped:
            try: os.killpg(pid, signal.SIGKILL)
            except ProcessLookupError: pass
            os.waitpid(pid, 0)
        os.close(fd)


if __name__ == '__main__':
    main()

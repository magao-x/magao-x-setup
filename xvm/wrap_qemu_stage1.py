import subprocess
import time
import sys
import socket

print(sys.argv)

proc = subprocess.Popen(
    sys.argv[1:] + ["-monitor", "tcp:localhost:4444,server,nowait"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=False,
)

sock = None
last_line = b''
skipped = False

while True:
    line = proc.stdout.read(128)
    if not line:
        break  # QEMU exited

    sys.stdout.buffer.write(repr(line).encode('utf8'))
    sys.stdout.buffer.flush()

    if sock is None:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(("localhost", 4444))
        print("Connected to localhost:4444")

    full_line = last_line + line
    if b"Test this media" in full_line:
        print("Detected boot prompt! Sending keys...", file=sys.stderr)
        time.sleep(0.1)
        sock.sendall(b"sendkey up\n")
        time.sleep(0.1)
        sock.sendall(b"sendkey ret\n")
        last_line = b''
    if b"Press [Esc] to abort check." in full_line or b"Checking: " in full_line:
        print("Detected media integrity prompt! Sending keys...", file=sys.stderr)
        time.sleep(0.1)
        sock.sendall(b"sendkey esc\n")
        time.sleep(0.5)
        sock.sendall(b"sendkey esc\n")
        last_line = b''
    else:
        last_line = line

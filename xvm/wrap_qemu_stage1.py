import subprocess
import time
import sys
import socket
import os
qemuPort = int(os.environ.get('qemuPort', 4444))
print(sys.argv)

# Trick to grab an almost-certainly-unused port number
temp = socket.socket()
temp.bind(("", 0))
qemuPort = temp.getsockname()[1]
temp.close()

proc = subprocess.Popen(
    sys.argv[1:] + ["-monitor", f"tcp:localhost:{qemuPort},server,nowait"],
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

    print(repr(line).encode('utf8'))
    sys.stdout.buffer.flush()

    if sock is None:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(("localhost", qemuPort))
        print(f"Connected to localhost:{qemuPort}")

    full_line = last_line + line
    if b"Test this media" in full_line:
        print("Detected boot prompt! Sending keys...", file=sys.stderr)
        time.sleep(0.1)
        sock.sendall(b"sendkey up\n")
        time.sleep(0.1)
        sock.sendall(b"sendkey ret\n")
        last_line = b''
    elif b"Press [Esc] to abort check." in full_line:
        print("Detected media integrity prompt! Sending keys...", file=sys.stderr)
        time.sleep(0.1)
        sock.sendall(b"sendkey esc\n")
        time.sleep(0.5)
        sock.sendall(b"sendkey esc\n")
        last_line = b''
    elif b"Checking:" in full_line:
        print("Somehow it's still going.")
        proc.kill()
        sys.exit(1)
    else:
        last_line = line

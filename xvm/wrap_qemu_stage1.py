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
last_line = None
skipped = False

while True:
    line = proc.stdout.read(128)
    if not line:
        break  # QEMU exited

    sys.stdout.buffer.write(line)
    sys.stdout.buffer.flush()

    if sock is None:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(("localhost", 4444))
        print("Connected to localhost:4444")


    if last_line is None:
        last_line = b''

    if not skipped:
        full_line = last_line + line
        if b"Test this media" in full_line:
            print("Detected boot prompt! Sending keys...")
            time.sleep(0.1)
            sock.sendall(b"sendkey up\n")
            time.sleep(0.1)
            sock.sendall(b"sendkey ret\n")
            skipped = True
        if b"Press [Esc] to abort check." in full_line or b"Checking: " in full_line:
            print("Detected media integrity prompt! Sending keys...")
            time.sleep(0.1)
            sock.sendall(b"sendkey esc\n")
            time.sleep(0.5)
            sock.sendall(b"sendkey esc\n")
            skipped = True
        else:
            last_line = line

import subprocess
import time
import sys
import socket

print(sys.argv)

proc = subprocess.Popen(
    sys.argv[1:] + ["-monitor", "tcp:localhost:4444,server,nowait"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    text=False,
)

sock = None
last_line = None
skipped_menu = False

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

    if b"Test this media" in last_line + line:
        print("Detected boot prompt! Sending keys...")
        time.sleep(0.1)
        sock.sendall(b"sendkey up\n")
        time.sleep(0.1)
        sock.sendall(b"sendkey ret\n")
        skipped_menu = True
    else:
        last_line = line

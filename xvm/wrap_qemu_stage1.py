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

# Use that port number to launch QEMU with a monitor socket listening
proc = subprocess.Popen(
    sys.argv[1:] + ["-monitor", f"tcp:localhost:{qemuPort},server,nowait"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    encoding='utf8',
)

# Connect to the monitor socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(("localhost", qemuPort))
print(f"Connected to localhost:{qemuPort}")

while True:
    line = proc.stdout.readline()
    if not line:
        break  # QEMU exited

    print(line)
    sys.stdout.buffer.flush()

    if "Test this media" in line:
        print("Detected boot prompt! Sending keys...", file=sys.stderr)
        time.sleep(0.1)
        sock.sendall(b"sendkey up\n")
        time.sleep(0.1)
        sock.sendall(b"sendkey ret\n")
        last_line = b''
    elif "Press [Esc] to abort check." in line:
        print("Detected media integrity prompt! Sending keys...", file=sys.stderr)
        time.sleep(0.1)
        sock.sendall(b"sendkey esc\n")
        time.sleep(0.5)
        sock.sendall(b"sendkey esc\n")
        last_line = b''
    elif "Checking:" in line:
        print("Somehow it's still going.")
        proc.kill()
        sys.exit(1)

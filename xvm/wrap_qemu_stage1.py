import subprocess
import time
import sys
import socket
import os
qemu_port = int(os.environ.get('qemuPort', 4444))

# Trick to grab an almost-certainly-unused port number
temp = socket.socket()
temp.bind(("", 0))
qemu_port = temp.getsockname()[1]
temp.close()

# Use that port number to launch QEMU with a monitor socket listening
qemu_args = sys.argv[1:] + ["-monitor", f"tcp:localhost:{qemu_port},server,nowait"]
print('Launching QEMU...')
print(' '.join(qemu_args))
proc = subprocess.Popen(
    qemu_args,
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    encoding='utf8',
)

retries = 10
retry_sec = 2
connected = False
for i in range(retries):
    try:
        # Connect to the monitor socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(("localhost", qemu_port))
        connected = True
    except Exception as e:
        print(e)
        print(f"Retry {i+1}/{retries} in {retry_sec} sec...")
        time.sleep(retry_sec)

if connected:
    print(f"Connected to localhost:{qemu_port}")
else:
    print("Unable to connect to QEMU monitor port")
    sys.exit(1)

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

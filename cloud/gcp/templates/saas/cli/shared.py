import random
import shlex
import string
import subprocess

def shell(cmd):
    popen = subprocess.Popen(
        shlex.split(cmd),
        stderr=subprocess.PIPE,
        bufsize=1,
        universal_newlines=True)
    try:
        exit_code = popen.wait()
        _, stderr = popen.communicate()
        if exit_code > 0:
            print(stderr)
            raise RuntimeError(f'subcommand failed: {cmd}')
    except KeyboardInterrupt:
        # Allow terraform to gracefully exit if a user Ctrl+C's out of the command
        popen.terminate()

def generate_random_string(length: int):
    allowed_chars = string.ascii_letters + string.digits + '!#$&*+-=?^~|`'
    return ''.join(random.choice(allowed_chars) for _ in range(length))

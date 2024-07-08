import builtins
import sys


def print(*args, **kwargs):
    kwargs["file"] = sys.stderr
    kwargs["flush"] = True
    builtins.print(*args, **kwargs)

BLACK = '\033[30m'
RED = '\033[31m'
GREEN = '\033[32m'
YELLOW = '\033[33m'
BLUE = '\033[34m'
MAGENTA = '\033[35m'
CYAN = '\033[36m'
WHITE = '\033[37m'
END = '\033[0m'


def colorize(color, text):
    return color + text + END


def black(text):
    return colorize(BLACK, text)


def red(text):
    return colorize(RED, text)


def green(text):
    return colorize(GREEN, text)


def yellow(text):
    return colorize(YELLOW, text)


def blue(text):
    return colorize(BLUE, text)


def magenta(text):
    return colorize(MAGENTA, text)


def cyan(text):
    return colorize(CYAN, text)


def white(text):
    return colorize(WHITE, text)

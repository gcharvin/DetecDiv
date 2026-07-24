CALL_COUNT = 0


def run(value=None):
    global CALL_COUNT
    CALL_COUNT += 1
    return f"{value}:{CALL_COUNT}"

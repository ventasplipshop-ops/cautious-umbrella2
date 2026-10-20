import random
import time

SHORT = (2, 5)
MEDIUM = (6, 12)
LONG = (15, 30)

def human_delay(level="medium"):

    ranges = {
        "short": SHORT,
        "medium": MEDIUM,
        "long": LONG
    }

    r = ranges[level]
    delay = random.uniform(r[0], r[1])

    print(f"[delay] sleeping {delay:.2f}s")
    time.sleep(delay)
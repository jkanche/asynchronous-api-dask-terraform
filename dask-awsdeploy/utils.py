import os

__author__ = "jkanche"
__copyright__ = "jkanche"
__license__ = "MIT"


def get_env(key: str):
    rval = os.getenv(key)

    if rval is None or len(rval) == 0:
        raise Exception(f"'{key}' not found in environment!")

    return rval

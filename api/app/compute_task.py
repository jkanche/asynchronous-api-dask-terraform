import json

from dask import delayed

from .redis_client import rconnect

__author__ = "jkanche"
__copyright__ = "jkanche"
__license__ = "MIT"

REDIS_CACHE = rconnect()


def fib(n: int):
    if n < 2:
        return n
    else:
        return fib(n - 1) + fib(n - 2)


def dask_compute_fibonacci(payload: dict, rkey: str):
    key_params = json.loads(REDIS_CACHE.get(rkey))

    try:
        fib_future = delayed(fib)(payload["n"])
        result_fib = fib_future.compute()

        key_params["status"] = "DONE"
        key_params["result"] = {"value": result_fib}
        REDIS_CACHE.set(rkey, json.dumps(key_params))
    except Exception as e:
        key_params["status"] = "FAILED"
        key_params["error"] = str(e)
        REDIS_CACHE.set(rkey, json.dumps(key_params))


def get_result(task_id: str):
    try:
        redis_result = REDIS_CACHE.get(task_id)
        # error checking
        if redis_result is None:
            raise Exception(f"task_id not found: {task_id}")

        def json_parser(arg):
            c = {"NaN": "NA"}
            return c[arg]

        # replace NaN with NA
        replaced = json.loads(redis_result, parse_constant=json_parser)
        return replaced
    except Exception as e:
        raise Exception("Failed to load result.")

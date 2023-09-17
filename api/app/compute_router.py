import hashlib
import json

from distributed import fire_and_forget
from fastapi import APIRouter, Request

from .compute_task import (
    dask_compute_fibonacci,
    get_result,
)
from .redis_client import rconnect

__author__ = "jkanche"
__copyright__ = "jkanche"
__license__ = "MIT"


REDIS_CACHE = rconnect()
fibo = APIRouter()


def get_key(params):
    return hashlib.md5(json.dumps(params).encode("utf-8")).hexdigest()


@fibo.post("/compute/{n}", status_code=201)
async def compute_fibo(
    n: int,
    request: Request,
):
    key_params = {
        "type": "compute_fibo",
        "input": n,
    }

    rkey = get_key(key_params)
    if not REDIS_CACHE.get(rkey):
        REDIS_CACHE.set(
            rkey,
            json.dumps({"params": key_params, "status": "PENDING", "result": None}),
        )

        # dask fire and forget
        task_future = request.app.dask.submit(dask_compute_fibonacci, n, rkey)
        fire_and_forget(task_future)

    return {"task_id": rkey}


@fibo.get("/result", status_code=200)
async def task_result(task_id: str):
    return get_result(task_id)

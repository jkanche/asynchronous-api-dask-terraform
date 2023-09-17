import os

from distributed import Client
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .compute_router import fibo

__author__ = "jkanche"
__copyright__ = "jkanche"
__license__ = "MIT"


openapi_prefix = os.getenv("OPENAPI_PREFIX", default="")
print("using api prefix " + openapi_prefix)

app = FastAPI(
    root_path=openapi_prefix,
    openapi_url="/api/v1/openapi.json",
    docs_url="/api/v1/docs",
)
origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# setting up dask client
dport = os.getenv("DASK_PORT")
dDomain = os.getenv("DASK_DOMAIN")

app.dask = Client(f"{dDomain}:{dport}")

app.include_router(fibo, prefix="/api/v1/fibo", tags=["fibo"])

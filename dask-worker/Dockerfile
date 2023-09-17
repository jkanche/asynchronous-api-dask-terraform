FROM daskdev/dask:2022.10.0

RUN apt update && apt install curl -y 

WORKDIR /app

COPY  ./dask-worker/requirements.txt /app/requirements.txt

# RUN pip install dask-cloudprovider
RUN pip install -r /app/requirements.txt

EXPOSE 8787
EXPOSE 8786

COPY ./api/ /app/
ENV PYTHONPATH=/app
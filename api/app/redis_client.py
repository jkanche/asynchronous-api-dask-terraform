import os
import redis

__author__ = "jkanche"
__copyright__ = "jkanche"
__license__ = "MIT"


redis_pass = os.getenv("REDIS_PASSWORD")
redis_domain = os.getenv("REDIS_DOMAIN")


def rconnect(host=redis_domain, port=6379, password=redis_pass):
    try:
        client = redis.Redis(host=host, port=port, password=password, socket_timeout=5)

        ping = client.ping()

        if ping is True:
            return client
    except redis.AuthenticationError:
        raise Exception("Cannot authenticate to redis.")

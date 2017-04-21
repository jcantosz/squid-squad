FROM silarsis/docker-proxy:latest

RUN apt-get update \
    && apt-get install -y squidclient


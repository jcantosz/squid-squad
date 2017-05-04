FROM ibm_devops_services/worker_base:theRealLatest

RUN export DEBIAN_FRONTEND=noninteractive TERM=linux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        netcat \
        net-tools \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY detect-proxy.sh /tmp

RUN /tmp/detect-proxy.sh

RUN echo "registry = \"http://registry.npmjs.org/\"" >>/home/pipeline/.npmrc


FROM morrisjobke/docker-swift-onlyone
MAINTAINER Backstage 3 <backstage3@corp.globo.com>

RUN apt-get update -y

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential \
    python-dev \
    autoconf \
    automake \
    libtool \
    python-pip \
    jq \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install keystonemiddleware

COPY proxy-server.conf /etc/swift/proxy-server.conf

COPY setup-keystone.sh /usr/local/bin/setup-keystone.sh

ENTRYPOINT ["/usr/local/bin/setup-keystone.sh"]
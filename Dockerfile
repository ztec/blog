FROM floryn90/hugo:0.152.2-ext

USER root

RUN rm -f /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
        bash \
        ca-certificates \
        coreutils \
        curl \
        file \
        findutils \
        git \
        jq \
        python3-minimal \
    && rm -rf /var/lib/apt/lists/* \
    && git config --system --add safe.directory /workspace \
    && install -d -m 0777 /workspace /cache

COPY --chmod=0755 bunny-deploy /usr/local/bin/bunny-deploy

USER hugo
WORKDIR /workspace

ENV HUGO_ENV=production

ENTRYPOINT ["/usr/local/bin/bunny-deploy"]

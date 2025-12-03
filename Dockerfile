# syntax=docker/dockerfile:1
FROM floryn90/hugo:0.152.2-ext AS builder
WORKDIR /app
ENV HUGO_ENV="production"
ADD --chmod=0777 --chown=hugo:hugo ./ /app
RUN --mount=type=secret,id=PP_TOKEN,env=PP_TOKEN \
    --mount=type=secret,id=PP_HOST,env=PP_HOST \
    --mount=target=/app/resources,type=cache,uid=1234,gid=1234 \
    bin/build.sh


FROM nginx:stable
ADD nginx.conf /etc/nginx/nginx.conf
ADD default.conf /etc/nginx/templates/default.conf.template
VOLUME /var/log/nginx
COPY --from=builder /app/public /usr/share/nginx/html



FROM floryn90/hugo:0.139.2-ext AS builder
WORKDIR /app
ENV HUGO_ENV="production"
ADD --chown=hugo:hugo ./ /app
RUN bin/build.sh


FROM nginx:stable
ADD nginx.conf /etc/nginx/nginx.conf
ADD default.conf /etc/nginx/templates/default.conf.template
VOLUME /var/log/nginx
COPY --from=builder /app/public /usr/share/nginx/html



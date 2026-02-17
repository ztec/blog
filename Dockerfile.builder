FROM floryn90/hugo:0.152.2-ext
WORKDIR /app
ENV HUGO_ENV="production"
CMD ["--minify","--templateMetrics","--templateMetricsHints"]

FROM floryn90/hugo:0.162.0-ext
WORKDIR /app
ENV HUGO_ENV="production"
CMD ["--minify","--templateMetrics","--templateMetricsHints"]

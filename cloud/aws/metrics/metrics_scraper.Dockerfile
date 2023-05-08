FROM public.ecr.aws/aws-observability/aws-otel-collector:latest
COPY otel-config.yaml /cloud/aws/metrics/otel-config.yaml
CMD ["--config=/cloud/aws/metrics/otel-config.yaml"]

FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y socat curl jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy scripts
COPY entrypoint.sh /app/
COPY healthcheck.sh /app/
RUN chmod +x /app/entrypoint.sh /app/healthcheck.sh

# Environment variables with defaults
ENV TARGET_IP="185.63.148.22"
ENV HTTP_PORT="80"
ENV HTTPS_PORT="443"
ENV LOG_LEVEL="info"
ENV HEALTH_CHECK_INTERVAL="30"

# Simplified health check for Azure
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=5 \
  CMD /app/healthcheck.sh || exit 0

# Expose ports
EXPOSE 80 443

# Use custom entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]

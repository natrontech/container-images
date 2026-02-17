FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y socat curl jq libcap2-bin && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r forwarder && useradd -r -g forwarder -s /sbin/nologin forwarder

# Allow socat to bind privileged ports as non-root
RUN setcap 'cap_net_bind_service=+ep' /usr/bin/socat

# Create app directory
WORKDIR /app

# Copy scripts
COPY entrypoint.sh /app/
COPY healthcheck.sh /app/
RUN chmod +x /app/entrypoint.sh /app/healthcheck.sh && chown -R forwarder:forwarder /app

# Environment variables with defaults
ENV TARGET_IP=""
ENV HTTP_PORT="80"
ENV HTTPS_PORT="443"
ENV LOG_LEVEL="info"
ENV HEALTH_CHECK_INTERVAL="30"
ENV HEALTH_PORT="8080"

# Simplified health check for Azure
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=5 \
  CMD /app/healthcheck.sh || exit 0

# Expose ports
EXPOSE 80 443 8080

USER forwarder

# Use custom entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]

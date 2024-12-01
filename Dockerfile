ARG TAILSCALE_VERSION=stable
ARG UPTIME_KUMA_VERSION=latest

# Added validator stage to resolve correct build context
FROM alpine AS validator

# Define a Tailscale stage to fetch the latest Tailscale package for the target platform
FROM tailscale/tailscale:${TAILSCALE_VERSION} AS tailscale

# The second stage of multi-stage build
# Define the main build stage Using Uptime Kuma image
FROM louislam/uptime-kuma:${UPTIME_KUMA_VERSION}
# Install necessary packages and clean up
RUN apt-get update && apt-get install -y ca-certificates iptables \
    && rm -rf /var/lib/apt/lists/*

# Copy Tailscale bins from the Tailscale stage into the container
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale
# Create necessary directories for Tailscale
RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

# Set environment variable for Tailscale hostname
ENV TS_HOSTNAME=TailscaleUptimeKuma

# Expose necessary port for the application
EXPOSE 3001

# Define volume for persistent data
VOLUME ["/app/data"]

# Define health check commands for Uptime Kuma
HEALTHCHECK --interval=60s --timeout=30s --start-period=180s --retries=5 CMD curl --fail http://localhost:3001/healthcheck || exit 1

# Define entrypoint to dumb-init and got rid of start.sh
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Define container startup command 
CMD ["/bin/sh", "-c", "/usr/local/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock & /usr/local/bin/tailscale up --authkey=$TS_AUTHKEY --accept-routes --hostname=$TS_HOSTNAME & node server/server.js"]

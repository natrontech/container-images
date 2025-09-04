#!/bin/bash
# healthcheck.sh

# Check if socat processes are running
if ! pgrep -f "tcp-listen:443" > /dev/null; then
    echo "HTTPS forwarder not running"
    exit 1
fi

if ! pgrep -f "tcp-listen:80" > /dev/null; then
    echo "HTTP forwarder not running"  
    exit 1
fi

# Test local port connectivity
if ! timeout 2 bash -c "</dev/tcp/127.0.0.1/443" 2>/dev/null; then
    echo "HTTPS port 443 not responding"
    exit 1
fi

if ! timeout 2 bash -c "</dev/tcp/127.0.0.1/80" 2>/dev/null; then
    echo "HTTP port 80 not responding"
    exit 1
fi

echo "Health check passed"
exit 0

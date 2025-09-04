#!/bin/bash
# entrypoint.sh

set -e

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "ERROR") echo -e "${RED}[$timestamp] [ERROR]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[$timestamp] [WARN]${NC} $message" ;;
        "INFO")  echo -e "${GREEN}[$timestamp] [INFO]${NC} $message" ;;
        "DEBUG") echo -e "${BLUE}[$timestamp] [DEBUG]${NC} $message" ;;
        *) echo "[$timestamp] [$level] $message" ;;
    esac
}

# Validate environment variables
validate_config() {
    log "INFO" "Validating configuration..."
    
    if [[ -z "$TARGET_IP" ]]; then
        log "ERROR" "TARGET_IP environment variable is required"
        exit 1
    fi
    
    if ! [[ "$HTTP_PORT" =~ ^[0-9]+$ ]] || [ "$HTTP_PORT" -le 0 ] || [ "$HTTP_PORT" -gt 65535 ]; then
        log "ERROR" "Invalid HTTP_PORT: $HTTP_PORT"
        exit 1
    fi
    
    if ! [[ "$HTTPS_PORT" =~ ^[0-9]+$ ]] || [ "$HTTPS_PORT" -le 0 ] || [ "$HTTPS_PORT" -gt 65535 ]; then
        log "ERROR" "Invalid HTTPS_PORT: $HTTPS_PORT"
        exit 1
    fi
    
    log "INFO" "Configuration valid - Target: $TARGET_IP, HTTP: $HTTP_PORT, HTTPS: $HTTPS_PORT"
}

# Test connectivity to target
test_connectivity() {
    log "INFO" "Testing connectivity to $TARGET_IP..."
    
    if timeout 5 bash -c "</dev/tcp/$TARGET_IP/$HTTPS_PORT"; then
        log "INFO" "HTTPS connectivity to $TARGET_IP:$HTTPS_PORT confirmed"
    else
        log "WARN" "Cannot reach $TARGET_IP:$HTTPS_PORT - continuing anyway"
    fi
    
    if timeout 5 bash -c "</dev/tcp/$TARGET_IP/$HTTP_PORT"; then
        log "INFO" "HTTP connectivity to $TARGET_IP:$HTTP_PORT confirmed"
    else
        log "WARN" "Cannot reach $TARGET_IP:$HTTP_PORT - continuing anyway"
    fi
}

# Cleanup function
cleanup() {
    log "INFO" "Received shutdown signal, cleaning up..."
    if [ ! -z "$HTTPS_PID" ]; then
        log "INFO" "Stopping HTTPS forwarder (PID: $HTTPS_PID)"
        kill $HTTPS_PID 2>/dev/null || true
    fi
    if [ ! -z "$HTTP_PID" ]; then
        log "INFO" "Stopping HTTP forwarder (PID: $HTTP_PID)"
        kill $HTTP_PID 2>/dev/null || true
    fi
    log "INFO" "Cleanup complete"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Set socat log level based on LOG_LEVEL
case $LOG_LEVEL in
    "debug") SOCAT_OPTS="-v -d -d -d" ;;
    "info")  SOCAT_OPTS="-v -d" ;;
    "warn")  SOCAT_OPTS="-d" ;;
    "error") SOCAT_OPTS="" ;;
    *) SOCAT_OPTS="-v -d" ;;
esac

main() {
    log "INFO" "Starting Safir Traffic Forwarder v1.0"
    log "INFO" "===================================="
    
    validate_config
    test_connectivity
    
    # Create named pipes for logging
    mkfifo /tmp/https_log /tmp/http_log
    
    # Start log processors in background
    while read line; do
        log "INFO" "[HTTPS] $line"
    done < /tmp/https_log &
    HTTPS_LOG_PID=$!
    
    while read line; do
        log "INFO" "[HTTP] $line"
    done < /tmp/http_log &
    HTTP_LOG_PID=$!
    
    # Start HTTPS forwarder
    log "INFO" "Starting HTTPS forwarder: 0.0.0.0:$HTTPS_PORT -> $TARGET_IP:$HTTPS_PORT"
    socat $SOCAT_OPTS tcp-listen:$HTTPS_PORT,fork,reuseaddr tcp-connect:$TARGET_IP:$HTTPS_PORT 2>/tmp/https_log &
    HTTPS_PID=$!
    
    # Start HTTP forwarder
    log "INFO" "Starting HTTP forwarder: 0.0.0.0:$HTTP_PORT -> $TARGET_IP:$HTTP_PORT"
    socat $SOCAT_OPTS tcp-listen:$HTTP_PORT,fork,reuseaddr tcp-connect:$TARGET_IP:$HTTP_PORT 2>/tmp/http_log &
    HTTP_PID=$!
    
    log "INFO" "All forwarders started successfully"
    log "INFO" "HTTPS PID: $HTTPS_PID, HTTP PID: $HTTP_PID"
    
    # Monitor processes
    while true; do
        if ! kill -0 $HTTPS_PID 2>/dev/null; then
            log "ERROR" "HTTPS forwarder died, restarting..."
            socat $SOCAT_OPTS tcp-listen:$HTTPS_PORT,fork,reuseaddr tcp-connect:$TARGET_IP:$HTTPS_PORT 2>/tmp/https_log &
            HTTPS_PID=$!
        fi
        
        if ! kill -0 $HTTP_PID 2>/dev/null; then
            log "ERROR" "HTTP forwarder died, restarting..."
            socat $SOCAT_OPTS tcp-listen:$HTTP_PORT,fork,reuseaddr tcp-connect:$TARGET_IP:$HTTP_PORT 2>/tmp/http_log &
            HTTP_PID=$!
        fi
        
        sleep $HEALTH_CHECK_INTERVAL
    done
}

main "$@"

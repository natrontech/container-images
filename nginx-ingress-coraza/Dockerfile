# Global build args — declared before any FROM so they are available in all FROM instructions.
# To use a value inside a stage's RUN commands, redeclare with ARG <name> (inherits global default).
ARG GO_VERSION=1.26
ARG GO_DIGEST=sha256:6b9b1ff26b22fde9b31abc5c6994586f588107ee3aa54dba50626aaac5884995
ARG NIC_VERSION=5.4.1
ARG NIC_DIGEST=sha256:5fabb45022a8875d428382222859f27df2845cc22e6780fd3476fbbcf5bad504
ARG ALPINE_VERSION=3.23
ARG ALPINE_DIGEST=sha256:4d889c14e7d5a73929ab00be2ef8ff22437e7cbc545931e52554a7b00e123d8b
ARG LIBCORAZA_VERSION=v1.4.0
ARG LIBCORAZA_SHA256=356d7ddb2c816ffb1a4ab46dca2de881b21cafe57ea33e5cf20fb772ae4c5147
ARG CORAZA_NGINX_VERSION=v0.11.0
ARG CRS_VERSION=v4.26.0

# ──────────────────────────────────────────────────────────────────────────────
# Stage 1: Build libcoraza (Go → C shared/static library)
# coraza-nginx v0.11+ is pure C; it links against libcoraza at runtime via dlopen.
# This stage compiles libcoraza.so + libcoraza.a + coraza/coraza.h.
# ──────────────────────────────────────────────────────────────────────────────
FROM golang:${GO_VERSION}-bookworm@${GO_DIGEST} AS libcoraza-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    libtool \
    gcc \
    make \
    wget \
    && rm -rf /var/lib/apt/lists/*

ARG LIBCORAZA_VERSION
ARG LIBCORAZA_SHA256
RUN set -eux; \
    wget -q "https://github.com/corazawaf/libcoraza/tarball/${LIBCORAZA_VERSION}" -O /tmp/libcoraza.tar.gz; \
    echo "${LIBCORAZA_SHA256}  /tmp/libcoraza.tar.gz" | sha256sum -c -; \
    tar -xf /tmp/libcoraza.tar.gz -C /tmp/; \
    cd /tmp/*-libcoraza-*; \
    ./build.sh; \
    ./configure; \
    make; \
    mkdir -p /output/lib /output/include/coraza; \
    cp libcoraza.a /output/lib/; \
    cp libcoraza.so /output/lib/; \
    cp coraza/coraza.h /output/include/coraza/

# ──────────────────────────────────────────────────────────────────────────────
# Stage 2: Build ngx_http_coraza_module.so
# Uses the NIC image as builder base to guarantee exact NGINX ABI match.
# ──────────────────────────────────────────────────────────────────────────────
FROM nginx/nginx-ingress:${NIC_VERSION}@${NIC_DIGEST} AS nginx-module-builder

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    gnupg \
    libpcre2-dev \
    zlib1g-dev \
    libssl-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy libcoraza headers and libraries so the module C code can find <coraza/coraza.h>
COPY --from=libcoraza-builder /output/lib/libcoraza.a /usr/local/lib/
COPY --from=libcoraza-builder /output/lib/libcoraza.so /usr/local/lib/
COPY --from=libcoraza-builder /output/include/coraza /usr/local/include/coraza
RUN ldconfig

# Capture the exact NGINX version and configure arguments from the running binary
RUN nginx -v 2>&1 | grep -oP '(?<=nginx/)[0-9.]+' > /tmp/nginx_version.txt
RUN nginx -V 2>&1 | sed -n 's/^.*arguments: //p' > /tmp/nginx_configure_args.txt

ARG CORAZA_NGINX_VERSION
RUN git clone --depth 1 --branch ${CORAZA_NGINX_VERSION} \
    https://github.com/corazawaf/coraza-nginx.git /build/coraza-nginx

# Import NGINX release signing keys and download source with GPG verification
# Keys: Konstantin Pavlov (thresh), Roman Arutyunyan (arut), Sergey Kandaurov (pluknet)
RUN curl -fsSL \
      https://nginx.org/keys/thresh.key \
      https://nginx.org/keys/arut.key \
      https://nginx.org/keys/pluknet.key \
    | gpg --batch --import
RUN NGINX_VERSION=$(cat /tmp/nginx_version.txt) && \
    curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -o /tmp/nginx.tar.gz && \
    curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc" -o /tmp/nginx.tar.gz.asc && \
    gpg --batch --verify /tmp/nginx.tar.gz.asc /tmp/nginx.tar.gz && \
    tar -xz -C /build/ -f /tmp/nginx.tar.gz && \
    mv /build/nginx-${NGINX_VERSION} /build/nginx-src

# Build the NGINX dynamic module using the exact configure args from the running binary.
# CONFARGS is unquoted so the shell splits it into individual flags.
WORKDIR /build/nginx-src
RUN CONFARGS=$(cat /tmp/nginx_configure_args.txt) && \
    eval "./configure --with-compat --add-dynamic-module=/build/coraza-nginx ${CONFARGS}" && \
    make modules && \
    cp objs/ngx_http_coraza_module.so /tmp/ngx_http_coraza_module.so

# ──────────────────────────────────────────────────────────────────────────────
# Stage 3: Fetch OWASP Core Rule Set
# ──────────────────────────────────────────────────────────────────────────────
FROM alpine:${ALPINE_VERSION}@${ALPINE_DIGEST} AS crs-downloader

ARG CRS_VERSION
# Import CRS GPG key from coreruleset.org; key fingerprint: 3600 6F0E 0BA1 6783 2158 8211 38EE ACA1 AB8A 6E72
# Use the signed minimal release asset instead of the unsigned auto-generated GitHub archive.
RUN apk add --no-cache curl tar gnupg && \
    curl -fsSL https://coreruleset.org/security.asc | gpg --batch --import && \
    CRS_BARE="${CRS_VERSION#v}" && \
    curl -fsSL "https://github.com/coreruleset/coreruleset/releases/download/${CRS_VERSION}/coreruleset-${CRS_BARE}-minimal.tar.gz" \
      -o /tmp/crs.tar.gz && \
    curl -fsSL "https://github.com/coreruleset/coreruleset/releases/download/${CRS_VERSION}/coreruleset-${CRS_BARE}-minimal.tar.gz.asc" \
      -o /tmp/crs.tar.gz.asc && \
    gpg --batch --verify /tmp/crs.tar.gz.asc /tmp/crs.tar.gz && \
    mkdir -p /crs && \
    tar -xz --strip-components=1 -C /crs -f /tmp/crs.tar.gz

# ──────────────────────────────────────────────────────────────────────────────
# Stage 4: Final image — NIC + Coraza module + libcoraza + OWASP CRS
# ──────────────────────────────────────────────────────────────────────────────
FROM nginx/nginx-ingress:${NIC_VERSION}@${NIC_DIGEST}

USER root

# Coraza dynamic module
COPY --from=nginx-module-builder /tmp/ngx_http_coraza_module.so \
    /usr/lib/nginx/modules/ngx_http_coraza_module.so

# libcoraza shared library — loaded at runtime by the module via dlopen
COPY --from=libcoraza-builder /output/lib/libcoraza.so /usr/local/lib/libcoraza.so
RUN ldconfig

# OWASP CRS rules
RUN mkdir -p /etc/coraza/crs
COPY --from=crs-downloader /crs/rules/ /etc/coraza/crs/rules/
COPY --from=crs-downloader /crs/crs-setup.conf.example /etc/coraza/crs/crs-setup.conf

# Coraza configuration files
COPY coraza.conf /etc/coraza/coraza.conf
COPY coraza-crs-include.conf /etc/coraza/coraza-crs-include.conf

# NIC runs as uid 101 (nginx)
RUN chown -R 101:0 /etc/coraza /usr/lib/nginx/modules/ngx_http_coraza_module.so && \
    chmod -R g=u /etc/coraza && \
    chmod 755 /usr/lib/nginx/modules/ngx_http_coraza_module.so

USER 101

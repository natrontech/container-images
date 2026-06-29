# syntax=docker/dockerfile:1
# Global build args — declared before any FROM so they are available in all FROM instructions.
# To use a value inside a stage's RUN commands, redeclare with ARG <name> (inherits global default).
ARG GO_VERSION=1.26
ARG GO_DIGEST=sha256:b305420a68d0f229d91eb3b3ed9e519fcf2cf5461da4bef997bf927e8c0bfd2b
ARG NIC_VERSION=5.5.1
ARG NIC_DIGEST=sha256:85b835a6a8d1958f51ce94f0f1e7af833e63731add98eca1d15b11b75ebd50c6
ARG ALPINE_VERSION=3.24
ARG ALPINE_DIGEST=sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b
ARG LIBCORAZA_VERSION=v1.6.0
ARG LIBCORAZA_SHA256=27158bfe16314e46fc4c276c2cb3e04519ed548337fc961155636768fb44be4a
ARG CORAZA_NGINX_VERSION=v0.11.4
ARG CRS_VERSION=v4.27.0

# ──────────────────────────────────────────────────────────────────────────────
# Stage 1: Build libcoraza (Go → C shared/static library)
# coraza-nginx v0.11+ is pure C; it links against libcoraza at runtime via dlopen.
# This stage compiles libcoraza.so + libcoraza.a + coraza/coraza.h.
# ──────────────────────────────────────────────────────────────────────────────
FROM golang:${GO_VERSION}-bookworm@${GO_DIGEST} AS libcoraza-builder

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

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
RUN wget "https://github.com/corazawaf/libcoraza/tarball/${LIBCORAZA_VERSION}" -O /tmp/libcoraza.tar.gz \
    && echo "${LIBCORAZA_SHA256}  /tmp/libcoraza.tar.gz" | sha256sum -c - \
    && tar -xf /tmp/libcoraza.tar.gz -C /tmp/ \
    && cd /tmp/*-libcoraza-* \
    && ./build.sh \
    && ./configure \
    && make \
    && mkdir -p /output/lib /output/include/coraza \
    && cp libcoraza.a /output/lib/ \
    && cp libcoraza.so /output/lib/ \
    && cp coraza/coraza.h /output/include/coraza/ \
    && test -s /output/lib/libcoraza.a \
    && test -s /output/lib/libcoraza.so \
    && test -s /output/include/coraza/coraza.h

# ──────────────────────────────────────────────────────────────────────────────
# Stage 2: Build ngx_http_coraza_module.so
# Uses the NIC image as builder base to guarantee exact NGINX ABI match.
# ──────────────────────────────────────────────────────────────────────────────
FROM nginx/nginx-ingress:${NIC_VERSION}@${NIC_DIGEST} AS nginx-module-builder

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

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

# Capture the exact NGINX version and configure arguments from the running binary.
# test -s ensures the captured values are non-empty — an empty file means the
# parse failed silently and would produce a broken build further down.
RUN nginx -v 2>&1 | grep -oP '(?<=nginx/)[0-9.]+' > /tmp/nginx_version.txt \
    && test -s /tmp/nginx_version.txt
RUN nginx -V 2>&1 | sed -n 's/^.*arguments: //p' > /tmp/nginx_configure_args.txt \
    && test -s /tmp/nginx_configure_args.txt

ARG CORAZA_NGINX_VERSION
RUN git clone --depth 1 --branch ${CORAZA_NGINX_VERSION} \
    https://github.com/corazawaf/coraza-nginx.git /build/coraza-nginx

# Download NGINX release signing keys to files first, then import.
# Avoids masking a curl failure in a pipe where only the last exit code is seen.
# Keys: Konstantin Pavlov (thresh), Roman Arutyunyan (arut), Sergey Kandaurov (pluknet)
RUN curl -fsSL https://nginx.org/keys/thresh.key -o /tmp/thresh.key \
    && curl -fsSL https://nginx.org/keys/arut.key -o /tmp/arut.key \
    && curl -fsSL https://nginx.org/keys/pluknet.key -o /tmp/pluknet.key \
    && gpg --batch --import /tmp/thresh.key /tmp/arut.key /tmp/pluknet.key \
    && rm /tmp/thresh.key /tmp/arut.key /tmp/pluknet.key

RUN NGINX_VERSION=$(cat /tmp/nginx_version.txt) \
    && curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -o /tmp/nginx.tar.gz \
    && curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc" -o /tmp/nginx.tar.gz.asc \
    && gpg --batch --verify /tmp/nginx.tar.gz.asc /tmp/nginx.tar.gz \
    && tar -xz -C /build/ -f /tmp/nginx.tar.gz \
    && mv /build/nginx-${NGINX_VERSION} /build/nginx-src

# Build the NGINX dynamic module using the exact configure args from the running binary.
# CONFARGS is unquoted so the shell splits it into individual flags.
WORKDIR /build/nginx-src
RUN CONFARGS=$(cat /tmp/nginx_configure_args.txt) \
    && eval "./configure --with-compat --add-dynamic-module=/build/coraza-nginx ${CONFARGS}" \
    && make modules \
    && cp objs/ngx_http_coraza_module.so /tmp/ngx_http_coraza_module.so \
    && test -s /tmp/ngx_http_coraza_module.so

# ──────────────────────────────────────────────────────────────────────────────
# Stage 3: Fetch OWASP Core Rule Set
# ──────────────────────────────────────────────────────────────────────────────
FROM alpine:${ALPINE_VERSION}@${ALPINE_DIGEST} AS crs-downloader

SHELL ["/bin/sh", "-eux", "-c"]

ARG CRS_VERSION
# Import CRS GPG key from coreruleset.org; key fingerprint: 3600 6F0E 0BA1 6783 2158 8211 38EE ACA1 AB8A 6E72
# Download key to file first to avoid masking curl failures in a pipe.
RUN apk add --no-cache curl tar gnupg \
    && curl -fsSL https://coreruleset.org/security.asc -o /tmp/crs-signing.asc \
    && test -s /tmp/crs-signing.asc \
    && gpg --batch --import /tmp/crs-signing.asc \
    && CRS_BARE="${CRS_VERSION#v}" \
    && curl -fsSL "https://github.com/coreruleset/coreruleset/releases/download/${CRS_VERSION}/coreruleset-${CRS_BARE}-minimal.tar.gz" \
      -o /tmp/crs.tar.gz \
    && curl -fsSL "https://github.com/coreruleset/coreruleset/releases/download/${CRS_VERSION}/coreruleset-${CRS_BARE}-minimal.tar.gz.asc" \
      -o /tmp/crs.tar.gz.asc \
    && test -s /tmp/crs.tar.gz \
    && test -s /tmp/crs.tar.gz.asc \
    && gpg --batch --verify /tmp/crs.tar.gz.asc /tmp/crs.tar.gz \
    && mkdir -p /crs \
    && tar -xz --strip-components=1 -C /crs -f /tmp/crs.tar.gz \
    && test -d /crs/rules \
    && ls /crs/rules/*.conf > /dev/null

# ──────────────────────────────────────────────────────────────────────────────
# Stage 4: Final image — NIC + Coraza module + libcoraza + OWASP CRS
# ──────────────────────────────────────────────────────────────────────────────
FROM nginx/nginx-ingress:${NIC_VERSION}@${NIC_DIGEST}

USER root

# Coraza dynamic module — ownership and mode set at copy time to avoid a separate chown layer
COPY --chown=101:0 --chmod=755 --from=nginx-module-builder /tmp/ngx_http_coraza_module.so \
    /usr/lib/nginx/modules/ngx_http_coraza_module.so

# libcoraza shared library — loaded at runtime by the module via dlopen.
# -X updates the cache only; skipping symlink recreation avoids duplicating every
# system .so symlink (libcrypto, libssl, …) in this layer.
COPY --from=libcoraza-builder /output/lib/libcoraza.so /usr/local/lib/libcoraza.so
RUN ldconfig -X

# OWASP CRS rules — ownership set at copy time
RUN mkdir -p /etc/coraza/crs
COPY --chown=101:0 --from=crs-downloader /crs/rules/ /etc/coraza/crs/rules/
COPY --chown=101:0 --from=crs-downloader /crs/crs-setup.conf.example /etc/coraza/crs/crs-setup.conf

# Coraza configuration files
COPY --chown=101:0 coraza.conf /etc/coraza/coraza.conf
COPY --chown=101:0 coraza-crs-include.conf /etc/coraza/coraza-crs-include.conf

USER 101

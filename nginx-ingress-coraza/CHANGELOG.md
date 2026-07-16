# Changelog

All published versions of the `nginx-ingress-coraza` image and the component versions baked into each. The image version follows the pinned NGINX Ingress Controller (NIC) version; a `-N` suffix marks a component-only rebuild on the same NIC version (see [README — update procedure](README.md#keeping-components-up-to-date)).

When publishing a new version, add a row to the matrix **and** a release-notes section below.

## Component version matrix

| Image version | Published  | NIC     | coraza-nginx | libcoraza | OWASP CRS | Go (builder) | Alpine (CRS stage) |
| ------------- | ---------- | ------- | ------------ | --------- | --------- | ------------ | ------------------ |
| `5.5.3`       | 2026-07-16 | `5.5.3` | `v0.11.4`    | `v1.6.0`  | `v4.28.0` | `1.26`       | `3.24`             |
| `5.5.1-2`     | 2026-06-29 | `5.5.1` | `v0.11.4`    | `v1.6.0`  | `v4.27.0` | `1.26`       | `3.24`             |
| `5.5.1`       | 2026-06-23 | `5.5.1` | `v0.11.2`    | `v1.6.0`  | `v4.27.0` | `1.26`       | `3.24`             |
| `5.5.0`       | 2026-05-29 | `5.5.0` | `v0.11.0`    | `v1.6.0`  | `v4.26.0` | `1.26`       | `3.23`             |

Older releases (`5.4.3` and earlier) predate this changelog — see the git history of [Dockerfile](Dockerfile) and [VERSION](VERSION).

## Release notes

For details on upstream changes, always check the linked release notes.

### 5.5.3 (2026-07-16)

- NIC `5.5.1` → `5.5.3` (NGINX OSS 1.31.3) — release notes: [v5.5.2](https://github.com/nginx/kubernetes-ingress/releases/tag/v5.5.2), [v5.5.3](https://github.com/nginx/kubernetes-ingress/releases/tag/v5.5.3)
- OWASP CRS `v4.27.0` → `v4.28.0` (includes security fixes) — release notes: [v4.28.0](https://github.com/coreruleset/coreruleset/releases/tag/v4.28.0)
- refreshed drifted `golang:1.26-bookworm` builder digest (Go 1.26.5)
- default `coraza.conf` (and the example ConfigMap) now follows the [Coraza recommended config](https://github.com/corazawaf/coraza/blob/main/coraza.conf-recommended): JSON/XML request-body processors, body-parse-failure rules, body-limit tuning

### 5.5.1-2 (2026-06-29)

- coraza-nginx `v0.11.2` → `v0.11.4` — release notes: [v0.11.3](https://github.com/corazawaf/coraza-nginx/releases/tag/v0.11.3), [v0.11.4](https://github.com/corazawaf/coraza-nginx/releases/tag/v0.11.4)
- refreshed drifted `golang:1.26-bookworm` builder digest

### 5.5.1 (2026-06-23)

- NIC `5.5.0` → `5.5.1` (NGINX OSS 1.31.2) — release notes: [v5.5.1](https://github.com/nginx/kubernetes-ingress/releases/tag/v5.5.1)
- coraza-nginx `v0.11.0` → `v0.11.2` — release notes: [v0.11.1](https://github.com/corazawaf/coraza-nginx/releases/tag/v0.11.1), [v0.11.2](https://github.com/corazawaf/coraza-nginx/releases/tag/v0.11.2)
- OWASP CRS `v4.26.0` → `v4.27.0` — release notes: [v4.27.0](https://github.com/coreruleset/coreruleset/releases/tag/v4.27.0)
- Alpine `3.23` → `3.24` (CRS downloader stage) — [release announcements](https://alpinelinux.org/releases/)

### 5.5.0 (2026-05-29)

- NIC `5.4.3` → `5.5.0` — release notes: [v5.5.0](https://github.com/nginx/kubernetes-ingress/releases/tag/v5.5.0)

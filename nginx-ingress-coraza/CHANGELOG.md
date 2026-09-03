# Changelog

All notable changes to the `nginx-ingress-coraza` image are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Image versions follow the pinned NGINX Ingress Controller (NIC) version instead of Semantic Versioning; a `-N` suffix marks a component-only rebuild on the same NIC version (see [README — update procedure](README.md#keeping-components-up-to-date)).

When publishing a new version, add a row to the component version matrix **and** a release section below.

## Withdrawn versions

> [!WARNING]
> The version tags `5.4.1`, `5.4.2`, `5.4.3`, `5.5.0`, `5.5.1`, `5.5.1-2`, `5.5.1-pr54-websocket` and `5.5.3` (and their `sha-*` twins) were **withdrawn on 2026-09-02** and can no longer be pulled. A faulty registry cleanup job had deleted the untagged child manifests (per-arch images, provenance) of these multi-arch images; the loss was discovered after GitHub's 30-day restore window had expired, so the broken tags were removed rather than left dangling. They were **not** rebuilt: a rebuild would produce different digests without the original SLSA provenance and would no longer satisfy the published verification policy — for what are, by now, outdated NIC versions.
>
> **Upgrade to `5.5.4` or later.** If you have a hard requirement on an older NIC version, open an issue — it can be re-released through CI as a new revision tag (e.g. `5.5.1-3`) with a complete signature and provenance chain.

## Component version matrix

| Image version | Published  | NIC     | coraza-nginx | libcoraza | OWASP CRS | Go (builder) | Alpine (CRS stage) |
| ------------- | ---------- | ------- | ------------ | --------- | --------- | ------------ | ------------------ |
| `5.6.0`       | 2026-09-03 | `5.6.0` | `v0.21.0`    | `v1.7.0`  | `v4.29.0` | `1.27`       | `3.24`             |
| `5.5.4-2`     | 2026-08-31 | `5.5.4` | `v0.21.0`    | `v1.7.0`  | `v4.29.0` | `1.26`       | `3.24`             |
| `5.5.4`       | 2026-07-28 | `5.5.4` | `v0.20.0`    | `v1.6.0`  | `v4.28.0` | `1.26`       | `3.24`             |
| `5.5.3` †     | 2026-07-16 | `5.5.3` | `v0.11.4`    | `v1.6.0`  | `v4.28.0` | `1.26`       | `3.24`             |
| `5.5.1-2` †   | 2026-06-29 | `5.5.1` | `v0.11.4`    | `v1.6.0`  | `v4.27.0` | `1.26`       | `3.24`             |
| `5.5.1` †     | 2026-06-23 | `5.5.1` | `v0.11.2`    | `v1.6.0`  | `v4.27.0` | `1.26`       | `3.24`             |
| `5.5.0` †     | 2026-05-29 | `5.5.0` | `v0.11.0`    | `v1.6.0`  | `v4.26.0` | `1.26`       | `3.23`             |

† Withdrawn 2026-09-02 — no longer pullable, see [Withdrawn versions](#withdrawn-versions).

Older releases (`5.4.3` and earlier) predate this changelog — see the git history of [Dockerfile](Dockerfile) and [VERSION](VERSION).

For details on upstream changes, always check the linked release notes.

## [Unreleased]

## [5.6.0] - 2026-09-03

### Changed

- NIC `5.5.4` → `5.6.0` (NGINX OSS 1.31.4) — release notes: [v5.6.0](https://github.com/nginx/kubernetes-ingress/releases/tag/v5.6.0). Upstream OSS images are now [built from scratch](https://github.com/nginx/kubernetes-ingress/pull/10159), shrinking this image by ~350 MB per platform (473 MB → 119 MB on amd64)
- Go builder `1.26` → `1.27` — [release notes](https://go.dev/doc/go1.27)
- coraza-nginx `v0.21.0`, libcoraza `v1.7.0` and OWASP CRS `v4.29.0` unchanged (already latest)

## [5.5.4-2] - 2026-08-31

### Changed

- coraza-nginx `v0.20.0` → `v0.21.0` — release notes: [v0.20.1](https://github.com/corazawaf/coraza-nginx/releases/tag/v0.20.1) (audit record now written when an internal redirect hides the LOG-phase ctx), [v0.21.0](https://github.com/corazawaf/coraza-nginx/releases/tag/v0.21.0) (requires libcoraza >= 1.7, gated at build and runtime)
- libcoraza `v1.6.0` → `v1.7.0` — release notes: [v1.7.0](https://github.com/corazawaf/libcoraza/releases/tag/v1.7.0) (exports `coraza_is_request_body_accessible` and the library version to C consumers)
- OWASP CRS `v4.28.0` → `v4.29.0` — release notes: [v4.29.0](https://github.com/coreruleset/coreruleset/releases/tag/v4.29.0)
- refreshed drifted base-image digests: `nginx/nginx-ingress:5.5.4` (upstream re-push) and `golang:1.26-bookworm` (Go 1.26.7)

## [5.5.4] - 2026-07-28

### Changed

- NIC `5.5.3` → `5.5.4` — release notes: [v5.5.4](https://github.com/nginx/kubernetes-ingress/releases/tag/v5.5.4)
- coraza-nginx `v0.11.4` → `v0.20.0` — release notes: [v0.20.0](https://github.com/corazawaf/coraza-nginx/releases/tag/v0.20.0)

## [5.5.3] - 2026-07-16

> **Withdrawn 2026-09-02** — no longer pullable, see [Withdrawn versions](#withdrawn-versions).

### Changed

- NIC `5.5.1` → `5.5.3` (NGINX OSS 1.31.3) — release notes: [v5.5.2](https://github.com/nginx/kubernetes-ingress/releases/tag/v5.5.2), [v5.5.3](https://github.com/nginx/kubernetes-ingress/releases/tag/v5.5.3)
- OWASP CRS `v4.27.0` → `v4.28.0` — release notes: [v4.28.0](https://github.com/coreruleset/coreruleset/releases/tag/v4.28.0)
- default `coraza.conf` (and the example ConfigMap) now follows the [Coraza recommended config](https://github.com/corazawaf/coraza/blob/main/coraza.conf-recommended): JSON/XML request-body processors, body-parse-failure rules, body-limit tuning
- refreshed drifted `golang:1.26-bookworm` builder digest (Go 1.26.5)

## [5.5.1-2] - 2026-06-29

> **Withdrawn 2026-09-02** — no longer pullable, see [Withdrawn versions](#withdrawn-versions).

### Changed

- coraza-nginx `v0.11.2` → `v0.11.4` — release notes: [v0.11.3](https://github.com/corazawaf/coraza-nginx/releases/tag/v0.11.3), [v0.11.4](https://github.com/corazawaf/coraza-nginx/releases/tag/v0.11.4)
- refreshed drifted `golang:1.26-bookworm` builder digest

## [5.5.1] - 2026-06-23

> **Withdrawn 2026-09-02** — no longer pullable, see [Withdrawn versions](#withdrawn-versions).

### Changed

- NIC `5.5.0` → `5.5.1` (NGINX OSS 1.31.2) — release notes: [v5.5.1](https://github.com/nginx/kubernetes-ingress/releases/tag/v5.5.1)
- coraza-nginx `v0.11.0` → `v0.11.2` — release notes: [v0.11.1](https://github.com/corazawaf/coraza-nginx/releases/tag/v0.11.1), [v0.11.2](https://github.com/corazawaf/coraza-nginx/releases/tag/v0.11.2)
- OWASP CRS `v4.26.0` → `v4.27.0` — release notes: [v4.27.0](https://github.com/coreruleset/coreruleset/releases/tag/v4.27.0)
- Alpine `3.23` → `3.24` (CRS downloader stage) — [release announcements](https://alpinelinux.org/releases/)

## [5.5.0] - 2026-05-29

> **Withdrawn 2026-09-02** — no longer pullable, see [Withdrawn versions](#withdrawn-versions).

### Changed

- NIC `5.4.3` → `5.5.0` — release notes: [v5.5.0](https://github.com/nginx/kubernetes-ingress/releases/tag/v5.5.0)

<!-- Older versions have no nginx-ingress-coraza-<version> git tag (tagging was introduced with 5.5.3), so no compare links exist for them. -->
[unreleased]: https://github.com/natrontech/container-images/compare/nginx-ingress-coraza-5.6.0...HEAD
[5.6.0]: https://github.com/natrontech/container-images/compare/nginx-ingress-coraza-5.5.4-2...nginx-ingress-coraza-5.6.0
[5.5.4-2]: https://github.com/natrontech/container-images/compare/nginx-ingress-coraza-5.5.4...nginx-ingress-coraza-5.5.4-2
[5.5.4]: https://github.com/natrontech/container-images/compare/nginx-ingress-coraza-5.5.3...nginx-ingress-coraza-5.5.4
[5.5.3]: https://github.com/natrontech/container-images/releases/tag/nginx-ingress-coraza-5.5.3

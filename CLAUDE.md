# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A collection of utility container images built and published nightly to GitHub Container Registry (ghcr.io/natrontech/container-images). Each top-level directory containing a `Dockerfile` is auto-discovered and built as a separate container image.

## Build & Test Commands

```bash
# Local build and test a container
./scripts/test-build.sh <container-name>          # build only
./scripts/test-build.sh <container-name> --push    # build and push

# Validate repository structure and container discovery
./scripts/validate-workflow.sh

# Install pre-commit hooks
pre-commit install

# Run pre-commit checks manually
pre-commit run --all-files
```

## Architecture

**Auto-discovery build system:** The CI workflow (`container-build.yml`) scans for directories containing a `Dockerfile` at the repo root. Directory name becomes the image name. No manual workflow configuration is needed when adding new containers.

**CI pipeline jobs:** `discover-containers` → `build-and-push` (matrix) → `collect-digests` → `provenance` (versioned only) → `verify` → `summary`

**Security chain:** Every image is signed with Cosign (keyless/OIDC) and gets a CycloneDX SBOM attestation. Versioned images (with a `VERSION` file) additionally get SLSA Level 3 provenance. Verification policies are in `policy.cue` (SLSA) and `policy-sbom.cue` (SBOM).

**Multi-arch:** Images build for `linux/amd64,linux/arm64` by default. Add a `PLATFORMS` file (comma-separated) to override for a specific container (e.g. `linux/amd64` only).

**Tagging:** `:nightly` (scheduled), `:sha-<commit>` (push to main, immutable), `:<version>` (push to main if `VERSION` file exists, immutable), `:latest` (push to main + nightly).

## Adding a New Container Image

1. Create a directory at the repo root: `mkdir <name>`
2. Add a `Dockerfile` inside it
3. Optionally add a `VERSION` file (e.g. `1.0.0`) to publish an immutable version tag and SLSA provenance
4. Optionally add a `PLATFORMS` file to restrict platforms (default: `linux/amd64,linux/arm64`)
5. Add a docker entry for the new directory to `.github/dependabot.yml`
6. Push to main — auto-discovered on next build
7. Run `./scripts/validate-workflow.sh` to verify discovery works locally

## Conventions

- **Commits:** Conventional Commits format with emoji prefixes (`:seedling:` for deps, `:robot:` for Docker)
- **Commits must be GPG-signed**
- **Pre-commit hooks:** Gitleaks secret scanning, Checkov Dockerfile linting (skips CKV_DOCKER_2, CKV_DOCKER_7), trailing whitespace/EOF fixers
- **EditorConfig:** LF line endings, UTF-8, tabs for Go/Makefiles/markdown, 2-space indent for YAML/JSON
- **Code ownership:** @natrontech/developers — all PRs require review

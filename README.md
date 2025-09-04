# Container Images

A collection of utility container images built and published nightly to GitHub Container Registry. These are lightweight, secure helper containers designed for various infrastructure and development tasks.

## 🚀 Available Images

All images are available at `ghcr.io/natrontech/container-images/<image-name>` with the following tags:

- `:latest` - Latest stable release
- `:nightly` - Nightly builds from main branch
- `:sha-<commit>` - Specific commit builds

### Current Images

- **tcp-forwarder** - A robust TCP port forwarder with health checks and logging

## 🔒 Security

All container images are:
- ✅ Signed with [Cosign](https://github.com/sigstore/cosign)
- ✅ Built with [SLSA Level 3](https://slsa.dev/) provenance
- ✅ Scanned for vulnerabilities
- ✅ Generated with reproducible builds

## 🏗️ Build Process

### Automated Builds
- **Nightly**: Automatically builds all containers every night at 02:00 UTC
- **On Push**: Builds containers when changes are pushed to main branch
- **Manual**: Can be triggered manually via GitHub Actions

### Container Discovery
The build system automatically discovers containers by scanning for directories containing a `Dockerfile`. Each directory name becomes the container image name.

## 🛠️ Adding New Container Images

1. Create a new directory with your container name (e.g., `my-tool/`)
2. Add a `Dockerfile` in that directory
3. Optionally add any supporting scripts or files
4. Push to main branch - the container will be automatically built and published

Example structure:
```
my-tool/
├── Dockerfile
├── entrypoint.sh
└── healthcheck.sh
```

## 📋 Verification

To verify a container image signature:

```bash
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github.com/natrontech/container-images/.github/workflows/.*@refs/.*$' \
  ghcr.io/natrontech/container-images/<image-name>:<tag>
```

To verify SLSA provenance:

```bash
cosign verify-attestation \
  --type slsaprovenance \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/v[0-9]+.[0-9]+.[0-9]+$' \
  ghcr.io/natrontech/container-images/<image-name>:<tag>
```

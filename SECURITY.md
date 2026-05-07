# Security Policy

## Reporting Security Issues

The contributor and community take security bugs in container-images seriously. We appreciate your efforts to responsibly disclose your findings, and will make every effort to acknowledge your contributions.

To report a security issue, please use the GitHub Security Advisory ["Report a Vulnerability"](https://github.com/natrontech/container-images/security/advisories/new) tab.

The contributor will send a response indicating the next steps in handling your report. After the initial reply to your report, the security team will keep you informed of the progress towards a fix and full announcement, and may ask for additional information or guidance.

## Release verification

All container images are signed with [Cosign](https://github.com/sigstore/cosign) using [keyless signing](https://docs.sigstore.dev/cosign/signing/overview/) (OIDC, no long-lived keys). SBOMs are attested in CycloneDX JSON format.

### Prerequisites

Install [cosign](https://github.com/sigstore/cosign) and [crane](https://github.com/google/go-containerregistry/blob/main/cmd/crane/README.md).

### Setup

```bash
# set the image name and tag you want to verify
export IMAGE=ghcr.io/natrontech/container-images/<image-name>:<tag>

# resolve to digest to prevent TOCTOU attacks (tag is mutable, digest is not)
export IMAGE="${IMAGE}@$(crane digest ${IMAGE})"
```

### Verify signature of container image

```bash
cosign verify \
  --new-bundle-format \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github.com/natrontech/container-images/.github/workflows/container-build.yml@refs/heads/main$' \
  $IMAGE | jq
```

> [!IMPORTANT]
> Verifying the provenance of a container image ensures the integrity and authenticity of the image because the provenance (with the image digest) is signed with Cosign. The container images themselves are also signed with Cosign, but the signature is not necessary for verification if the provenance is verified. Provenance verification is a stronger security guarantee than image signing because it verifies the entire build process, not just the final image. Image signing is therefore not essential if provenance verification is.

### Verify SBOM attestation

The Software Bill of Materials (SBOM) is generated in CycloneDX JSON format for each container image and release and can be used to verify the container's dependencies.

```bash
# download policy-sbom.cue
curl -L -O https://raw.githubusercontent.com/natrontech/container-images/main/policy-sbom.cue

cosign verify-attestation \
  --new-bundle-format \
  --type cyclonedx \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github.com/natrontech/container-images/.github/workflows/container-build.yml@refs/heads/main$' \
  --policy policy-sbom.cue \
  $IMAGE | jq -r '.payload' | base64 -d | jq
```

To download the SBOM:

```bash
cosign verify-attestation \
  --new-bundle-format \
  --type cyclonedx \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github.com/natrontech/container-images/.github/workflows/container-build.yml@refs/heads/main$' \
  --policy policy-sbom.cue \
  $IMAGE | jq -r '.payload' | base64 -d | jq -r '.predicate' > sbom.json
```

### Verify SLSA provenance of container images

SLSA Level 3 provenance is generated for versioned images (those published with a fixed version tag, e.g., `:5.4.1`). It is not generated for `:latest` or `:nightly`.

Provenance uses the old Sigstore bundle format (the SLSA generator does not yet support `--new-bundle-format`):

**Verify with `cosign`**

```bash
# download policy.cue
curl -L -O https://raw.githubusercontent.com/natrontech/container-images/main/policy.cue

cosign verify-attestation \
  --type slsaprovenance \
  --new-bundle-format=false \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/v[0-9]+.[0-9]+.[0-9]+$' \
  --policy policy.cue \
  $IMAGE | jq
```

**Verify with `slsa-verifier`**

As an alternative to `cosign`, you can also use the [SLSA Verifier](https://github.com/slsa-framework/slsa-verifier) to verify the provenance of the container images.

```bash
VERSION=<version-tag-without-colon> # e.g. 5.4.1
IMAGE=ghcr.io/natrontech/container-images/<image-name>:$VERSION

# get the image digest and append it to the image name
IMAGE="${IMAGE}@"$(crane digest "${IMAGE}")

# verify the image
slsa-verifier verify-image \
  --source-uri github.com/natrontech/container-images \
  --source-versioned-tag $VERSION \
  $IMAGE
```

The output should be: PASSED: Verified SLSA provenance.

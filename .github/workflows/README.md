# GitHub Actions Workflows

## container-build.yml

Builds and publishes all container images.

**Triggers:** push to `main`, nightly at 02:00 UTC, manual dispatch (optional container filter)

**Pipeline:**

```
discover-containers
  └── build-and-push (matrix: all containers)
        ├── collect-digests (versioned containers, non-nightly)
        │     └── provenance (SLSA L3, versioned containers, non-nightly)
        ├── verify (all containers, non-nightly)
        └── summary
```

**Tags published:**

| Tag             | When                                               | Mutable |
| --------------- | -------------------------------------------------- | ------- |
| `:nightly`      | nightly schedule only                              | yes     |
| `:latest`       | every push to main + nightly                       | yes     |
| `:sha-<commit>` | every push to main                                 | no      |
| `:<version>`    | push to main, for containers with a `VERSION` file | no      |

**Security:**
- Every image is signed with Cosign (keyless/OIDC, `--new-bundle-format`)
- Every image gets a CycloneDX SBOM attestation
- Versioned images (with a `VERSION` file) additionally get SLSA Level 3 provenance
- Signature, SBOM, and provenance are verified in the `verify` job before the pipeline completes

**Multi-arch:** `linux/amd64` and `linux/arm64`

---

## cleanup.yml

Removes old untagged image versions and orphaned attestation blobs from GHCR.

**Triggers:** every Sunday at 03:00 UTC, manual dispatch (configurable `max_age_days`, default 30)

**What gets deleted (after `max_age_days`):**
- Untagged versions — old `:latest`/`:nightly` images whose mutable tags moved to a newer build
- Orphaned cosign attestation/signature blobs (`sha256-<hex>.att`, `sha256-<hex>.sig`) whose parent image digest no longer exists

**What is never deleted:**
- Any version carrying a `sha-*` or semver tag (e.g. `sha-abc1234`, `5.4.1`)
- Attestations and signatures for those protected versions

---

## scorecard.yml

Runs [OpenSSF Scorecard](https://github.com/ossf/scorecard) supply-chain security analysis and publishes results to the OSSF dashboard.

**Triggers:** push to `main`, every Monday at 14:00 UTC, branch protection rule changes

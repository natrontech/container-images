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

**Multi-arch:** `linux/amd64,linux/arm64` by default. A `PLATFORMS` file in the container directory overrides this (e.g. `linux/amd64` only).

---

## cleanup.yml

Garbage-collects GHCR versions that are **unreachable from any tag** (plus orphaned cosign attestation blobs).

**Triggers:** every Sunday at 03:00 UTC, manual dispatch (configurable `max_age_days`, default 30; `dry_run`, default true)

**How it decides what is garbage:** "untagged" does **not** mean unused — a tagged
multi-arch/attested image is an OCI index whose per-arch and provenance/SBOM
manifests are separate *untagged* package versions. The job therefore walks
every tagged manifest via the registry API and collects all transitively
referenced digests; only versions **outside** that set and older than
`max_age_days` are deleted:

- Unreferenced untagged versions — old `:latest`/`:nightly` builds whose mutable tags moved on
- Orphaned cosign blobs (`sha256-<hex>`, `.att`, `.sig`, `.sbom`) whose parent digest is gone

**What is never deleted:**
- Any version carrying a non-attestation tag (semver, `sha-*`, `latest`, `nightly`, ...)
- Any manifest referenced (directly or transitively) by a tagged index — per-arch images, provenance/SBOM manifests
- Cosign referrers (new bundle format) whose `subject` digest is alive, and attestation blobs whose parent digest is alive
- Anything younger than `max_age_days`

**Fail-safes:** if the reference graph for a package cannot be fully computed,
no deletions happen for that package. After cleanup the job verifies that every
tag still fully resolves (index + all children) and **fails the run** otherwise.
Use `dry_run` on manual dispatch to preview deletions and get an integrity
report (`./scripts/verify-image-tags.sh` does the same check locally).

---

## scorecard.yml

Runs [OpenSSF Scorecard](https://github.com/ossf/scorecard) supply-chain security analysis and publishes results to the OSSF dashboard.

**Triggers:** push to `main`, every Monday at 14:00 UTC, branch protection rule changes

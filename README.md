# Container Images

[![license](https://img.shields.io/github/license/natrontech/container-images)](https://github.com/natrontech/container-images/blob/main/LICENSE)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/natrontech/container-images/badge)](https://securityscorecards.dev/viewer/?uri=github.com/natrontech/container-images)
[![SLSA 3](https://slsa.dev/images/gh-badge-level3.svg)](https://slsa.dev)

---

A collection of utility container images built and published to the GitHub Container Registry.

## Available Images

All packages: [ghcr.io/natrontech/container-images](https://github.com/orgs/natrontech/packages?repo_name=container-images)

| Image                                         | Latest tag                                                        | Description                                              |
| --------------------------------------------- | ----------------------------------------------------------------- | -------------------------------------------------------- |
| [tcp-forwarder](tcp-forwarder/)               | `ghcr.io/natrontech/container-images/tcp-forwarder:latest`        | Robust TCP port forwarder with health checks and logging |
| [nginx-ingress-coraza](nginx-ingress-coraza/) | `ghcr.io/natrontech/container-images/nginx-ingress-coraza:latest` | NGINX Ingress Controller with Coraza WAF and OWASP CRS   |

### Tags

| Tag             | Published on                                          | Mutable |
| --------------- | ----------------------------------------------------- | ------- |
| `:latest`       | every push to main + nightly                          | yes     |
| `:nightly`      | nightly at 02:00 UTC                                  | yes     |
| `:sha-<commit>` | every push to main                                    | no      |
| `:<version>`    | every push to main (containers with a `VERSION` file) | no      |

## Security

All images are signed with [Cosign](https://github.com/sigstore/cosign) (keyless/OIDC) and come with a CycloneDX SBOM attestation. Versioned images additionally receive [SLSA Level 3](https://slsa.dev/) provenance.

| Artifact                   | Scope                               |
| -------------------------- | ----------------------------------- |
| Cosign signature           | all tags                            |
| CycloneDX SBOM attestation | all tags                            |
| SLSA Level 3 provenance    | versioned tags only (e.g. `:5.4.1`) |

See [SECURITY.md](SECURITY.md) for verification commands.

## Adding a New Image

1. Create a directory at the repo root with the image name
2. Add a `Dockerfile` inside it
3. Optionally add a `VERSION` file (e.g. `1.0.0`) to publish an immutable version tag and SLSA provenance
4. Push to main — auto-discovered and built on the next CI run

```
my-tool/
├── Dockerfile
├── VERSION
└── README.md
```

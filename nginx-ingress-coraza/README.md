# nginx-ingress-coraza

[NGINX Ingress Controller](https://docs.nginx.com/nginx-ingress-controller/) extended with the [Coraza WAF module](https://github.com/corazawaf/coraza-nginx) and [OWASP Core Rule Set](https://coreruleset.org/) — baked in, no NIC source changes required.

**Image**: `ghcr.io/natrontech/container-images/nginx-ingress-coraza`

## Architecture

The image adds three components on top of the official NIC image:

1. **`ngx_http_coraza_module.so`** — compiled against the exact NGINX ABI from the NIC image
2. **`libcoraza.so`** — the Go-based Coraza engine, loaded at runtime via dlopen
3. **OWASP CRS rules** — baked into `/etc/coraza/crs/`

WAF is wired in through NIC's snippet mechanism:

```
main context:   load_module ngx_http_coraza_module.so    ← main-snippets
http context:   coraza_rules_file (engine + CRS)         ← http-snippets
server context: coraza on                                ← server-snippets
```

Every Ingress/VirtualServer inherits the WAF by default and can opt out or tune rules per-resource via annotations.

## Usage

### 1. Install NIC with the custom image

```bash
helm upgrade --install nginx-ingress oci://ghcr.io/nginx/charts/nginx-ingress \
  -n nginx-ingress --create-namespace \
  -f examples/nginx-ingress-helm-values.yaml
```

See [examples/nginx-ingress-helm-values.yaml](examples/nginx-ingress-helm-values.yaml) for the full values file, including the ConfigMap volume for hot-reloadable engine config.

The ConfigMap referenced by the volume must exist before the Helm install:

```bash
kubectl apply -f examples/coraza-config.yaml
```

### 2. Switch WAF mode

`coraza.conf` defaults to `DetectionOnly` (log but don't block). To block:

```bash
kubectl edit configmap coraza-config -n nginx-ingress
# change: SecRuleEngine DetectionOnly → SecRuleEngine On
kubectl rollout restart deployment nginx-ingress-controller -n nginx-ingress
```

### 3. Per-resource overrides

Requires `enableSnippets: true` in the Helm values (already set in the example).

| Use case                          | Annotation                                               |
| --------------------------------- | -------------------------------------------------------- |
| WAF active (default)              | no annotation needed                                     |
| Disable WAF for an Ingress        | `nginx.org/location-snippets: "coraza off;"`             |
| Suppress specific rules           | `nginx.org/location-snippets` with inline `coraza_rules` |
| Per-route control (VirtualServer) | route `location-snippets` field                          |

See [examples/](examples/) for complete manifests covering all cases.

## Keeping components up to date

| Component                | Where to update                                             | Release page                                                     |
| ------------------------ | ----------------------------------------------------------- | ---------------------------------------------------------------- |
| NGINX Ingress Controller | `NIC_VERSION` / `NIC_DIGEST` in Dockerfile + `VERSION` file | [releases](https://github.com/nginx/kubernetes-ingress/releases) |
| libcoraza                | `LIBCORAZA_VERSION` / `LIBCORAZA_SHA256` in Dockerfile      | [releases](https://github.com/corazawaf/libcoraza/releases)      |
| coraza-nginx module      | `CORAZA_NGINX_VERSION` in Dockerfile                        | [releases](https://github.com/corazawaf/coraza-nginx/releases)   |
| OWASP CRS                | `CRS_VERSION` in Dockerfile                                 | [releases](https://github.com/coreruleset/coreruleset/releases)  |
| Go (builder)             | `GO_VERSION` / `GO_DIGEST` in Dockerfile                    | [releases](https://go.dev/doc/devel/release)                     |
| Alpine (CRS stage)       | `ALPINE_VERSION` / `ALPINE_DIGEST` in Dockerfile            | [releases](https://alpinelinux.org/releases/)                    |

**Update procedure:**

1. Update the relevant `ARG` values in [Dockerfile](Dockerfile)
2. If `NIC_VERSION` changed, also bump [VERSION](VERSION) to match — this publishes a new immutable version tag (e.g., `:5.5.0`) without overwriting the previous one
3. Push to main — CI builds and publishes `:latest`, `:sha-<commit>`, and the version tag

**Getting digests:**

```bash
# Base images (golang, nginx-ingress, alpine)
docker manifest inspect nginx/nginx-ingress:<VERSION> \
  | jq -r '.manifests[] | select(.platform.os=="linux" and .platform.architecture=="amd64") | .digest'

# libcoraza — no release artifacts, SHA256 is self-computed
curl -fsSL "https://github.com/corazawaf/libcoraza/tarball/<VERSION>" | sha256sum
```

> When bumping `NIC_VERSION`, also check the [coraza-nginx changelog](https://github.com/corazawaf/coraza-nginx/releases) for a newer `CORAZA_NGINX_VERSION` — newer NGINX versions occasionally change internal C APIs the module hooks into, causing a compile error. The ABI recompilation itself is automatic: Stage 2 reads `nginx -v` at build time and compiles the module against the matching NGINX source.

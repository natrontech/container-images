# nginx-ingress-coraza

[NGINX Ingress Controller](https://docs.nginx.com/nginx-ingress-controller/) extended with the [Coraza WAF module](https://github.com/corazawaf/coraza-nginx) and [OWASP Core Rule Set](https://coreruleset.org/) — baked in, no NIC source changes required.

**Image**: `ghcr.io/natrontech/container-images/nginx-ingress-coraza`

## Architecture

The image adds three components on top of the official NIC image:

1. **`ngx_http_coraza_module.so`** — compiled against the exact NGINX ABI from the NIC image (Stage 2 reads `nginx -v` at build time and downloads the matching NGINX source to compile against)
2. **`libcoraza.so`** — the Go-based Coraza engine, compiled as a C shared library and loaded at runtime via `dlopen`
3. **OWASP CRS rules** — baked into `/etc/coraza/crs/`, GPG-verified at build time

WAF is wired in through NIC's snippet mechanism:

```
main context:   load_module modules/ngx_http_coraza_module.so                   ← main-snippets
http context:   coraza_rules_file /etc/coraza/coraza.conf                       ← http-snippets
                coraza_rules_file /etc/coraza/coraza-crs-include.conf
server context: coraza on                                                       ← server-snippets
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

### Running with `readOnlyRootFilesystem: true`

NGINX writes temporary files (client body buffers, proxy cache, etc.) to `/tmp` at runtime. When `readOnlyRootFilesystem: true` is set on the container security context, this directory is not writable and the pod will enter **CrashLoopBackOff** immediately on startup.

To fix this, mount an `emptyDir` volume at `/tmp`:

```yaml
# in controller.volumes
- name: nginx-tmp
  emptyDir: {}

# in controller.volumeMounts
- name: nginx-tmp
  mountPath: /tmp
```

The example values file already includes this volume alongside the full hardened security context (`readOnlyRootFilesystem`, `runAsNonRoot`, dropped capabilities, seccomp profile). See [examples/nginx-ingress-helm-values.yaml](examples/nginx-ingress-helm-values.yaml).

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

| Component                | Pinned version | Where to update                                             | Release page                                                     |
| ------------------------ | -------------- | ----------------------------------------------------------- | ---------------------------------------------------------------- |
| NGINX Ingress Controller | `5.5.1`        | `NIC_VERSION` / `NIC_DIGEST` in Dockerfile + `VERSION` file | [releases](https://github.com/nginx/kubernetes-ingress/releases) |
| libcoraza                | `v1.6.0`       | `LIBCORAZA_VERSION` / `LIBCORAZA_SHA256` in Dockerfile      | [releases](https://github.com/corazawaf/libcoraza/releases)      |
| coraza-nginx module      | `v0.11.2`      | `CORAZA_NGINX_VERSION` in Dockerfile                        | [releases](https://github.com/corazawaf/coraza-nginx/releases)   |
| OWASP CRS                | `v4.27.0`      | `CRS_VERSION` in Dockerfile                                 | [releases](https://github.com/coreruleset/coreruleset/releases)  |
| Go (builder)             | `1.26`         | `GO_VERSION` / `GO_DIGEST` in Dockerfile                    | [releases](https://go.dev/doc/devel/release)                     |
| Alpine (CRS stage)       | `3.24`         | `ALPINE_VERSION` / `ALPINE_DIGEST` in Dockerfile            | [releases](https://alpinelinux.org/releases/)                    |

**Update procedure:**

1. Update the relevant `ARG` values in [Dockerfile](Dockerfile) and the **Pinned version** column above
2. If `NIC_VERSION` changed, also bump [VERSION](VERSION) to match — this publishes a new immutable version tag (e.g., `:5.5.0`) without overwriting the previous one
3. Push to main — CI builds and publishes `:latest`, `:sha-<commit>`, and the version tag

**Getting digests:**

```bash
# Multi-platform manifest digest (what the Dockerfile ARG expects)
docker buildx imagetools inspect golang:1.26-bookworm \
  --format '{{json .Manifest}}' | jq -r '.digest'

docker buildx imagetools inspect nginx/nginx-ingress:5.5.1 \
  --format '{{json .Manifest}}' | jq -r '.digest'

docker buildx imagetools inspect alpine:3.24 \
  --format '{{json .Manifest}}' | jq -r '.digest'

# libcoraza SHA256 — computed from the tarball (no signed release artifact)
curl -fsSL "https://github.com/corazawaf/libcoraza/tarball/v1.6.0" | sha256sum
```

> When bumping `NIC_VERSION`, also check the [coraza-nginx changelog](https://github.com/corazawaf/coraza-nginx/releases) for a newer `CORAZA_NGINX_VERSION` — newer NGINX versions occasionally change internal C APIs the module hooks into, causing a compile error. The ABI recompilation itself is automatic: Stage 2 reads `nginx -v` at build time and compiles the module against the matching NGINX source.

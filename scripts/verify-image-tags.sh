#!/usr/bin/env bash
#
# Verify that every tag of every published image fully resolves on ghcr.io:
# the tag's manifest exists and, for a multi-arch/attested index, every
# referenced child manifest (per-arch image, provenance/SBOM) exists too.
#
# Anonymous registry access — works for public images, no token needed.
#
# Usage: ./scripts/verify-image-tags.sh [container-name ...]

set -euo pipefail

ORG="natrontech"
ACCEPT="application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json"

containers=("$@")
if [[ ${#containers[@]} -eq 0 ]]; then
	for dir in */; do
		[[ -f "${dir}Dockerfile" ]] && containers+=("$(basename "$dir")")
	done
fi

broken=0

for container in "${containers[@]}"; do
	repo="${ORG}/container-images/${container}"
	echo "== ${repo}"

	token=$(curl -sf "https://ghcr.io/token?service=ghcr.io&scope=repository:${repo}:pull" | jq -r .token)
	tags=$(curl -sf -H "Authorization: Bearer ${token}" \
		"https://ghcr.io/v2/${repo}/tags/list?n=1000" | jq -r '.tags[]?')

	for tag in ${tags}; do
		# skip cosign attestation/signature/referrer tags
		if [[ "${tag}" =~ ^sha256-[a-f0-9]{64}(\.(att|sig|sbom))?$ ]]; then
			continue
		fi

		manifest=$(curl -s -H "Authorization: Bearer ${token}" -H "Accept: ${ACCEPT}" \
			"https://ghcr.io/v2/${repo}/manifests/${tag}")

		if [[ "$(jq -r '.errors[0].code // empty' <<<"${manifest}")" != "" ]]; then
			echo "  BROKEN ${tag}: manifest missing"
			broken=$((broken + 1))
			continue
		fi

		missing=0
		total=0
		for digest in $(jq -r '.manifests[]?.digest' <<<"${manifest}"); do
			total=$((total + 1))
			code=$(curl -s -o /dev/null -w '%{http_code}' -I \
				-H "Authorization: Bearer ${token}" -H "Accept: ${ACCEPT}" \
				"https://ghcr.io/v2/${repo}/manifests/${digest}")
			[[ "${code}" != "200" ]] && missing=$((missing + 1))
		done

		if [[ ${missing} -gt 0 ]]; then
			echo "  BROKEN ${tag}: ${missing}/${total} child manifests missing"
			broken=$((broken + 1))
		else
			echo "  ok     ${tag}"
		fi
	done
done

echo
if [[ ${broken} -gt 0 ]]; then
	echo "FAILED: ${broken} broken tag(s)"
	exit 1
fi
echo "All tags fully resolvable."

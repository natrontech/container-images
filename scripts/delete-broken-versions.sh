#!/usr/bin/env bash
#
# Delete GHCR package versions whose tags no longer fully resolve (broken
# multi-arch indexes whose child manifests were lost and are past GitHub's
# 30-day restore window).
#
# A version is only deleted when ALL of the following hold:
#   - it carries at least one real (non-attestation) tag
#   - it does NOT carry `latest` or `nightly`
#   - its manifest is an index and at least one referenced child manifest
#     is missing from the registry (i.e. the tag is unpullable)
#
# Deleted versions remain restorable for 30 days via
# ./scripts/restore-deleted-versions.sh in case of a mistake.
#
# Requires a gh CLI token with read:packages and delete:packages:
#   gh auth refresh -s read:packages,write:packages,delete:packages
#
# Usage:
#   ./scripts/delete-broken-versions.sh              # dry-run: list broken versions
#   DRY_RUN=false ./scripts/delete-broken-versions.sh    # actually delete

set -euo pipefail

ORG="natrontech"
DRY_RUN="${DRY_RUN:-true}"
ACCEPT="application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json"
ATTESTATION_TAG_RE='^sha256-[a-f0-9]{64}(\.(att|sig|sbom))?$'

packages=()
for dir in */; do
	if [[ -f "${dir}Dockerfile" ]]; then
		packages+=("container-images/$(basename "$dir")")
	fi
done

total_broken=0

for pkg in "${packages[@]}"; do
	enc="${pkg//\//%2F}"
	repo="${ORG}/${pkg}"
	echo "== ${pkg}"

	token=$(curl -sf "https://ghcr.io/token?service=ghcr.io&scope=repository:${repo}:pull" | jq -r .token)

	while IFS=$'\t' read -r id digest tags; do
		[[ -z "${tags}" ]] && continue # untagged — the cleanup workflow's business

		# collect real (non-attestation) tags; skip pure attestation-blob versions
		real_tags=()
		IFS=',' read -ra tag_arr <<<"${tags}"
		for t in "${tag_arr[@]}"; do
			[[ "${t}" =~ ${ATTESTATION_TAG_RE} ]] || real_tags+=("${t}")
		done
		[[ ${#real_tags[@]} -eq 0 ]] && continue

		# never touch the versions currently serving latest/nightly
		for t in "${real_tags[@]}"; do
			if [[ "${t}" == "latest" || "${t}" == "nightly" ]]; then
				continue 2
			fi
		done

		manifest=$(curl -s -H "Authorization: Bearer ${token}" -H "Accept: ${ACCEPT}" \
			"https://ghcr.io/v2/${repo}/manifests/${digest}")

		missing=0
		total=0
		for child in $(jq -r '.manifests[]?.digest' <<<"${manifest}"); do
			total=$((total + 1))
			code=$(curl -s -o /dev/null -w '%{http_code}' -I \
				-H "Authorization: Bearer ${token}" -H "Accept: ${ACCEPT}" \
				"https://ghcr.io/v2/${repo}/manifests/${child}")
			[[ "${code}" != "200" ]] && missing=$((missing + 1))
		done

		[[ ${missing} -eq 0 ]] && continue # fully resolvable — keep

		total_broken=$((total_broken + 1))
		echo "  BROKEN version=${id} tags=[${tags}] (${missing}/${total} children missing)"
		if [[ "${DRY_RUN}" != "true" ]]; then
			if gh api -X DELETE \
				"/orgs/${ORG}/packages/container/${enc}/versions/${id}" >/dev/null; then
				echo "    -> deleted"
			else
				echo "    -> DELETE FAILED"
			fi
		fi
	done < <(gh api --paginate \
		"/orgs/${ORG}/packages/container/${enc}/versions?per_page=100" \
		--jq '.[] | "\(.id)\t\(.name)\t\(.metadata.container.tags | join(","))"')
done

echo
if [[ "${DRY_RUN}" == "true" ]]; then
	echo "Dry-run only: found ${total_broken} broken version(s). Re-run with DRY_RUN=false to delete them."
else
	echo "Deleted ${total_broken} broken version(s). Verify with: ./scripts/verify-image-tags.sh"
	echo "Orphaned attestation blobs will be garbage-collected by the next cleanup workflow run."
fi

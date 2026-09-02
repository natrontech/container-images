#!/usr/bin/env bash
#
# Restore GHCR package versions deleted by the cleanup workflow.
#
# GitHub keeps deleted package versions for 30 days — this restores every
# version still inside that window. Restoring "too much" is safe: genuinely
# orphaned versions will be re-deleted correctly by the fixed cleanup job.
#
# Requires a gh CLI token with read:packages, write:packages, delete:packages:
#   gh auth refresh -s read:packages,write:packages,delete:packages
#
# Usage:
#   ./scripts/restore-deleted-versions.sh            # dry-run: list restorable versions
#   DRY_RUN=false ./scripts/restore-deleted-versions.sh   # actually restore

set -euo pipefail

ORG="natrontech"
DRY_RUN="${DRY_RUN:-true}"

# Discover packages from the repo layout (every dir with a Dockerfile)
packages=()
for dir in */; do
	if [[ -f "${dir}Dockerfile" ]]; then
		packages+=("container-images/$(basename "$dir")")
	fi
done

for pkg in "${packages[@]}"; do
	enc="${pkg//\//%2F}"
	echo "== ${pkg}"

	restorable=$(gh api --paginate \
		"/orgs/${ORG}/packages/container/${enc}/versions?state=deleted&per_page=100" \
		--jq '.[] | "\(.id)\t\(.name)\t\(.updated_at)\t\(.metadata.container.tags | join(","))"' || true)

	if [[ -z "${restorable}" ]]; then
		echo "  nothing restorable (30-day window expired or nothing deleted)"
		continue
	fi

	while IFS=$'\t' read -r id digest updated tags; do
		echo "  ${id}  ${digest}  updated=${updated}  tags=[${tags}]"
		if [[ "${DRY_RUN}" != "true" ]]; then
			if gh api -X POST \
				"/orgs/${ORG}/packages/container/${enc}/versions/${id}/restore" >/dev/null; then
				echo "    -> restored"
			else
				echo "    -> RESTORE FAILED"
			fi
		fi
	done <<<"${restorable}"
done

if [[ "${DRY_RUN}" == "true" ]]; then
	echo
	echo "Dry-run only. Re-run with DRY_RUN=false to restore the versions above."
else
	echo
	echo "Done. Verify with: ./scripts/verify-image-tags.sh"
fi

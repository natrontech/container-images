# Jupyter scientific-python notebook with nbgitpuller.
#
# Why this image exists: nbgitpuller is not part of the upstream Jupyter Docker
# Stacks, and it cannot be added at runtime. A "pip install --user" lands in
# ~/.local, which the `jupyter` entrypoint (conda's Python) does not see, so the
# server extension never loads and /user-redirect/git-pull 404s. Installing into
# the conda environment is the only reliable route, which means baking an image.
# Measured against scipy-notebook:2026-09-01 on 2026-09-08.
#
# Every profile needs it, not just this one: /hub/user-redirect/git-pull
# redirects to whichever server the user currently has running, with no profile
# selection, so a student on a GPU profile would otherwise get a 404. See the
# jupyter-pytorch-nbgitpuller and jupyter-tensorflow-nbgitpuller images.
FROM quay.io/jupyter/scipy-notebook:2026-09-01@sha256:41e9176dc64072976c43c037f853ae9a95ca34aeb0170c58a1b304d62fbde486

# The base image already drops to this user; repeated so the Dockerfile is
# explicit about not installing as root.
USER ${NB_UID}

COPY requirements.txt VERSION ./

# Three guards, because a silently broken install here shows up as a 404 on a
# student's course link rather than as an error anyone would notice:
#   1. the package imports
#   2. the server extension actually registered
#   3. VERSION still matches the pinned nbgitpuller release, so a Dependabot bump
#      of requirements.txt cannot publish an image tagged with a stale version.
#      A base-image-only bump may add a revision suffix, e.g. 1.3.0-2, so this is
#      a prefix check rather than equality.
RUN pip install --no-cache-dir -r requirements.txt && \
	installed="$(python3 -c 'import nbgitpuller; print(nbgitpuller.__version__)')" && \
	jupyter server extension list 2>&1 | grep -q nbgitpuller && \
	case "$(tr -d '[:space:]' < VERSION)" in \
		"${installed}"*) ;; \
		*) echo "VERSION does not match nbgitpuller ${installed}" >&2; exit 1 ;; \
	esac && \
	rm -f requirements.txt VERSION

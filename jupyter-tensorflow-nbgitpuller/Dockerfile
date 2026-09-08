# Jupyter TensorFlow CUDA notebook with nbgitpuller.
#
# Why this image exists: nbgitpuller is not part of the upstream Jupyter Docker
# Stacks, and it cannot be added at runtime. A "pip install --user" lands in
# ~/.local, which the `jupyter` entrypoint (conda's Python) does not see, so the
# server extension never loads and /user-redirect/git-pull returns 404.
# Installing into the conda environment is the only reliable route, which means
# baking an image. Measured on 2026-09-08.
#
# Why the GPU flavours need it too: /hub/user-redirect/git-pull redirects to
# whichever server the user currently has running, with no profile selection.
# A student sitting on a GPU profile who clicks a course link would otherwise
# get a 404, so every profile a student can be on needs the extension.
FROM quay.io/jupyter/tensorflow-notebook:cuda-2026-09-07@sha256:389f89a56e5298f4f762c2c47bdaeca10a0d8244e029b896248e096ae1a0d6da

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

# GitHub Actions Workflows

This directory contains the automated workflows for building, publishing, and maintaining container images.

## Workflows

### 🏗️ container-build.yml
**Purpose:** Main workflow for building and publishing container images

**Triggers:**
- **Schedule:** Every night at 02:00 UTC
- **Push:** When changes are pushed to main branch
- **Manual:** Can be triggered manually with optional container selection

**Features:**
- 🔍 **Auto-discovery:** Automatically finds all directories with Dockerfiles
- 🏗️ **Matrix builds:** Builds multiple containers in parallel
- 🏷️ **Smart tagging:** 
  - `:nightly` for scheduled builds
  - `:sha-XXXXXXX` for all builds
  - `:latest` for main branch pushes
- 🔒 **Security:** Cosign signing, SLSA provenance, SBOM generation
- 🌐 **Multi-arch:** Builds for linux/amd64 and linux/arm64
- ✅ **Verification:** Validates signatures and attestations

### 🧹 cleanup.yml
**Purpose:** Keeps the container registry clean by removing old images

**Triggers:**
- **Schedule:** Every Sunday at 03:00 UTC
- **Manual:** Can be triggered with custom retention settings

**Features:**
- Removes old container versions (keeps minimum 10)
- Cleans up untagged images
- Configurable retention period

### 📊 scorecard.yml
**Purpose:** Security scorecard analysis for supply chain security

**Triggers:**
- **Schedule:** Every Monday at 14:00 UTC
- **Push:** On main branch changes
- **Branch protection:** When branch protection rules change

## Container Discovery

The build system automatically discovers containers by:
1. Scanning the repository root for directories
2. Checking if each directory contains a `Dockerfile`
3. Using the directory name as the container image name

Example structure:
```
my-tool/
├── Dockerfile      ← Required
├── entrypoint.sh   ← Optional
└── healthcheck.sh  ← Optional
```

Results in: `ghcr.io/natrontech/container-images/my-tool:nightly`

## Manual Workflow Dispatch

### Build Specific Containers
To build only specific containers manually:
1. Go to **Actions** → **Container Build & Publish**
2. Click **Run workflow**
3. Enter comma-separated container names (e.g., `tcp-forwarder,my-tool`)
4. Leave empty to build all containers

### Cleanup with Custom Settings
To run cleanup with custom retention:
1. Go to **Actions** → **Container Cleanup**
2. Click **Run workflow**
3. Set maximum age in days

## Security Features

All container images include:
- 🔏 **Cosign signatures** for image authenticity
- 📜 **SLSA Level 3 provenance** for build integrity
- 📋 **CycloneDX SBOM** for dependency tracking
- 🛡️ **Multi-stage verification** ensuring security

## Adding New Containers

1. Create a new directory: `mkdir my-new-tool`
2. Add a Dockerfile: `touch my-new-tool/Dockerfile`
3. Commit and push to main branch
4. The container will be automatically built on the next workflow run

No configuration changes needed - everything is automatic!

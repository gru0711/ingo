# Agent environment for the cron-parser "W / LW day-of-month" task.
#
# Contains: the unchanged upstream baseline (history up to the baseline SHA only), its locked
# dependencies, a compiled build, and the agent-facing TASK.md.
# Does NOT contain: the reference solution, private verifiers, evaluation scripts or logs.
#
# Build context is the deliverables directory; .dockerignore admits only TASK.md and the vendored
# baseline bundle (vendor/cron-parser-5b08cdf.bundle, created with `git bundle create ... HEAD --tags`
# from the baseline checkout). The bundle removes any build-time dependency on GitHub.

# node:24-bookworm (Node 24.21.0, npm 11.19.0, git 2.39.5), resolved 2026-10-05
FROM node:24-bookworm@sha256:64af3819f9275802414d7cdc38c27e9d82bd564dec4d4da87d008255d36c63b4

ARG BASE_SHA=5b08cdf831c94a656def5a6ab7008f1e497d21b2

ENV TZ=UTC \
    CI=true \
    HUSKY=0 \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    BASE_SHA=${BASE_SHA}

WORKDIR /workspace
RUN chown node:node /workspace
USER node

# Baseline source with upstream history (448 commits, newest = BASE_SHA), cloned from the vendored
# bundle through a bind mount so the bundle itself never lands in an image layer. The remote, any
# branches, tags not merged into HEAD, the reflog and unreachable objects are removed, so the
# repository holds only commits reachable from the baseline.
RUN --mount=type=bind,source=vendor/cron-parser-5b08cdf.bundle,target=/tmp/baseline.bundle \
    git clone --quiet --no-checkout /tmp/baseline.bundle cron-parser \
 && cd cron-parser \
 && git -c advice.detachedHead=false checkout --quiet --detach "${BASE_SHA}" \
 && test "$(git rev-parse HEAD)" = "${BASE_SHA}" \
 && git remote remove origin \
 && git for-each-ref --format='%(refname)' refs/heads | xargs -r -n1 git update-ref -d \
 && git tag --no-merged HEAD | xargs -r git tag -d \
 && git reflog expire --expire=now --all \
 && git gc --quiet --prune=now \
 && git config user.name "Agent" \
 && git config user.email "agent@localhost"

WORKDIR /workspace/cron-parser

# Exact dependency versions from the upstream package-lock.json. `prepare` builds dist/.
RUN npm ci \
 && npm cache clean --force

# Build-time baseline verification (lint, type tests, unit tests with coverage), then drop
# caches and coverage output so the image starts clean.
RUN npm test \
 && rm -rf coverage /tmp/jest_* \
 && git status --porcelain --ignored=no | (! grep .)

COPY --chown=node:node --chmod=0644 TASK.md /workspace/TASK.md

CMD ["bash"]

# Studio runtime checks

[`studio.yml`](../.github/workflows/studio.yml) runs the structural and two-player Studio suites on a dedicated Windows runner. It checks out the exact commit that passed the source workflow, runs the same test command used locally, and uploads a JSON result containing the commit, completion time, suite counts, and overall status.

The workflow is disabled until the repository variable `STUDIO_RUNTIME_TESTS` is set to `true`. The regular source workflow remains active independently. A skipped Studio job means runtime execution is disabled; it is not a passing runtime result.

## Runner setup

1. Prepare a dedicated Windows machine with Roblox Studio installed and signed in. Keep it separate from personal files and unrelated project credentials.
2. Install PowerShell 7 and Git. Run the GitHub runner in the signed-in desktop session so Studio can launch its test clients. A Windows service session does not provide that desktop.
3. Register the runner for this repository with the additional label `roblox-studio`. The workflow also requires the default `self-hosted` and `Windows` labels. See [GitHub's runner setup](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners).
4. Verify the command below on that machine. It builds a local test place and does not publish to Roblox or modify a live game.
5. Set the repository Actions variable `STUDIO_RUNTIME_TESTS` to `true`, then run **Studio runtime checks** from `master` once to verify the installation.

```powershell
./tests/RunStudioTests.ps1 -ReportPath "$env:TEMP/chassis-runtime.json"
```

## Execution rules

- Automatic execution follows a successful **Source checks** run for a push to this repository's `master` branch.
- Manual execution requires both `master` and the enabled repository variable.
- Pull requests, fork workflows, and other branches are excluded from Studio execution.
- The checkout uses the triggering commit, has read-only repository permissions, and does not retain GitHub credentials in Git configuration.
- Actions are pinned to commit revisions. Concurrent Studio runs are serialized on this repository's runner.
- Only the generated JSON result is uploaded. Raw Studio logs and local account data are excluded.

To disable Studio CI, remove the variable or set it to `false`. The local test command remains available.

## Results

Both suites must emit their success marker and a check count. The multiplayer result includes a unique invocation ID, so a result from an older Studio log cannot satisfy a new run. A missing marker, assertion failure, or timeout fails the command and the CI job.

When a suite fails after Studio execution begins, the JSON report records the overall failure and any suites that already passed. Missing prerequisites or a failed Rojo build stop before Studio execution; the Actions step reports the error and may have no JSON artifact.

Local reports include `workingTreeDirty` so results from uncommitted changes are distinguishable from results for a clean checkout. Counts are read from the completed suites, not hard-coded in the workflow.

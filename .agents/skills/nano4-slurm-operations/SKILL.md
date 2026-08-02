---
name: nano4-slurm-operations
description: Operate Slurm safely on the NCHC Nano4 cluster, including wallet balance checks, project/account authorization, partition discovery and compatibility, GPU resource selection, sbatch submission, squeue/sacct status inspection, and non-polling monitoring. Use for Nano4 job preparation, submission, diagnosis, cancellation, project selection, partition choice, or questions involving GOV115071, the dev partition, and GPU jobs.
---

# Nano4 Slurm Operations

Perform live discovery before relying on documented values. Nano4 project balances,
associations, partitions, limits, resources, and Allow/DenyAccounts policies can
change.

## Preflight

1. Confirm the login host matches `25a-lgn*` and Slurm reports cluster `hpc`.
2. Run the bundled read-only preflight:

   ```bash
   bash .agents/skills/nano4-slurm-operations/scripts/slurm-preflight.sh \
     --project "<PROJECT_ID>" \
     --partition "<PARTITION>"
   ```

3. Stop before submission if the script reports a wallet, account, association,
   policy, or partition error.
4. Do not treat a previously successful job as permanent authorization. Repeat the
   live preflight before every submission.
5. If working outside this repository, resolve the installed skill directory first
   and run the same script from that location.

Read [references/accounts-and-partitions.md](references/accounts-and-partitions.md)
when selecting an account or partition. Read
[references/commands.md](references/commands.md) for exact Nano4 commands and job
lifecycle operations.

## Account and Partition Selection

- Use the user-authorized general wallet project `GOV115071` for this repository's
  Nano4 jobs.
- Use `GOV115071` with the live `dev` GPU partition only after all of the following
  checks pass:
  - `wallet GOV115071` confirms that the project is active.
  - The current user has a `gov115071` Slurm association.
  - The live `dev` partition policy does not exclude `gov115071`.
  - The partition state and resource limits support the requested job.
- The `GOV115071 + dev` combination was successfully verified on 2026-08-03 by
  Job `230782`, which completed with exit code `0:0` using one NVIDIA H200 GPU.
  Treat this as prior evidence only; live scheduler output always takes precedence.
- Do not assume every general wallet project can use every GPU or special-purpose
  partition. Inspect `AllowAccounts`, `DenyAccounts`, `AllowGroups`, QoS, time
  limits, state, and available resources.
- Never place a personal project ID in a version-controlled `#SBATCH --account`
  directive. Supply the authorized project at submission time:

  ```bash
  sbatch --account="GOV115071" job.slurm
  ```

- If the user requests another project or partition, rerun preflight and require
  explicit authorization before choosing which project budget to charge.

## Resource Selection

- Use the `dev` GPU partition for this repository's formal workflow scripts.
- Request one task and one GPU:

  ```bash
  #SBATCH --partition=dev
  #SBATCH --ntasks=1
  #SBATCH --gpus-per-node=1
  ```

- Nano4 rejected the generic `--gpus=1` form during live testing and reported that
  GPU partitions require `--gpus-per-node=<num>`. Use
  `--gpus-per-node=1` unless a newer live scheduler check proves otherwise.
- Do not use an unverified `--gres=gpu:1` substitution when the verified
  `--gpus-per-node=1` form is available.
- Formal nf-core/ampliseq scripts in this repository must not specify:
  - `#SBATCH --cpus-per-task`
  - `#SBATCH --mem`
  - `#SBATCH --nodes`
- Keep a finite `#SBATCH --time`. The live `dev` maximum was four hours at the
  2026-08-03 verification, so the repository default is:

  ```bash
  #SBATCH --time=04:00:00
  ```

- Recheck the live `dev` maximum before changing the time limit.
- Ensure the Slurm output directory exists before calling `sbatch`; Slurm opens
  output and error files before running the script body.
- Requesting a GPU does not automatically make an application GPU-accelerated.
  Confirm whether the application can use CUDA before claiming a performance
  benefit.

## Submission Safety

Before submission:

1. Resolve the exact job script, working directory, inputs, outputs, account,
   partition, time limit, and GPU request.
2. Run `bash -n` for every Bash or Slurm job script.
3. Confirm the job script fails fast with `set -euo pipefail`.
4. Confirm the script contains `#SBATCH --partition=dev`.
5. Confirm the script contains `#SBATCH --ntasks=1`.
6. Confirm the script contains `#SBATCH --gpus-per-node=1`.
7. For formal workflow scripts, confirm the script does not contain explicit
   `--cpus-per-task`, `--mem`, `--nodes`, or `--account` directives.
8. Confirm the required log directory exists and `logs/.gitkeep` remains tracked.
9. Confirm compute-node commands do not download pipeline, container, or reference
   assets.
10. For nf-core/ampliseq, validate metadata, samplesheet paths, FASTQ paths,
    Nextflow configuration, Singularity configuration, pipeline assets, container
    images, and taxonomy references.
11. Run the Nano4 preflight with the exact submission combination:

    ```bash
    bash .agents/skills/nano4-slurm-operations/scripts/slurm-preflight.sh \
      --project "GOV115071" \
      --partition "dev"
    ```

12. Stop before submission if any validation fails.

Use `sbatch --test-only` when scheduler-level validation is useful without creating
a job:

```bash
sbatch --test-only \
  --account="GOV115071" \
  path/to/job.slurm
```

Submit only after all checks pass:

```bash
mkdir -p logs
sbatch --account="GOV115071" path/to/job.slurm
```

After submission:

1. Report the Job ID immediately.
2. Take one `squeue` snapshot.
3. Use `sacct` for terminal state, exit code, elapsed time, and allocated resources.
4. Use product scheduling or background monitoring when available.
5. Never occupy the session with a continuous `sleep` polling loop.

## GPU Smoke Test

Use a minimal GPU smoke test before running a full workflow when GPU access has not
recently been verified.

The smoke test should:

- Use `dev`.
- Request one task.
- Request one GPU with `--gpus-per-node=1`.
- Use a short finite time limit.
- Run `nvidia-smi -L` and a concise `nvidia-smi` query.
- Perform no download and make no changes to workflow results.

Verify the completed job with:

```bash
sacct -j "<JOB_ID>" \
  --format=JobID,JobName%30,Account,Partition,State,ExitCode,Elapsed,Timelimit,AllocCPUS,ReqMem,AllocTRES
```

A successful submission message alone is not sufficient. Confirm that the job
reaches `COMPLETED` with exit code `0:0` and that its log identifies an allocated
GPU.

## Status, Failure, and Cancellation

- Use `squeue` for queued or running state.
- Use `sacct` for terminal state, exit code, elapsed time, time limit, and allocated
  resources.
- Inspect Slurm output/error files and application logs before resubmitting.
- For GPU failures, confirm:
  - `CUDA_VISIBLE_DEVICES` is set.
  - `nvidia-smi -L` detects the allocated GPU.
  - `sacct` reports `gres/gpu=1`.
  - The application itself supports and enables GPU execution.
- Prefer workflow-native resume capabilities such as Nextflow `-resume`.
- Treat `scancel` as a state-changing action. Resolve the exact Job ID and obtain
  user authorization unless cancellation was explicitly requested.
- Never delete work directories, results, or logs merely to retry a job.
- Treat result deletion, log deletion, and work-directory deletion as destructive
  actions requiring exact targets and explicit authorization.

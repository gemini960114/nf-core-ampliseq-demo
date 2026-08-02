# Project execution rules

- Before any Nano4 Slurm project selection, partition choice, submission,
  monitoring, diagnosis, or cancellation, use
  `.agents/skills/nano4-slurm-operations/SKILL.md`.
- For nf-core/ampliseq work, also use
  `.agents/skills/slurm-ampliseq-guide/SKILL.md`.
- Run the Nano4 read-only preflight before every submission. Resolve wallet
  validity, the current user's Slurm association, and the exact partition's
  AllowAccounts/DenyAccounts policy.
- Use the user-authorized general wallet project `GOV115071` for this
  repository's Nano4 jobs.
- Use the `dev` GPU partition with one task and one GPU. Request the GPU with
  `#SBATCH --gpus-per-node=1`; Nano4 rejected the generic `--gpus=1` form during
  live verification.
- The `GOV115071` and `dev` combination was successfully verified on 2026-08-03
  by Job `230782`, which completed with one NVIDIA H200 GPU. Treat this only as
  prior evidence and repeat live preflight before every submission.
- Formal nf-core/ampliseq Slurm scripts must not specify an explicit CPU count,
  RAM amount, or node count. Keep `#SBATCH --ntasks=1` and
  `#SBATCH --gpus-per-node=1`.
- Use a finite time limit compatible with `dev`. Its live maximum was four hours
  at the last verification.
- Never commit a personal project ID in a `#SBATCH --account` directive. Pass
  the authorized project at submission time with
  `sbatch --account="GOV115071" <JOB_SCRIPT>`.
- Stop before submission if wallet validation, Slurm association, partition
  policy, shell validation, input validation, or required-asset validation
  fails.
- Keep `logs/.gitkeep` tracked and ensure the required log directory exists
  before `sbatch`, because Slurm opens output and error files before executing
  the job body.
- Prepare the pipeline, containers, modules, and reference assets on the login
  node. Do not download assets from a compute job.
- Keep nf-core/ampliseq tasks inside the allocated GPU node using the
  repository's local Nextflow executor and Singularity configuration.
- Validate metadata, generated samplesheet paths, FASTQ paths, shell syntax,
  Nextflow configuration, and required reference assets before submission.
- After submission, report the Job ID immediately and take one
  `squeue`/`sacct` status snapshot. Use non-polling monitoring.
- Treat `scancel`, result deletion, log deletion, and work-directory deletion as
  destructive or state-changing actions requiring exact targets and explicit
  authorization.
- Never delete Nextflow work directories merely to retry a failed workflow.
  Diagnose the failure and prefer `-resume`.

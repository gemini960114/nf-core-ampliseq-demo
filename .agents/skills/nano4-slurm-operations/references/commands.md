# Nano4 Slurm Commands

## Preflight

Run the read-only preflight before every submission:

```bash
bash .agents/skills/nano4-slurm-operations/scripts/slurm-preflight.sh \
  --project "GOV115071" \
  --partition "dev"
```

Stop before submission if wallet, Slurm association, partition policy, or
partition-state validation fails.

## Project and Balance

List active wallet projects:

```bash
wallet
```

Inspect the repository's authorized project:

```bash
wallet GOV115071
```

The local `wallet` command does not implement conventional `--help`; do not use
`wallet --help` as a capability test.

Inspect the current user's Slurm association:

```bash
sacctmgr -nP show assoc user="$USER" account="gov115071" \
  format=Account,Partition,QOS,DefaultQOS
```

## Partition Discovery

List current partitions and resources:

```bash
sinfo -h -o '%P|%a|%l|%D|%c|%m|%G'
```

Inspect the live `dev` partition policy:

```bash
scontrol show partition dev
```

Never parse only the partition name. Inspect its state, `AllowAccounts`,
`DenyAccounts`, `AllowGroups`, QoS, maximum time, and GPU resources from the full
record.

## GPU Job Directives

Formal workflow scripts use:

```bash
#SBATCH --partition=dev
#SBATCH --ntasks=1
#SBATCH --gpus-per-node=1
#SBATCH --time=04:00:00
```

Do not add these directives to formal workflow scripts:

```bash
#SBATCH --account=...
#SBATCH --nodes=...
#SBATCH --cpus-per-task=...
#SBATCH --mem=...
```

Nano4 rejected the generic `--gpus=1` form during live testing. Use the verified
`--gpus-per-node=1` form.

## Submission

Validate the job script:

```bash
bash -n path/to/job.slurm
```

Create the required log directory before submission:

```bash
mkdir -p logs
```

Validate the job with the scheduler without creating a real job:

```bash
sbatch --test-only \
  --account="GOV115071" \
  path/to/job.slurm
```

Submit the job:

```bash
sbatch --account="GOV115071" path/to/job.slurm
```

Capture and report the returned Job ID immediately. Do not add the project ID to a
tracked `#SBATCH --account` directive.

## Queue and Accounting

Show the current user's jobs:

```bash
squeue -u "$USER" \
  -o '%.18i %.12P %.28j %.10T %.10M %.10l %.6D %.12a %R'
```

Inspect one queued or running job:

```bash
squeue -j "<JOB_ID>"
```

Inspect accounting state and allocated GPU resources:

```bash
sacct -j "<JOB_ID>" \
  --format=JobID,JobName%30,Account,Partition,State,ExitCode,Elapsed,Timelimit,AllocCPUS,ReqMem,AllocTRES%50,MaxRSS
```

Confirm that a successful job reaches `COMPLETED` with exit code `0:0`. For GPU
jobs, confirm that `AllocTRES` contains `gres/gpu=1`.

## Cancellation

After resolving the exact target and receiving authorization:

```bash
scancel "<JOB_ID>"
```

Cancellation does not remove job outputs, logs, results, or Nextflow work
directories.

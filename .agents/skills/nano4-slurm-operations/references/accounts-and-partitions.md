# Nano4 Accounts and Partitions

Last verified on Nano4 login host `25a-lgn01`: 2026-08-03.

Live scheduler output always overrides this reference. Wallet balances, Slurm
associations, partition policies, hardware availability, QoS, and time limits can
change without notice.

## Contents

- [Cluster Identity](#cluster-identity)
- [Account Authorization Sources](#account-authorization-sources)
- [Repository Project](#repository-project)
- [Verified `dev` Partition Policy](#verified-dev-partition-policy)
- [Verified GPU Request](#verified-gpu-request)
- [Formal Workflow Resource Profile](#formal-workflow-resource-profile)
- [Successful Live Verification](#successful-live-verification)
- [Formal Script Scheduler Validation](#formal-script-scheduler-validation)
- [GPU Allocation Versus GPU Acceleration](#gpu-allocation-versus-gpu-acceleration)
- [Other Partitions](#other-partitions)
- [Submission Decision](#submission-decision)

## Cluster Identity

The verified Nano4 environment was:

- Login host pattern: `25a-lgn*`
- Slurm cluster: `hpc`
- Target GPU partition: `dev`
- Authorized repository project: `GOV115071`

Stop before submission if the current host or Slurm cluster does not match the
expected Nano4 environment.

## Account Authorization Sources

Nano4 exposes complementary authorization views:

- `wallet`: active project membership and current SU balance.
- `sacctmgr show assoc`: the current user's Slurm account association.
- `scontrol show partition`: the partition's current Allow/DenyAccounts policy.

A project must pass all applicable checks before submission. Do not treat any
single check as sufficient authorization.

For this repository, verify:

1. `wallet GOV115071` reports an active project.
2. The current user has a `gov115071` Slurm association.
3. The live `dev` policy allows the project.
4. The partition is `UP`.
5. The requested GPU and time limit fit the live partition configuration.

## Repository Project

Use the following user-authorized general wallet project:

- Project: `GOV115071`
- Project name observed during verification:
  `2026國研院暑期實習生專案計畫`
- Slurm account form: `gov115071`
- Repository partition: `dev`

The wallet balance is dynamic. Query it immediately before submission rather than
copying a previously observed value into documentation or scripts.

Never put the account in a version-controlled `#SBATCH --account` directive.
Provide it at submission time:

```bash
sbatch --account="GOV115071" path/to/job.slurm
```

If the user selects another project, do not silently substitute it. Require
explicit authorization and rerun all account and partition checks.

## Verified `dev` Partition Policy

The live `dev` partition was verified with the following relevant properties:

- State: `UP`
- QoS: `p_dev`
- Maximum time: `04:00:00`
- GPU type: NVIDIA H200
- GPUs per observed node: 8
- `AllowGroups`: `ALL`
- `AllowAccounts`: not explicitly restricted in the observed record
- `DenyAccounts`: included `mst109178`
- `gov115071`: not present in the observed deny list

The absence of `gov115071` from `DenyAccounts` is not sufficient by itself.
Wallet membership and the current user's Slurm association must also pass.

Repeat the bundled preflight before every submission:

```bash
bash .agents/skills/nano4-slurm-operations/scripts/slurm-preflight.sh \
  --project "GOV115071" \
  --partition "dev"
```

## Verified GPU Request

Nano4 `dev` requires the GPU count in the following form:

```bash
#SBATCH --gpus-per-node=1
```

During live testing, the scheduler rejected:

```bash
#SBATCH --gpus=1
```

with an error stating that GPU partitions require
`--gpus-per-node=<num>`.

The `--gres=gpu:1` form was not verified for this repository. Prefer the tested
`--gpus-per-node=1` form unless a newer live scheduler check demonstrates a
different requirement.

## Formal Workflow Resource Profile

Formal nf-core/ampliseq scripts in this repository use:

```bash
#SBATCH --partition=dev
#SBATCH --ntasks=1
#SBATCH --gpus-per-node=1
#SBATCH --time=04:00:00
```

Do not add the following directives to the formal workflow scripts:

```bash
#SBATCH --account=...
#SBATCH --nodes=...
#SBATCH --cpus-per-task=...
#SBATCH --mem=...
```

The project account must be passed to `sbatch`. CPU, RAM, and node counts are not
explicitly requested under the current repository policy.

The scheduler may still report one allocated processor because the script requests
one task. This does not mean the script contains an explicit CPU-count directive.

## Successful Live Verification

The `GOV115071 + dev` combination was verified by a real GPU smoke-test job:

- Job ID: `230782`
- Date: 2026-08-03
- Account: `gov115071`
- Partition: `dev`
- State: `COMPLETED`
- Exit code: `0:0`
- Elapsed time: `00:00:01`
- Allocated CPUs reported by Slurm: 1
- Allocated GPUs: 1
- GPU model: NVIDIA H200
- Compute node: `25a-hgpn010`
- `CUDA_VISIBLE_DEVICES`: `0`

The job log successfully reported:

- One allocated NVIDIA H200 GPU
- A working `nvidia-smi` command
- GPU driver information
- GPU memory information
- Successful smoke-test completion

This completed job proves that the combination worked at that time. It does not
replace future wallet, association, or partition-policy checks.

## Formal Script Scheduler Validation

After removing explicit CPU, RAM, and node directives, both formal workflow scripts
passed `sbatch --test-only` with `GOV115071` and `dev`:

- `03_scripts/submit_ampliseq.slurm`
- `examples/gut-to-soil/submit_ampliseq.slurm`

The scheduler estimated execution on an H200 GPU node in `dev` using one processor.
`sbatch --test-only` does not create a real job and does not prove that the
application itself uses CUDA.

## GPU Allocation Versus GPU Acceleration

A successful GPU allocation means Slurm assigned a GPU to the job. It does not
guarantee that nf-core/ampliseq, Nextflow, QIIME 2, DADA2, or another application
uses the GPU for computation.

Before claiming GPU acceleration, verify that:

- The application supports GPU execution.
- The required CUDA libraries are available.
- The application is configured to use CUDA.
- GPU utilization is visible during the relevant process.

The current repository configuration uses `dev` because that is the authorized and
available execution path. Do not describe the workflow as GPU-accelerated without
application-level evidence.

## Other Partitions

Visibility in `sinfo` is not authorization. Do not infer access to another
partition from its presence in scheduler output.

Before selecting another partition, inspect:

- `State`
- `AllowAccounts`
- `DenyAccounts`
- `AllowGroups`
- `QoS`
- `MaxTime`
- CPU and memory limits
- GPU type and count
- Special-purpose or reservation requirements

Do not switch away from `dev`, change the project account, or choose another budget
without explicit user authorization.

## Submission Decision

A `GOV115071 + dev` submission is eligible only when all of the following are true:

- The host matches `25a-lgn*`.
- The Slurm cluster is `hpc`.
- `wallet GOV115071` succeeds.
- The current user has a `gov115071` association.
- The live `dev` partition exists and is `UP`.
- `AllowAccounts`, when present, includes `gov115071`.
- `DenyAccounts`, when present, does not include `gov115071`.
- The job requests one GPU with `--gpus-per-node=1`.
- The time limit does not exceed the live `dev` maximum.
- Required log directories exist.
- Shell syntax and workflow inputs pass validation.
- No compute-node download is required.

Stop before submission if any condition fails.

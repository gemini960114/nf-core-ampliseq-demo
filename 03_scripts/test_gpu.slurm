#!/bin/bash
#SBATCH --job-name=gpu_smoke_test
#SBATCH --partition=dev
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --gpus-per-node=1
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --output=logs/gpu-smoke-%j.out
#SBATCH --error=logs/gpu-smoke-%j.err

set -euo pipefail

echo "Job ID: ${SLURM_JOB_ID:?SLURM_JOB_ID is not set}"
echo "Node: $(hostname)"
echo "CUDA_VISIBLE_DEVICES: ${CUDA_VISIBLE_DEVICES:-not set}"

command -v nvidia-smi >/dev/null 2>&1 || {
    echo "ERROR: nvidia-smi is not available on the allocated node." >&2
    exit 1
}

echo "Allocated GPU(s):"
nvidia-smi -L

echo "GPU status:"
nvidia-smi \
    --query-gpu=index,name,uuid,driver_version,memory.total \
    --format=csv,noheader

echo "GPU smoke test completed successfully."

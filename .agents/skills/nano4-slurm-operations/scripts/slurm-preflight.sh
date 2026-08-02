#!/usr/bin/env bash
set -euo pipefail

project=""
partition=""

usage() {
    cat <<'USAGE'
Usage:
  slurm-preflight.sh [--project PROJECT_ID] [--partition PARTITION]

Performs read-only Nano4 checks. With no arguments, lists active wallet projects
and current Slurm partitions.

Examples:
  slurm-preflight.sh
  slurm-preflight.sh --project GOV115071
  slurm-preflight.sh --partition dev
  slurm-preflight.sh --project GOV115071 --partition dev

This script never submits, modifies, or cancels a job.
USAGE
}

while (($# > 0)); do
    case "$1" in
        --project)
            if [[ $# -lt 2 || -z "$2" ]]; then
                echo "錯誤：--project 缺少值" >&2
                exit 2
            fi
            project="$2"
            shift 2
            ;;
        --partition)
            if [[ $# -lt 2 || -z "$2" ]]; then
                echo "錯誤：--partition 缺少值" >&2
                exit 2
            fi
            partition="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "錯誤：未知參數：$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

for command_name in hostname wallet scontrol sinfo sacctmgr awk grep tr; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "錯誤：找不到必要指令：$command_name" >&2
        exit 2
    fi
done

host_name="$(hostname -s)"
if [[ ! "$host_name" =~ ^25a-lgn[0-9]+$ ]]; then
    echo "錯誤：目前主機不是 Nano4 login node：$host_name" >&2
    exit 2
fi

cluster_name="$(
    scontrol show config |
        awk -F= '
            $1 ~ /^[[:space:]]*ClusterName[[:space:]]*$/ {
                value = $2
                gsub(/[[:space:]]/, "", value)
                cluster = value
            }
            END {
                print cluster
            }
        '
)"

if [[ "$cluster_name" != "hpc" ]]; then
    echo "錯誤：非預期 Slurm cluster：${cluster_name:-unknown}" >&2
    exit 2
fi

echo "Nano4 host: $host_name"
echo "Slurm cluster: $cluster_name"

project_lower="${project,,}"

list_contains_account() {
    local account_list="${1,,}"
    local target_account="${2,,}"

    account_list="${account_list//[[:space:]]/}"

    [[ "$account_list" == "all" ||
       ",$account_list," == *",$target_account,"* ]]
}

partition_field() {
    local record="$1"
    local requested_key="$2"

    tr ' ' '\n' <<<"$record" |
        awk -v key="$requested_key" '
            index($0, key "=") == 1 && !found {
                value = substr($0, length(key) + 2)
                found = 1
            }
            END {
                print value
            }
        '
}

check_project() {
    local wallet_status=0
    local wallet_output=""
    local association=""

    echo
    echo "Project check: $project"

    wallet_output="$(wallet "$project" 2>&1)" || wallet_status=$?

    if ((wallet_status != 0)); then
        printf '%s\n' "$wallet_output" >&2
        echo "錯誤：wallet 無法確認有效計畫或目前使用者不是計畫成員：$project" >&2
        return 1
    fi

    if ! grep -Fqi "PROJECT_ID: ${project}," <<<"$wallet_output"; then
        printf '%s\n' "$wallet_output" >&2
        echo "錯誤：wallet 輸出中找不到計畫：$project" >&2
        return 1
    fi

    printf '%s\n' "$wallet_output"

    association="$(
        sacctmgr -nP show assoc \
            user="$USER" \
            account="$project_lower" \
            format=Account,Partition,QOS,DefaultQOS
    )"

    if ! awk -F'|' -v target="$project_lower" '
        tolower($1) == target {
            found = 1
        }
        END {
            exit !found
        }
    ' <<<"$association"; then
        echo "錯誤：目前使用者的 Slurm association 找不到帳號：$project" >&2
        return 1
    fi

    echo "Slurm association: OK"

    if [[ -n "$association" ]]; then
        echo "Association details:"
        printf '%s\n' "$association"
    fi
}

check_partition() {
    local partition_record=""
    local partition_name=""
    local partition_state=""
    local allow_accounts=""
    local deny_accounts=""
    local allow_groups=""
    local max_time=""
    local qos=""
    local tres=""

    echo
    echo "Partition check: $partition"

    if ! partition_record="$(
        scontrol -o show partition "$partition" 2>&1
    )"; then
        printf '%s\n' "$partition_record" >&2
        echo "錯誤：partition 不存在或無法查詢：$partition" >&2
        return 1
    fi

    printf '%s\n' "$partition_record"

    partition_name="$(partition_field "$partition_record" "PartitionName")"
    partition_state="$(partition_field "$partition_record" "State")"
    allow_accounts="$(partition_field "$partition_record" "AllowAccounts")"
    deny_accounts="$(partition_field "$partition_record" "DenyAccounts")"
    allow_groups="$(partition_field "$partition_record" "AllowGroups")"
    max_time="$(partition_field "$partition_record" "MaxTime")"
    qos="$(partition_field "$partition_record" "QoS")"
    tres="$(partition_field "$partition_record" "TRES")"

    if [[ "$partition_name" != "$partition" ]]; then
        echo "錯誤：Slurm 回傳的 partition 名稱不符：" \
             "${partition_name:-unknown}" >&2
        return 1
    fi

    if [[ "${partition_state^^}" != "UP" ]]; then
        echo "錯誤：partition 目前不是 UP：${partition_state:-unknown}" >&2
        return 1
    fi

    if [[ -n "$project_lower" ]]; then
        if [[ -n "$allow_accounts" ]] &&
           ! list_contains_account "$allow_accounts" "$project_lower"; then
            echo "錯誤：$partition 的 AllowAccounts 不包含 $project" >&2
            return 1
        fi

        if [[ -n "$deny_accounts" ]] &&
           list_contains_account "$deny_accounts" "$project_lower"; then
            echo "錯誤：$partition 的 DenyAccounts 禁止 $project" >&2
            return 1
        fi

        echo "Project/partition policy: OK"
    else
        echo "INFO: 未提供 --project，未驗證計畫與 partition 相容性。"
    fi

    echo "Partition state: $partition_state"
    echo "Partition MaxTime: ${max_time:-unknown}"
    echo "Partition QoS: ${qos:-unknown}"
    echo "Partition AllowGroups: ${allow_groups:-unknown}"
    echo "Partition AllowAccounts: ${allow_accounts:-ALL/not explicitly restricted}"
    echo "Partition DenyAccounts: ${deny_accounts:-none}"

    if [[ "$partition" == "dev" ]]; then
        if [[ "$tres" != *"gres/gpu="* ]]; then
            echo "錯誤：dev partition 的 TRES 未顯示 GPU 資源" >&2
            return 1
        fi

        echo "GPU resources: detected in partition TRES"
        echo "INFO: dev GPU job 請使用 #SBATCH --gpus-per-node=1"
        echo "INFO: 正式 workflow 腳本不指定 CPU、RAM 或 node 數量。"
    fi
}

if [[ -n "$project" ]]; then
    check_project
else
    echo
    echo "Active wallet projects:"
    wallet
fi

if [[ -n "$partition" ]]; then
    if [[ "$project_lower" == "gov115071" && "$partition" != "dev" ]]; then
        echo
        echo "錯誤：本 repository 的 GOV115071 workflow 僅設定為 dev GPU partition" >&2
        exit 1
    fi

    check_partition
else
    echo
    echo "Current partitions:"
    sinfo -h -o '%P|%a|%l|%D|%c|%m|%G'
fi

echo
echo "Preflight completed without scheduler mutation."

#!/usr/bin/env bash

# 使脚本在任何命令执行失败时立即退出。
set -e
log_file="./blast_$(date '+%Y%m%d_%H%M%S').log"

# 打印帮助信息函数
print_help() {
    cat << EOF
Usage: 
  $0 update                            # Update the NCBI 16S database
  $0 -i <input_folder> [options]       # Run the Sanger BLAST pipeline

Pipeline Required arguments:
  -i   Input folder containing sequence files

Pipeline Optional arguments:
  -o   Output directory (default: ./blast_out)
  -d   NCBI database (default: latest set by the config file)
  -m   Sequence type: single-end or contig (default: single-end)
  -n   Number of jobs (default: 8)
  -x   File extension (default: seq)
  -h   Show this help message
EOF
    exit 1
}

# 输出信息格式
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$log_file"
}
export log_file
export -f log_info

# 无参数输入时直接打印帮助
if [ $# -eq 0 ]; then
    print_help
fi

# ==============================================================================
# SECTION 1: 配置与子命令 (Configuration & Subcommands)
# ==============================================================================

# --- 1.1 获取config文件 ---
# 获取config文件所在的绝对目录路径
PROJECT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

CONFIG_FILE="${PROJECT_DIR}/sanger_blast.config"
if [ ! -f "${CONFIG_FILE}" ]; then
    log_info "[ERROR] Can't find the config file '${CONFIG_FILE}'"
    exit 1
fi
# 将配置文件中的变量加载到当前Shell环境中
source "${CONFIG_FILE}"

# --- 1.2 处理 update 子命令 ---
if [[ "$1" == "update" ]]; then
    log_info "[INFO] Initializing NCBI database update..."
    bash "${PROJECT_DIR}/bins/update_database.sh" "$NCBI_16S_DB_DIR"
    log_info "[SUCCESS] Database update completed."
    exit 0
fi

# --- 1.3 设置管道默认值 ---
ncbi_db_dir="$(ls -d ${NCBI_16S_DB_DIR}/*_latest 2>/dev/null | head -n 1)" # 自动寻找DB中以latest结尾的文件夹
ncbi_db_file="${ncbi_db_dir}/16S_ribosomal_RNA"
seq_type="single-end"
output_dir="./blast_out"
n_jobs=8
extension="seq"

# --- 1.4 解析命令行参数 ---
while getopts "i:d:o:m:n:x:h" opt; do
    case $opt in
        i) input_dir=$OPTARG ;;
        d) ncbi_db_file=$OPTARG ;;
        o) output_dir=$OPTARG ;;
        m) seq_type=$OPTARG ;;
        n) n_jobs=$OPTARG ;;
        x) extension=$OPTARG ;;
        h) print_help ;;
        *) print_help ;;
    esac
done

# --- 1.5 检查参数是否无误 ---
# 检查必填参数
if [ -z "$input_dir" ]; then
    log_info "[ERROR] No input folder specified. Use -i option."
    exit 1
fi

# 检查 -m 参数值是否正确
if [[ "$seq_type" != "single-end" && "$seq_type" != "contig" ]]; then
    log_info "[ERROR] Invalid value for -m: $seq_type"
    log_info "        Must be 'single-end' or 'contig'"
    exit 1
fi

# 检查NCBI数据库是否存在
if [[ ! -d "$ncbi_db_dir" ]]; then
    log_info "[ERROR] NCBI database directory does not exist! Please run '$0 update' first."
    exit 1
fi

# 检查输入文件夹中给定后缀文件数量
count=$(find "$input_dir" -maxdepth 1 -type f -name "*$extension" | wc -l)

if [ "$count" -eq 0 ]; then
    log_info "[ERROR] No files with extension '$extension' found in '$input_dir'."
    exit 1
else
    log_info "[INFO] Found $count file(s) with extension '$extension' in '$input_dir'."
fi


# ==============================================================================
# SECTION 2: 主流程 (Main Pipeline)
# ==============================================================================

export BLASTDB=${ncbi_db_dir}
mkdir -p "$output_dir"

if [[ "$seq_type" == "single-end" ]]; then
    trimmed_out_dir="${input_dir}/Trimmed"
    mkdir -p "$trimmed_out_dir"

    log_info "[INFO] Running trimming step..."
    # 调用修剪脚本
    bash "${PROJECT_DIR}/bins/trim_seq.sh" "$input_dir" "$trimmed_out_dir" "$extension"

    log_info "[INFO] Running BLAST step..."
    # 调用BLAST脚本，输入是修剪后的目录
    bash "${PROJECT_DIR}/bins/run_blast.sh" "$trimmed_out_dir" "$output_dir" "$ncbi_db_file" "$n_jobs" "fasta"

elif [[ "$seq_type" == "contig" ]]; then
    log_info "[INFO] Running BLAST step..."
    # 直接调用BLAST脚本，输入是原始目录
    bash "${PROJECT_DIR}/bins/run_blast.sh" "$input_dir" "$output_dir" "$ncbi_db_file" "$n_jobs" "${extension}"
fi

log_info "[SUCCESS] All tasks completed."
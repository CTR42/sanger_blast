#!/usr/bin/env bash

# 使脚本在任何命令执行失败时立即退出。
set -e
log_file="./sanger_blast_$(date '+%Y%m%d_%H%M%S').log"

# 打印帮助信息函数
print_help() {
    cat << EOF
Usage: 
  $0 update [options]                  # Update the NCBI 16S database
  $0 -i <input_folder> [options]       # Run the Sanger BLAST pipeline

Update Optional arguments:
  -f   Path to manual tar.gz file
  -m   Path to manual md5 file
       (Note: -f and -m must be used together)

Pipeline Required arguments:
  -i   Input folder containing sequence files

Pipeline Optional arguments:
  -o   Output directory (default: ./blast_out)
  -d   NCBI database (default: latest set by the config file)
  -t   Sequence type: single-end or contig (default: single-end)
  -n   Number of jobs (default: 8)
  -x   File extension (default: seq)
  -l   Bases to trim from the left (default: 30)
  -k   Length of sequence to keep (default: 700)
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

# 检查 blastn
if [[ -z "${BLASTN_PATH}" ]]; then
    log_info "[ERROR] BLASTN_PATH is not defined in ${CONFIG_FILE}."
    exit 1
elif ! command -v "${BLASTN_PATH}" &> /dev/null; then
    log_info "[ERROR] 'blastn' not found at specified path: ${BLASTN_PATH}"
    log_info "        Please install NCBI BLAST+ or correct the path in sanger_blast.config."
    exit 1
fi

# 检查 parallel
if [[ -z "${PARALLEL_PATH}" ]]; then
    log_info "[ERROR] PARALLEL_PATH is not defined in ${CONFIG_FILE}."
    exit 1
elif ! command -v "${PARALLEL_PATH}" &> /dev/null; then
    log_info "[ERROR] 'parallel' not found at specified path: ${PARALLEL_PATH}"
    log_info "        Please install GNU Parallel or correct the path in sanger_blast.config."
    exit 1
fi

# 导出为全局环境变量，供后续的子脚本调用
export BLASTN_PATH
export PARALLEL_PATH

log_info "[INFO] Dependencies check passed. blastn: ${BLASTN_PATH}, parallel: ${PARALLEL_PATH}"

# --- 1.2 处理 update 子命令 ---
if [[ "$1" == "update" ]]; then
    shift # 将 "update" 从参数列表中移除，使得后续参数变为 $1, $2...
    
    manual_tar=""
    manual_md5=""
    
    # 局部解析 update 命令专属参数
    while getopts "f:m:h" opt; do
        case $opt in
            f) manual_tar=$OPTARG ;;
            m) manual_md5=$OPTARG ;;
            h) print_help ;;
            *) print_help ;;
        esac
    done

    # 逻辑校验：如果只输入了一个参数，报错拦截
    if [[ (-n "$manual_tar" && -z "$manual_md5") || (-z "$manual_tar" && -n "$manual_md5") ]]; then
        log_info "[ERROR] Options -f and -m must be provided together for manual update."
        exit 1
    fi
    # 如果输入两个参数，确认文本是否存在 
    if [[ -n "$manual_tar" && -n "$manual_md5" ]]; then       
        if [[ ! -f "$manual_tar" || ! -f "$manual_md5" ]]; then
            log_info "[ERROR] Manual files not found at specified paths."
            exit 1
        fi
    fi
    
    log_info "[INFO] Initializing NCBI database update..."

    # 调用底层更新脚本
    bash "${PROJECT_DIR}/bins/update_database.sh" "$NCBI_16S_DB_DIR" "$manual_tar" "$manual_md5"
    log_info "[SUCCESS] Database update completed."
    exit 0
fi

# --- 1.3 设置管道默认值 ---
ncbi_db_dir="${NCBI_16S_DB_DIR}/NCBI_16S_latest" # 自动寻找DB中以latest结尾的文件夹
ncbi_db_file="${ncbi_db_dir}/16S_ribosomal_RNA"
seq_type="single-end"
output_dir="./blast_out"
n_jobs=8
extension="seq"
left_trim=30     
keep_len=700

# --- 1.4 解析命令行参数 ---
while getopts "i:d:o:t:n:x:l:k:h" opt; do
    case $opt in
        i) input_dir=$OPTARG ;;
        d) ncbi_db_file=$OPTARG ;;
        o) output_dir=$OPTARG ;;
        t) seq_type=$OPTARG ;;
        n) n_jobs=$OPTARG ;;
        x) extension=$OPTARG ;;
        l) left_trim=$OPTARG ;;
        k) keep_len=$OPTARG ;;
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

# 检查 -t 参数值是否正确
if [[ "$seq_type" != "single-end" && "$seq_type" != "contig" ]]; then
    log_info "[ERROR] Invalid value for -t: $seq_type"
    log_info "        Must be 'single-end' or 'contig'"
    exit 1
fi

# 校验新参数：必须是纯数字
if ! [[ "$left_trim" =~ ^[0-9]+$ ]]; then
    log_info "[ERROR] Invalid value for -l: must be an integer."
    exit 1
fi
if ! [[ "$keep_len" =~ ^[0-9]+$ ]]; then
    log_info "[ERROR] Invalid value for -k: must be an integer."
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

# --- 新增：将初始化阶段的 log 文件移动到 output_dir 下 ---
new_log_file="${output_dir}/$(basename "$log_file")"
if [[ -f "$log_file" ]]; then
    mv "$log_file" "$new_log_file"
    # 更新全局日志变量，让后续的 log_info 写入新路径
    log_file="$new_log_file"
    export log_file
    log_info "[INFO] Log file dynamically moved to ${output_dir}"
fi
# --------------------------------------------------------

if [[ "$seq_type" == "single-end" ]]; then
    trimmed_out_dir="${input_dir}/Trimmed"
    mkdir -p "$trimmed_out_dir"

    log_info "[INFO] Running trimming step..."
    # 调用修剪脚本
    bash "${PROJECT_DIR}/bins/trim_seq.sh" "$input_dir" "$trimmed_out_dir" "$extension" "$left_trim" "$keep_len"

    log_info "[INFO] Running BLAST step..."
    # 调用BLAST脚本，输入是修剪后的目录
    bash "${PROJECT_DIR}/bins/run_blast.sh" "$trimmed_out_dir" "$output_dir" "$ncbi_db_file" "$n_jobs" "fasta"

elif [[ "$seq_type" == "contig" ]]; then
    log_info "[INFO] Running BLAST step..."
    # 直接调用BLAST脚本，输入是原始目录
    bash "${PROJECT_DIR}/bins/run_blast.sh" "$input_dir" "$output_dir" "$ncbi_db_file" "$n_jobs" "${extension}"
fi

DB_INFO_FILE="${ncbi_db_dir}/db_version_info.txt"

if [[ -f "${DB_INFO_FILE}" ]]; then
    log_info "[INFO] Appending database version info to log file..."
    # 打印一个分割线，使日志阅读更清晰
    echo -e "\n NCBI Database Version Info " >> "$log_file"
    cat "${DB_INFO_FILE}" >> "$log_file"
else
    log_info "[WARNING] Database version info file not found at: ${DB_INFO_FILE}"
fi

log_info "[SUCCESS] All tasks completed."


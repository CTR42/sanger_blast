#!/bin/bash
set -e

# 如果没有加载外部函数，提供一个默认的 log_info 以防报错
if ! type log_info > /dev/null 2>&1; then
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
fi

ncbi_parent_dir="$1"
manual_tar="$2"
manual_md5="$3"

# 获取当天的日期，格式为 YYYYMMDD（如 20260706）
current_date=$(date '+%Y%m%d')

if [[ -z "$ncbi_parent_dir" ]]; then
    log_info "[ERROR] Database parent directory must be provided!" >&2
    exit 1
fi

# 自动查找并设置最新的NCBI 16S数据库目录
ncbi_db_dir="${ncbi_parent_dir}/NCBI_16S_latest"
ncbi_db_file="${ncbi_db_dir}/16S_ribosomal_RNA"

# 使用固定的 tmp_update 目录，方便手动拖入文件
update_tmp_dir="${ncbi_parent_dir}/tmp_update"

mkdir -p "${update_tmp_dir}"
mkdir -p "${ncbi_parent_dir}/NCBI_16S_archived"

# --- 定义核心部署函数 (已支持手动文件检测) ---
process_and_deploy() {
    local tar_file="${update_tmp_dir}/16S_ribosomal_RNA.tar.gz"
    local md5_file="${update_tmp_dir}/16S_ribosomal_RNA.tar.gz.md5"

    # 检查数据库是否完整
    if ! (cd "${update_tmp_dir}" && md5sum -c --quiet "${md5_file}"); then
        return 1
    fi

    # 解压
    log_info "[INFO] Extracting database files..."
    tar -xf "${tar_file}" -C "${update_tmp_dir}"
    
    # 删除tar文件
    rm -f "${tar_file}"
    
    # 重命名为latest
    mkdir -p "${ncbi_db_dir}"
    mv "${update_tmp_dir}"/* "${ncbi_db_dir}/"
    rm -rf "${update_tmp_dir}"

    log_info "[SUCCESS] Database deployed to ${ncbi_db_dir}"
    return 0
}

#---如果正确传入了两个文件（离线模式）---
if [[ -n "$manual_tar" && -n "$manual_md5" ]]; then   
    log_info "[INFO] Copying manual files to ${update_tmp_dir}..."
    cp "$manual_tar" "${update_tmp_dir}/16S_ribosomal_RNA.tar.gz"
    cp "$manual_md5" "${update_tmp_dir}/16S_ribosomal_RNA.tar.gz.md5"

    if ! process_and_deploy; then
        # md5核验不通过
        log_info "[ERROR] Given file and .md5 file not matched."
        rm -rf "${update_tmp_dir}"
        exit 1
    else
        # 核验通过
        info_file="${ncbi_db_dir}/db_version_info.txt"
        echo "==========================================" > "$info_file"
        echo "Database Name : NCBI 16S ribosomal RNA" >> "$info_file"
        echo "Update Method : Offline Manual Update" >> "$info_file"
        echo "Update Time   : ${current_date}" >> "$info_file"
        echo "Storage Path  : ${ncbi_db_dir}" >> "$info_file"
        echo "==========================================" >> "$info_file"
        exit 0
    fi
fi

#---如果并未给定文件（下载模式）---
new_md5="${update_tmp_dir}/16S_ribosomal_RNA.tar.gz.md5"

log_info "[INFO] Fetching latest MD5 checksum from NCBI..."
if ! curl -sL --progress-bar -o "${new_md5}" https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz.md5; then
    log_info "[ERROR] Failed to fetch MD5 from server. Check network."
    exit 1
fi

old_md5="${ncbi_db_dir}/16S_ribosomal_RNA.tar.gz.md5"

if [[ -f "${old_md5}" ]] && cmp -s "${old_md5}" "${new_md5}"; then
##---没有更新---
    log_info "[INFO] MD5 file matches. Database is already up to date. Cleaning up..."
    rm -rf "${update_tmp_dir}"
else
    ##---有更新---
    log_info "[INFO] Update available (or initial setup). Proceeding..."

    # 如果存在旧数据库，归档
    if [[ -d "${ncbi_db_dir}" ]]; then
        arch_dir_name=$(basename "${ncbi_db_dir}" "_latest")
        # 加上秒级时间戳避免同一天多次归档冲突重名
        archive_name="${arch_dir_name}_archived_${current_date}_$(date '+%H%M%S')"
        mv "${ncbi_db_dir}" "${ncbi_parent_dir}/NCBI_16S_archived/${archive_name}"
        log_info "[INFO] Archived old database to ${archive_name}"
    fi
    ###---下载数据库---
    # 引入重试机制，最多尝试3次，避免无限死循环
    max_retries=3
    retry=0
    success=false
    # 下载数据库
    while [[ $retry -lt $max_retries ]]; do
        log_info "[INFO] Starting database download via curl... (Attempt $((retry+1))/$max_retries)"
        
        # 使用 -O 强制保存为固定文件名，防止 wget 产生 .tar.gz.1 等文件
        curl -sL --progress-bar -o "${update_tmp_dir}/16S_ribosomal_RNA.tar.gz" https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz || true

        if process_and_deploy; then
            success=true
            break
        else
            log_info "[WARNING] MD5 verification failed (Download corrupted). Retrying..."
            retry=$((retry+1))
            # 必须删除损坏的包再重试
            rm -f "${update_tmp_dir}/16S_ribosomal_RNA.tar.gz"
        fi
    done

    # 如果 3 次都失败了，报错退出
    if [[ "$success" == "false" ]]; then
        log_info "[ERROR] Failed to correctly download database after $max_retries attempts. Aborting."
        rm -rf "${update_tmp_dir}"
        exit 1
    fi
fi

# 获得版本号
log_info "[INFO] Determining database version date..."
upload_time=$(
    curl -sI https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz \
    | grep -i "Last-Modified" \
    | sed 's/^[^:]*: //' | tr -d '\r' || true
)
if [[ -n "$upload_time" ]]; then
    upload_date=$(date -d "$upload_time" +%Y%m%d)
else
    upload_date="Unknown"
fi

# 将信息输出到文件中
info_file="${ncbi_db_dir}/db_version_info.txt"
echo "==========================================" > "$info_file"
echo "Database Name : NCBI 16S ribosomal RNA" >> "$info_file"
echo "Update Method : Online Auto Update (wget)" >> "$info_file"
echo "Version Date  : ${upload_date}" >> "$info_file"
echo "Update Time   : ${current_date}" >> "$info_file"
echo "Storage Path  : ${ncbi_db_dir}" >> "$info_file"
echo "==========================================" >> "$info_file"
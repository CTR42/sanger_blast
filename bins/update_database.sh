#!/bin/bash
set -e

# 如果没有加载外部函数，提供一个默认的 log_info 以防报错
if ! type log_info > /dev/null 2>&1; then
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
fi

ncbi_parent_dir="$1"

if [[ -z "$ncbi_parent_dir" ]]; then
    log_info "[ERROR] Database parent directory must be provided!" >&2
    exit 1
fi

# 自动查找并设置最新的NCBI 16S数据库目录
ncbi_db_dir="$(ls -d "${ncbi_parent_dir}"/*_latest 2>/dev/null | head -n 1)"
ncbi_db_file="${ncbi_db_dir}/16S_ribosomal_RNA"

# 使用固定的 tmp_update 目录，方便手动拖入文件
update_tmp_dir="${ncbi_parent_dir}/tmp_update"
mkdir -p "${update_tmp_dir}"
mkdir -p "${ncbi_parent_dir}/NCBI_16S_archived"

# --- 定义核心部署函数 (已支持手动文件检测) ---
process_and_deploy() {
    local tar_file="${update_tmp_dir}/16S_ribosomal_RNA.tar.gz"
    local md5_file="${update_tmp_dir}/16S_ribosomal_RNA.tar.gz.md5"
    local need_download="true"

    # 1. 检查是否存在手动拖入的压缩包
    if [[ -f "${tar_file}" ]]; then
        log_info "[INFO] Found existing tar.gz in tmp_update. Verifying MD5..."
        # 尝试校验手动拖入的文件
        if (cd "${update_tmp_dir}" && md5sum -c --quiet "16S_ribosomal_RNA.tar.gz.md5"); then
            log_info "[INFO] Manual file MD5 check passed. Skipping download."
            need_download="false"
        else
            log_info "[WARNING] Manual file MD5 check failed (possibly incomplete). Deleting and re-downloading..."
            rm -f "${tar_file}"
        fi
    fi

    # 2. 如果没有有效的手动文件，则执行下载
    if [[ "${need_download}" == "true" ]]; then
        log_info "[INFO] Starting database download via wget..."
        wget -q --show-progress -P "${update_tmp_dir}" https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz
        
        log_info "[INFO] Verifying downloaded MD5 checksum..."
        if ! (cd "${update_tmp_dir}" && md5sum -c --quiet "16S_ribosomal_RNA.tar.gz.md5"); then
            log_info "[ERROR] Downloaded NCBI 16S database MD5 check failed!" >&2
            exit 1
        fi
        log_info "[INFO] MD5 check passed."
    fi

    # 3. 解压
    log_info "[INFO] Extracting database files..."
    tar -xf "${tar_file}" -C "${update_tmp_dir}"

    # 4. 获取版本时间 (尝试请求服务器，若断网则使用本地文件时间)
    log_info "[INFO] Determining database version date..."
    upload_time=$(
        wget --server-response --spider https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz 2>&1 \
        | grep -i "Last-Modified" \
        | sed 's/^[^:]*: //' || true
    )
    
    if [[ -n "$upload_time" ]]; then
        upload_date=$(date -d "$upload_time" +%Y%m%d)
    else
        # 离线回退机制：读取 tar.gz 文件的最后修改时间
        log_info "[WARNING] Cannot fetch date from server. Using local file modification date."
        upload_date=$(date -r "${tar_file}" +%Y%m%d)
    fi
    
    # 5. 重命名为最终目录
    final_dir_name="${ncbi_parent_dir}/NCBI_16S_v${upload_date}_latest"
    # 清理掉不再需要的压缩包和 md5，保持最终目录纯净
    rm -f "${tar_file}" "${md5_file}"
    mv "${update_tmp_dir}" "${final_dir_name}"
    
    log_info "[SUCCESS] Database deployed to ${final_dir_name}"
}


# ==========================================
# --- 主逻辑检查 ---
# ==========================================

new_md5="${update_tmp_dir}/16S_ribosomal_RNA.tar.gz.md5"

# 优先检查本地是否已经手动放入了 md5，如果没有，尝试从网络获取最新 md5 进行比对
if [[ ! -f "${new_md5}" ]]; then
    log_info "[INFO] Fetching latest MD5 checksum from NCBI..."
    # 使用 || true 防止断网时触发 set -e 导致脚本直接退出
    wget -q --show-progress -O "${new_md5}" https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz.md5 || true
fi

# 如果既没手动放，又连不上网下载，则阻断程序
if [[ ! -f "${new_md5}" ]]; then
    log_info "[ERROR] Cannot find or download MD5 file. Please check network or put the .md5 file in tmp_update manually." >&2
    exit 1
fi


if [[ -z "$ncbi_db_dir" ]]; then
    log_info "[INFO] No *_latest directory found. Performing initial setup."
    process_and_deploy
else
    log_info "[INFO] Found existing database: ${ncbi_db_dir}"
    
    # 如果 MD5 一致，说明当前库已经是最新，或者你拖进来的文件和现有库版本一样
    if cmp -s "${ncbi_db_dir}/16S_ribosomal_RNA.tar.gz.md5" "${new_md5}"; then
        log_info "[INFO] MD5 file matches. Database is already up to date. Cleaning up..."
        rm -rf "${update_tmp_dir}"
    else
        log_info "[INFO] MD5 mismatch. Update available or new manual file detected. Proceeding..."
        
        # 归档旧数据库
        arch_dir_name=$(basename "${ncbi_db_dir}" "_latest")
        mv "${ncbi_db_dir}" "${ncbi_parent_dir}/NCBI_16S_archived/${arch_dir_name}"
        log_info "[INFO] Archived old database to ${arch_dir_name}"
        
        # 此时不要删 new_md5，因为后续校验需要用到它
        process_and_deploy
    fi
fi
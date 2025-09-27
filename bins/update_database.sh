#!/bin/bash
set -e

ncbi_parent_dir="$1"
# --- 1. 设置变量和初始目录 ---

# 自动查找并设置最新的NCBI 16S数据库目录。
ncbi_db_dir="$(ls -d ${ncbi_parent_dir}/*_latest 2>/dev/null | head -n 1)"

# 基于上面找到的目录，构建数据库文件的完整路径。
ncbi_db_file="${ncbi_db_dir}/16S_ribosomal_RNA"

# 创建一个临时目录用于下载文件，以及一个归档目录用于存放旧版本的数据库。
mkdir -p ${ncbi_parent_dir}/tmp
mkdir -p ${ncbi_parent_dir}/NCBI_16S_archived

# --- 2. 下载最新的MD5校验文件 ---

# 从NCBI的FTP服务器下载最新的MD5校验文件到临时目录。
wget -P ${ncbi_parent_dir}/tmp https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz.md5

# 将新下载的MD5文件的完整路径存储在一个变量中，方便后续使用。
new_md5="${ncbi_parent_dir}/tmp/16S_ribosomal_RNA.tar.gz.md5"

# --- 3. 检查本地数据库是否存在并决定是否更新 ---

# 检查变量 `ncbi_db_dir` 是否为空。
# 如果为空 (`-z`)，说明在第一步中没有找到任何以 "_latest" 结尾的本地数据库目录。
if [[ -z "$ncbi_db_dir" ]]; then
    # --- 分支A: 本地没有数据库，执行首次下载 ---
    log_info "[INFO] No *_latest directory found. Start downloading..." # 假设 log_info 是一个记录日志的函数
    
    # 从NCBI的FTP服务器下载16S rRNA数据库的压缩包到临时目录。
    wget -P ${ncbi_parent_dir}/tmp https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz
    
    # 使用 `md5sum -c` 命令来检查下载的压缩包是否与官方的MD5值匹配。

    # 使用子 Shell 来执行校验
    # && 确保只有在 cd 成功后才执行 md5sum
    (cd "${ncbi_parent_dir}/tmp" && md5sum -c "16S_ribosomal_RNA.tar.gz.md5")

    # 检查上一条命令的退出码来判断校验是否成功
    if [[ ! $? -eq 0 ]]; then
        log_info "[ERROR] NCBI 16S database download failed!" >&2
        exit 1
    fi

    # 解压已验证的数据库压缩包。
    tar -xvf ${ncbi_parent_dir}/tmp/16S_ribosomal_RNA.tar.gz -C ${ncbi_parent_dir}/tmp 

    # 获取服务器上文件的最后修改时间，以便我们用日期来命名数据库版本。
    upload_time=$(
    wget --server-response --spider https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz 2>&1 \
    | grep -i "Last-Modified" \
    | sed 's/^[^:]*: //'    
    )

    # 将获取到的日期字符串（如 "Thu, 25 Sep 2025..."）转换为 "YYYYMMDD" 格式（如 "20250925"）。
    upload_date=$(date -d "$upload_time" +%Y%m%d)   

    # 将下载并解压好的临时文件夹重命名，格式为 "NCBI_16S_v[日期]_latest"。
    mv ${ncbi_parent_dir}/tmp "${ncbi_parent_dir}/NCBI_16S_v${upload_date}_latest"
       
else
    # --- 分支B: 本地已存在数据库，检查是否需要更新 ---
    log_info "[INFO] Found existing database: $ncbi_db_dir"

    # 比较本地数据库目录中的MD5文件和刚刚从服务器下载的MD5文件是否一致。
    # `cmp -s` 命令用于静默比较（-s, silent），如果文件相同则返回0，不同则返回非0。
    if cmp -s "$ncbi_db_dir/16S_ribosomal_RNA.tar.gz.md5" "${ncbi_parent_dir}/tmp/16S_ribosomal_RNA.tar.gz.md5"; then
        # 如果MD5文件一致，说明本地数据库已是最新版本，无需操作。
        log_info "[INFO] MD5 file matches. Skip downloading."
        rm -r ${ncbi_parent_dir}/tmp
    else
        # 如果MD5文件不一致，说明服务器上的数据库已更新，需要重新下载。
        log_info "[INFO] MD5 mismatch. Start re-downloading..."
        
        # 从现有数据库目录名中提取版本信息（去掉 "_latest" 后缀）。
        arch_dir_name=$(basename $ncbi_db_dir "_latest")
        
        # 将旧的数据库目录移动到归档文件夹中进行备份。
        mv $ncbi_db_dir "${ncbi_parent_dir}/NCBI_16S_archived/${arch_dir_name}"

        # --- 下载和处理新数据库（这部分逻辑与上面的分支A完全相同）---
        wget -P ${ncbi_parent_dir}/tmp https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz
    
        md5sum -c $new_md5

        tar -xvf ${ncbi_parent_dir}/tmp/16S_ribosomal_RNA.tar.gz

        upload_time=$(
        wget --server-response --spider https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz 2>&1 \
        | grep -i "Last-Modified" \
        | sed 's/^[^:]*: //'    
        )

        upload_date=$(date -d "$upload_time" +%Y%m%d)   

        mv ${ncbi_parent_dir}/tmp "${ncbi_parent_dir}/NCBI_16S_v${upload_date}_latest"
    fi
fi
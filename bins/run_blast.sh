#!/bin/bash
set -e
# $1: input_dir, $2: output_dir, $3: db_path, $4: n_jobs, $5: blast_bin_dir
input_dir="$1"
output_dir="$2"
db_path="$3"
n_jobs="$4"
blast_bin_dir="$5"
extension="$6"

# 定义一个函数，用于处理单个文件的BLAST任务
process_single_file() {
    query_file="$1" # 第一个参数是输入的文件路径
    
    # 从函数外部获取变量
    local blast_bin="$2"
    local db="$3"
    local output_dir="$4"
    local extension="$5"

    local prefix
    prefix=$(basename "$query_file" .${extension})
    
    # 定义BLAST的临时输出和最终输出文件名
    local tmp_out="${output_dir}/${prefix}.txt"
    local final_out="${output_dir}/${prefix}_blast_out.txt"

    # 执行blastn命令
    "$blast_bin/blastn" -query "$query_file" \
                 -db "$db" \
                 -out "$tmp_out" \
                 -outfmt "6 sscinames sseqid stitle bitscore score qcovs evalue pident length" \
                 -max_target_seqs 5

    # 写入表头到最终输出文件
    echo -e "Scientific Name\tAccession\tDescription\tMax Score\tTotal Score\tQuery Cover\tE value\tPer. Ident\tLen" > "$final_out"
    # 将BLAST结果追加到文件中
    cat "$tmp_out" >> "$final_out"
    
    # 删除临时文件
    rm "$tmp_out"
}

# 导出函数和变量，以便 parallel 创建的子进程可以访问到它们
export -f process_single_file

# 使用find和parallel来并行处理所有的文件
# printf "[INFO] Starting BLAST tasks in parallel...\n"
find "$input_dir" -maxdepth 1 -type f -name "*.${extension}" -print0 | \
    parallel -0 --bar -j ${n_jobs} process_single_file {} "$blast_bin_dir" "$db_path" "$output_dir" "$extension"

# --- 步骤 3: 汇总结果 ---

# 创建一个最终的汇总文件，并写入表头
echo -e "Query file\tScientific Name\tAccession\tDescription\tMax Score\tTotal Score\tQuery Cover\tE value\tPer. Ident\tLen" > ${output_dir}/summary.txt

# 遍历每个BLAST输出文件，提取顶部的比对结果并添加到汇总文件中
for file in ${output_dir}/*_blast_out.txt; do
  # 将文件名和文件的第二行（即最佳匹配结果）合并，并追加到summary.txt中
  echo -e "$(basename "$file")\t$(sed -n '2p' "$file")"
done >> ${output_dir}/summary.txt

#!/bin/bash
set -e

# $1: input_dir, $2: extension
input_dir="$1"
output_dir="$2"
extension="$3"


mkdir -p "$output_dir"
# 遍历输入文件夹中所有指定扩展名的文件
for file in "$input_dir"/*."$extension"; do
    # 确保处理的是文件而不是目录
    if [[ -f $file ]]; then
        # 定义临时文件名
        temp_file="${file}.tmp"
        merged_file="${file}.merged"

        # 获取文件名，不包含路径和扩展名
        filename=$(basename "$file" ."$extension")

        # 使用awk将多行的FASTA序列合并为单行，方便后续处理
        awk '/^>/ {if (seq) print seq; print; seq=""; next} {seq = seq (seq=="" ? $0 : ""$0)} END {if (seq) print seq}' "$file" > "$merged_file"

        # 创建一个新的、经过修剪的FASTA文件
        {
            # 1. 将原始文件名作为新的FASTA头
            echo ">${filename}"
            # 2. 从合并后的序列中，去除旧的头信息行，并截取序列的特定部分 (从第30个字符开始，截取771个字符)
            awk '!/^>/ {print substr($0, 30, 771)}' "$merged_file"
        } > "$temp_file"

        # 将处理好的临时文件移动到Trimmed目录，并重命名
        mv "$temp_file" "$output_dir/$filename"_trimmed.fasta
        
        # 清理中间文件
        rm "$merged_file"
#       rm $file # 如果需要，可以取消此行注释以删除原始文件
    fi
done
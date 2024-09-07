#!/bin/bash

# 输入文件名
input_file="zubo_fofa.txt"
# 输出文件名
output_file="zubo_fofa.m3u"

# 初始化组名变量
group_title=""
logo_url_base="https://live.fanmingming.com/tv/" # 基础的 logo URL

# 删除旧的输出文件
> "$output_file"

# 读取输入文件行
while IFS= read -r line; do
    # 检查是否为组名行
    if [[ $line == *#genre# ]]; then
        # 去掉#genre#符号并提取组名
        group_title=$(echo "$line" | sed 's/,#genre#//')
    elif [[ $line == *,http* ]]; then
        # 如果这一行是频道信息和URL的组合行
        # 提取频道名称 (逗号前部分)
        channel_name=$(echo "$line" | cut -d',' -f1)
        # 提取URL (逗号后部分)
        stream_url=$(echo "$line" | cut -d',' -f2)
        # 提取频道ID (去掉空格和"-"作为ID)
        tvg_id=$(echo "$channel_name" | sed 's/ //g' | sed 's/-//g')
        # 构建logo URL
        logo_url="${logo_url_base}${tvg_id}.png"

        # 写入EXTINF和URL到输出文件
        echo "#EXTINF:-1 tvg-id=\"$tvg_id\" tvg-name=\"$tvg_id\" tvg-logo=\"$logo_url\" group-title=\"$group_title\",$channel_name" >> "$output_file"
        echo "$stream_url" >> "$output_file"
    fi
done < "$input_file"

echo "转换完成，结果已保存到 $output_file"
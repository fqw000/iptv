#!/bin/bash

# 1. 搜索关键字，获取前5页结果
echo "==== 开始获取数据 ======"
COOKIE="cookie: HstCfa4853344=1726738065912; HstCmu4853344=1726738065912; __dtsu=1040172673806781999D77C4BF3E8490; HstCfa4835429=1726738142531; HstCmu4835429=1726738142531; _ga=GA1.1.1199855925.1726885404; HstPn4835429=1; HstCla4835429=1726902266935; HstPt4835429=8; HstCnv4835429=5; HstCns4835429=5; __gads=ID=9354f480e65414f8:T=1726885405:RT=1726902305:S=ALNI_MZoJGQaJXSfhcsokthrELBI7gUmaQ; __eoi=ID=20de57355da68d3c:T=1726885405:RT=1726902305:S=AA-AfjajJAvwNS715hQLhairET9P; HstCnv4853344=6; HstCns4853344=9; HstCla4853344=1726910199992; HstPn4853344=9; HstPt4853344=165; ckip1=183.15.206.240%7C61.53.87.230%7C123.101.157.82%7C112.114.137.112%7C112.114.137.87%7C222.137.229.152%7C1732e975z9.zicp.fun%7C110.7.131.51; ckip2=124.64.189.63%7C171.120.110.65%7C116.23.139.108%7C180.116.217.147%7C123.145.67.77%7C116.226.74.224%7Cwouu.net%7C47.94.21.78; REFERER=Gameover; _ga_JNMLRB3QLF=GS1.1.1726991779.5.0.1726991783.0.0.0"
CHANNEL_NAME="台湾"
CHANNEL_KEY_URL="%E5%8F%B0%E6%B9%BE"
RESPONSE_FILE="response.txt"
SEARCH_RESULTS_FILE="searchresults.txt"
UNIQUE_SEARCH_RESULTS_FILE="unique_searchresults.txt"
SPEED_TEST_LOG="speedtest.log"
BEST_URL_RESPONSE_FILE="besturlresponse.txt"
OUTPUT_FILE="taiwan_tonkiang.txt"

# 清空或创建响应文件
:> ${RESPONSE_FILE}
:> ${SPEED_TEST_LOG}
:> ${UNIQUE_SEARCH_RESULTS_FILE}

# 获取数据
for page in {1..5}; do
    curl -X GET "http://tonkiang.us/?page=${page}&iqtv=${CHANNEL_KEY_URL}" -H "${COOKIE}" >> "$RESPONSE_FILE"
done

# 2. 提取源地址，并进行整理
grep -o '[^"]https://[^<]*' "$RESPONSE_FILE" > "$SEARCH_RESULTS_FILE"
sed -i 's/^[ \t]*//' "$SEARCH_RESULTS_FILE"
sort "$SEARCH_RESULTS_FILE" | uniq > tmp && mv tmp "$SEARCH_RESULTS_FILE"


# 3. 测速提取速度最好的源地址
:> "$UNIQUE_SEARCH_RESULTS_FILE"
awk -F/ '{print $3}' "$SEARCH_RESULTS_FILE" | sort -u | while read -r domain; do
    grep "$domain" "$SEARCH_RESULTS_FILE" | head -n 1 >> "$UNIQUE_SEARCH_RESULTS_FILE"
done

echo "==== 整理数据完成, 开始测速 ======"
lines=$(wc -l < "$UNIQUE_SEARCH_RESULTS_FILE")
    i=0
while read -r url; do
               i=$((i + 1))
          output=$(timeout 40 /usr/bin/yt-dlp --ignore-config --no-cache-dir --output "output.ts" --download-archive new-archive.txt --external-downloader ffmpeg --external-downloader-args "ffmpeg_i:-t 5" "${url}" 2>&1)
            if echo "${output}" | grep -q "ERROR"; then
                echo "下载失败：${url}"
                echo "下载失败：${url}" >> "$SPEED_TEST_LOG"
                continue
            fi

            speed=$(echo "${output}" | grep -oP "speed=\K[0-9]+\.[0-9]+x\s+$" | sed 's/x//')
        speedinfo=$(echo "${output}" | grep -E "speed=[0-9]+\.[0-9]+x\s+$")

        # echo "${output}" >> output.txt
        rm -f new-archive.txt output.ts

    printf "第 %d/%d 个：%s\n[speedinfo]%s\n" "$i" "$lines" "$url" "$speedinfo"

    echo "${speed} ${url}">> "$SPEED_TEST_LOG"
done < "$UNIQUE_SEARCH_RESULTS_FILE"

sort -u -r "$SPEED_TEST_LOG" | grep -E 'in [0-9]{1,2}:[0-9]{1,2}' | awk '{print $3 " " $1}' | sort -n -r > validurl.txt
besturl=$(head -n 1 validurl.txt | sed -n 's|.*//\([^/]*\)/.*|\1|p')
echo "========== bestdomain : ${besturl}"

# 4. 获取 besturl 对应的直播源列表
:> "$BEST_URL_RESPONSE_FILE"
curl -X GET "http://tonkiang.us/?page=1&iqtv=${besturl}" -H "${COOKIE}" > "$BEST_URL_RESPONSE_FILE"
max_page=$(grep -oP 'page=\K\d+' "$BEST_URL_RESPONSE_FILE" | sort -nr | head -n1)
echo "最大 page 值是: ${max_page}"
for page in $(seq 2 "$max_page"); do
    curl -X GET "http://tonkiang.us/?page=${page}&iqtv=${besturl}" -H "${COOKIE}" >> "$BEST_URL_RESPONSE_FILE"
done

# 清空或创建输出文件
:> "$OUTPUT_FILE"
# 使用 grep 和 awk 提取 <div class="tip"> 标签中的频道名称和 m3u8 链接
grep -Eo '<div class="tip"[^>]*>[^<]*</div>|https?://[^"]+\.m3u8' "$BEST_URL_RESPONSE_FILE" | while read -r line; do
    if [[ $line == "<div class=\"tip\""* ]]; then
        # channel=$(echo "$line" | sed -E 's/<div class="tip"[^>]*>([^<]*)<\/div>/\1/' | xargs)
          channel=$(echo "$line" | sed -E 's|<div class="tip"[^>]*>([^<]*)</div>|\1|' | xargs)
    elif [[ $line == "http"* ]]; then
        m3u8_url=$(echo "$line" | xargs)
        echo "$channel, $m3u8_url" >> "$OUTPUT_FILE"
    fi
done

sort -u "$OUTPUT_FILE" > tmp && mv tmp "$OUTPUT_FILE"
sed -i "1i ${CHANNEL_NAME},#genre#" "$OUTPUT_FILE"
echo " $OUTPUT_FILE 已经更新完成"

# ram validurl.txt
# rm ${RESPONSE_FILE} ${SEARCH_RESULTS_FILE} ${UNIQUE_SEARCH_RESULTS_FILE} ${SPEED_TEST_LOG} ${BEST_URL_RESPONSE_FILE}

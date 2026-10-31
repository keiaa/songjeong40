#!/usr/bin/env bash

# 에러 발생 시 즉시 중단
set -e

# 현재 디렉토리의 JPG 파일 목록 수집 (대소문자 구분 없이 *.JPG, *.jpg 포함 및 자연 정렬)
files=()
while IFS= read -r file; do
    [ -n "$file" ] && files+=("$file")
done < <(find . -maxdepth 1 -type f \( -name "*.JPG" -o -name "*.jpg" \) -exec basename {} \; | sort -V)

total=${#files[@]}

if [ "$total" -eq 0 ]; then
    echo "변경할 JPG 파일이 없습니다."
    exit 0
fi

echo "총 ${total}개의 파일을 1.JPG ~ ${total}.JPG 형식으로 이름을 변경합니다."

# 1단계: 임시 파일명으로 변경 (기존 파일명과 충돌 및 덮어쓰기 방지)
echo "1단계: 임시 파일명으로 변경 중..."
tmp_prefix="__tmp_rename_${RANDOM}_"
index=1
for file in "${files[@]}"; do
    tmp_name="${tmp_prefix}${index}.JPG"
    mv "$file" "$tmp_name"
    index=$((index + 1))
done

# 2단계: 최종 번호 파일명(1.JPG, 2.JPG...)으로 변경
echo "2단계: 최종 번호 파일명으로 변경 중..."
for (( i=1; i<=total; i++ )); do
    tmp_name="${tmp_prefix}${i}.JPG"
    final_name="${i}.JPG"
    mv "$tmp_name" "$final_name"
done

echo "=== 이름 변경 완료! (1.JPG ~ ${total}.JPG) ==="

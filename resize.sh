#!/usr/bin/env bash

# 에러 발생 시 중단 설정
set -e

# resize 디렉토리 생성
OUTPUT_DIR="resize"
mkdir -p "$OUTPUT_DIR"

echo "이미지 리사이즈를 시작합니다..."

# *.JPG 파일 순회
for f in *.JPG; do
    # 매칭되는 파일이 없는 경우 건너뛰기
    [ -f "$f" ] || continue

    echo "변환 중: $f -> $OUTPUT_DIR/$f"
    magick "$f" \
        -auto-orient \
        -resize '1920x>' \
        -strip \
        -quality 80 \
        "$OUTPUT_DIR/$f"
done

echo "모든 작업이 완료되었습니다."

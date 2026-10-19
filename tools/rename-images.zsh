#!/bin/zsh

emulate -LR zsh
setopt NO_UNSET

usage() {
    print -r -- '사용법: zsh rename-images.zsh [--dry-run] "이미지 폴더 경로"'
    print -r -- 'JPG, JPEG, PNG, GIF 파일을 현재 이름의 자연 정렬 순서로 1, 2, 3…으로 변경합니다.'
    print -r -- '확장자는 유지하며 하위 폴더와 숨김 파일, 심볼릭 링크는 처리하지 않습니다.'
}

previewOnly=0
if [[ "${1:-}" == '--help' || "${1:-}" == '-h' ]]; then
    usage
    exit 0
fi
if [[ "${1:-}" == '--dry-run' ]]; then
    previewOnly=1
    shift
fi
if (( $# != 1 )) || [[ ! -d "$1" ]]; then
    usage >&2
    exit 1
fi

targetDir=${1:A}
typeset -a imageFiles finalPaths stagedPaths
imageFiles=()
for filePath in "$targetDir"/*(N.); do
    case "${filePath:e:l}" in
        jpg|jpeg|png|gif) imageFiles+=("$filePath") ;;
    esac
done
# 숫자가 포함된 이름은 사진2, 사진10 순으로 정렬한다.
imageFiles=("${(@on)imageFiles}")
if (( ${#imageFiles} == 0 )); then
    print -r -- '변경할 이미지가 없습니다.'
    exit 0
fi

for (( index=1; index<=${#imageFiles}; index++ )); do
    filePath=${imageFiles[index]}
    finalPath="$targetDir/$index.${filePath:e}"
    if [[ -e "$finalPath" || -L "$finalPath" ]]; then
        if (( ${imageFiles[(Ie)$finalPath]} == 0 )); then
            print -r -- "동일한 이름의 다른 항목이 있어 중단합니다: $finalPath" >&2
            exit 1
        fi
    fi
    finalPaths+=("$finalPath")
    printf '%q -> %q\n' "${filePath:t}" "${finalPath:t}"
done
if (( previewOnly )); then
    print -r -- "미리보기 완료: ${#imageFiles}개 (파일 변경 없음)"
    exit 0
fi

# 같은 폴더 안에서 임시 이름으로 먼저 이동해 이름 충돌을 방지한다.
stagingDir=$(/usr/bin/mktemp -d "$targetDir/.image-renamer.XXXXXXXX") || exit 1
phase='staging'
for (( index=1; index<=${#imageFiles}; index++ )); do
    stagedPaths+=("$stagingDir/$index")
done

moveSafely() {
    local sourcePath="$1" destinationPath="$2"
    if [[ -e "$destinationPath" || -L "$destinationPath" ]]; then
        return 1
    fi
    /bin/mv -n "$sourcePath" "$destinationPath" || return 1
    [[ ! -e "$sourcePath" && ! -L "$sourcePath" ]]
}

rollback() {
    local index rollbackFailed=0
    trap - EXIT INT TERM HUP
    if [[ "$phase" == 'finishing' ]]; then
        for (( index=1; index<=${#imageFiles}; index++ )); do
            if [[ ! -e "${stagedPaths[index]}" ]]; then
                moveSafely "${finalPaths[index]}" "${stagedPaths[index]}" || rollbackFailed=1
            fi
        done
    fi
    for (( index=1; index<=${#imageFiles}; index++ )); do
        if [[ -e "${stagedPaths[index]}" ]]; then
            moveSafely "${stagedPaths[index]}" "${imageFiles[index]}" || rollbackFailed=1
        fi
    done
    if (( rollbackFailed )); then
        print -r -- "일부 복구에 실패했습니다. 남은 파일을 확인하세요: $stagingDir" >&2
    else
        /bin/rmdir "$stagingDir"
        print -r -- '작업이 중단되어 원래 이름으로 복구했습니다.' >&2
    fi
}
trap rollback EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

for (( index=1; index<=${#imageFiles}; index++ )); do
    moveSafely "${imageFiles[index]}" "${stagedPaths[index]}" || exit 1
done
phase='finishing'
for (( index=1; index<=${#imageFiles}; index++ )); do
    moveSafely "${stagedPaths[index]}" "${finalPaths[index]}" || exit 1
done
trap - EXIT INT TERM HUP
/bin/rmdir "$stagingDir"
print -r -- "완료: ${#imageFiles}개 이미지의 이름을 변경했습니다."

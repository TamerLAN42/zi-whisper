#!/bin/sh
set -e

PROMPT="${PROMPT:-Лекция. Русский текст с пунктуацией.}"
LANGUAGE="${LANGUAGE:-ru}"
VAD_FILTER="${VAD_FILTER:-true}"
WORD_TIMESTAMPS="${WORD_TIMESTAMPS:-false}"
OUTPUT="${OUTPUT:-txt}"
STARTUP_HEALTHCHECK_INTERVAL="${STARTUP_HEALTHCHECK_INTERVAL:-3}"
ARCHIVE_KEEP_FILES="${ARCHIVE_KEEP_FILES:-10}"

until curl -s -o /dev/null -w '%{http_code}' http://whisper:9000/docs | grep -q '^200$'; do
    sleep "$STARTUP_HEALTHCHECK_INTERVAL"
done

for f in /input/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    base="${name%.*}"
    echo "Начинаем обработку >> $name"
    if curl -s -f -X POST "http://whisper:9000/asr" \
    -F "encode=true" \
    -F "task=transcribe" \
    -F "language=$LANGUAGE" \
    -F "initial_prompt=$PROMPT" \
    -F "vad_filter=$VAD_FILTER" \
    -F "word_timestamps=$WORD_TIMESTAMPS" \
    -F "output=$OUTPUT" \
    -F "audio_file=@$f" -o "/output/$base.$OUTPUT"; then
           if [ -s "/output/$base.$OUTPUT" ]; then
				echo "С $f закончили, переношу исходники в архив"
				mv "$f" "/archive/$name"
				echo "Удаляем старые аудиозаписи в архиве, оставляем $ARCHIVE_KEEP_FILES самых свежих"
				if [ -n "$(find /archive -maxdepth 1 -type f -print -quit)" ]; then
					ls -t /archive/* | tail -n +$((ARCHIVE_KEEP_FILES + 1)) | while IFS= read -r old; do rm -f "$old"; done
				fi
			else
				echo "Выходной файл пуст или не существует, сбой транскрипции, ухожу плакать. Исходный файл: $name"
				rm -f "/output/$base.$OUTPUT"
			fi
	else
		echo "Ошибка при обработке файла $f, curl упал с ошибкой"
		rm -f "/output/$base.$OUTPUT"
	fi
done
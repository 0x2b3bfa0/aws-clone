#!/bin/bash
baseurl="https://bucketname.s3.amazonaws.com"
next_continuation_token=""
default_get="?list-type=2"

urlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"
}

mkdir indexes &>/dev/null

for ((counter=1;;counter++)); do
  if [[ "$next_continuation_token" != "" ]]; then
    get="$default_get&continuation-token=$(urlencode "$next_continuation_token")"
  else
    get="$default_get"
  fi

  result="$(curl -m 15 "$baseurl/$get")"
  while [[ $? != 0 ]]; do
    result="$(curl -m 15 "$baseurl/$get")"
  done

  next_continuation_token="$(grep -Eo '<NextContinuationToken>.*</NextContinuationToken>' <<< "$result" | sed 's#<NextContinuationToken>\(.*\)</NextContinuationToken>#\1#')"

  cat <<< "$result" > indexes/$((counter++)).xml

  if [[ "$next_continuation_token" == "" ]]; then
    break
  fi
done

mkdir files &>/dev/null

for index in indexes/*.xml; do
  xmllint --format "$index" | grep '<Key>.*</Key>' | grep -v 'log' | sed 's#^\s*<Key>\(.*\)</Key>.*#\1#' | while read url; do
    wget -cP files "$baseurl/$url"
  done
done

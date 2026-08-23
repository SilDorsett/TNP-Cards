#!/bin/bash

card_id=$1
season_id=$2

get_card_name() {
  # Clear the output file if it exist
  local TEMP_FILE="/tmp/card_info.xml"
  cat /dev/null > "$TEMP_FILE"

  url="https://www.nationstates.net/cgi-bin/api.cgi"
  curl_data="q=card+info;cardid=${card_id};season=${season_id}"
  response=$(curl -A "Sil Dorsett" "$url" --data "$curl_data" --http1.1)
  echo $response | xmllint --format - > ${TEMP_FILE}

  # Extract the Card Name
  card_name=$(awk -F'[<>]' '/<NAME>/ {print $3}' $TEMP_FILE)

  echo "Card Name: ${card_name}"
}

get_card_name

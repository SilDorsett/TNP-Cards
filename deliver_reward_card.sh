#!/bin/bash

#################
### Variables ###
#################

script_home=${HOME}/cards
data_home=${HOME}/.data/dpsystem

deck_file="$script_home/tnl_full_deck.xml"
legendaries_file="$script_home/tnl_legendaries.txt"

x_autologin=$(cat ${data_home}/the_northern_light.cred.dat)
user_agent=$(cat ${data_home}/useragent.dat)

# Normalize the target nation argument (lowercase, spaces -> underscores)
target_nation=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')



#################
### FUNCTIONS ###
#################

usage() {
  echo "Usage: $0 <target_nation>"
  echo "Example: $0 testlandia"
  exit 1
}



download_deck() {

  cat /dev/null > "$legendaries_file"

  url="https://www.nationstates.net/cgi-bin/api.cgi"
  curl_data="q=cards+deck;nationname=the_northern_light"
  response=$(curl -A "$user_agent" "$url" --data "$curl_data" --http1.1)
  echo $response | xmllint --format - > $deck_file

  xmlstarlet sel -t \
    -m "//CARD[CATEGORY='legendary']" \
    -v "concat(CARDID, '|', CATEGORY, '|', SEASON)" \
    -n "$deck_file" | while read -r line; do
      echo "${line}" >> "$legendaries_file"
    done

  echo "Parsing complete. Output saved to $legendaries_file."

}



select_random_card() {

  if [[ ! -s "$legendaries_file" ]]; then
    echo "Error: Deck file is either missing or empty."
    exit 1
  fi

  total_lines=$(wc -l < "$legendaries_file")
  random_line=$((RANDOM % total_lines + 1))
  selected_line_text=$(sed -n "${random_line}p" "$legendaries_file")

  card_id=$(echo "$selected_line_text" | cut -d"|" -f1)
  season_id=$(echo "$selected_line_text" | cut -d"|" -f3)

}



get_card_name() {

  local temp_file="/tmp/card_info.xml"
  cat /dev/null > "$temp_file"

  url="https://www.nationstates.net/cgi-bin/api.cgi"
  curl_data="q=card+info;cardid=${card_id};season=${season_id}"
  response=$(curl -A "$user_agent" "$url" --data "$curl_data" --http1.1)
  echo $response | xmllint --format - > ${temp_file}

  card_name=$(awk -F'[<>]' '/<NAME>/ {print $3}' $temp_file)

  echo "Card Name: $card_name"
#  rm $temp_file

}



print_debug_info() {

  echo "Lines in File: $total_lines"
  echo "Randomly selected line: Line $random_line"
  echo "Contents of Line $random_line: $selected_line_text"
  echo "Card ID = $card_id"
  echo "Season = $season_id"
  echo "Name of Card = $card_name"
  echo "----------------------------------------"
  echo "Target Nation: $target_nation"

}



deliver_card() {

  url="https://www.nationstates.net/cgi-bin/api.cgi"
  curl_data="nation=the_northern_light"
  curl_data="${curl_data}&c=giftcard"
  curl_data="${curl_data}&cardid=${card_id}"
  curl_data="${curl_data}&season=${season_id}"
  curl_data="${curl_data}&to=${target_nation}"

  curl_prepare="${curl_data}&mode=prepare"

  response_prepare=$(curl -i -H "X-Autologin: $x_autologin" -A "$user_agent" "$url" --data "$curl_prepare" --http1.1)

  echo "$response_prepare"

  token=$(echo $response_prepare | grep -o '<SUCCESS>.*</SUCCESS>' | sed -e 's/<SUCCESS>//;s/<\/SUCCESS>//')
  x_pin=$(echo "$response_prepare" | awk 'BEGIN {IGNORECASE=1} /^x-pin:/ {print $2}')

  echo "token: $token"
  echo "x-pin: $x_pin"

  if [ -z $token ]; then
          echo "[ERROR] Token not received." ; exit 1
  else
          sleep 2
          curl_execute="${curl_data}&mode=execute&token=$token"
          response_execute=$(curl -H "X-Pin: $x_pin" -A "$user_agent" "$url" --data "$curl_execute" --http1.1)
          echo "$curl_execute"
          echo "$response_execute"
  fi

}



####################
### MAIN ROUTINE ###
####################

if [ -z "$1" ]; then
   usage
fi

if [ -z "$x_autologin" ]; then
   echo "Error: No credentials file the_northern_light.cred.dat found."
   exit 1
fi

download_deck
select_random_card
get_card_name
print_debug_info
deliver_card

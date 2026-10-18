#!/bin/bash

#################
### Variables ###
#################

script_home=${HOME}/cards
data_home=${HOME}/.data/dpsystem

today=$(date +%Y%m%d)
today_dash=$(date +"%Y-%m-%d")
yesterday=$(date -d "Yesterday" +%Y%m%d)

deck_file="$script_home/tnl_full_deck.xml"
legendaries_file="$script_home/tnl_legendaries.txt"

eligible_nations_file="/mnt/nationstates/keepers/keepers_of_the_north.$today.txt"
eligible_nations_file_backup="/mnt/nationstates/keepers/keepers_of_the_north.$yesterday.txt"

excluded_nations_file="/mnt/nationstates/securitycouncil/securitycouncil.$today.txt"
excluded_nations_file_backup="/mnt/nationstates/securitycouncil/securitycouncil.$yesterday.txt"

x_autologin=$(cat ${data_home}/the_northern_light.cred.dat)
user_agent=$(cat ${data_home}/useragent.dat)



#################
### FUNCTIONS ###
#################

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



run_lottery() {

  if [[ ! -s "$legendaries_file" ]]; then
    echo "Error: Deck file is either missing or empty."
    exit 1
  fi

  total_lines=$(wc -l < "$legendaries_file")
  random_line=$((RANDOM % total_lines + 1))
  selected_line_text=$(sed -n "${random_line}p" "$legendaries_file")
  
  card_id=$(echo "$selected_line_text" | cut -d"|" -f1)
  season_id=$(echo "$selected_line_text" | cut -d"|" -f3)


  eligible_nations_filtered=$(mktemp)
 
  if [[ -f "$excluded_nations_file" ]]; then
    grep -vxFf "$excluded_nations_file" "$eligible_nations_file" > "$eligible_nations_filtered"
  else
    echo "Warning: No exclusion list found at $excluded_nations_file (or backup). Proceeding without exclusions."
    cat "$eligible_nations_file" > "$eligible_nations_filtered"
  fi
 
  total_eligible_count=$(wc -l < "$eligible_nations_filtered")
 
  if [[ "$total_eligible_count" -eq 0 ]]; then
    echo "Error: No eligible nations remain after applying exclusions."
    rm -f "$eligible_nations_filtered"
    exit 1
  fi

#  total_eligible_count=$(wc -l < "$eligible_nations_file")
#  random_eligible_line=$((RANDOM % total_eligible_count + 1))
#  random_eligible_name=$(sed -n "${random_eligible_line}p" "$eligible_nations_file")

random_eligible_line=$((RANDOM % total_eligible_count + 1))
  random_eligible_name=$(sed -n "${random_eligible_line}p" "$eligible_nations_filtered")
}



get_card_name() {

  local temp_file="/tmp/card_info.xml"
  cat /dev/null > "$temp_file"

  url="https://www.nationstates.net/cgi-bin/api.cgi"
  curl_data="q=card+info;cardid=${card_id};season=${season_id}"
  response=$(curl -A "$user_agent" "$url" --data "$curl_data" --http1.1)
  echo $response | xmllint --format - > ${temp_file}

  # Extract the Card Name
  card_name=$(awk -F'[<>]' '/<NAME>/ {print $3}' $temp_file)

  echo "Card Name: $card_name"
  rm $temp_file

}



print_debug_info() {
 
  echo "Lines in File: $total_lines"
  echo "Randomly selected line: Line $random_line"
  echo "Contents of Line $random_line: $selected_line_text"
  echo "Card ID = $card_id"
  echo "Season = $season_id"
  echo "Name of Card = $card_name"
  echo "----------------------------------------"
  echo "Exclusion List Used: $excluded_nations_file"
  echo "Total Eligible (after exclusions): $total_eligible_count"
  echo "Selected Eligible Line: $random_eligible_line"
  echo "Selected Eligible Name: $random_eligible_name"
}


deliver_card() {

  url="https://www.nationstates.net/cgi-bin/api.cgi"
  curl_data="nation=the_northern_light"
  curl_data="${curl_data}&c=giftcard"
  curl_data="${curl_data}&cardid=${card_id}"
  curl_data="${curl_data}&season=${season_id}"
  curl_data="${curl_data}&to=${random_eligible_name}"

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



make_rmb_post() {

  sed -e "s/@@DATE@@/$today_dash/" \
      -e "s/@@WINNER@@/$random_eligible_name/" \
      -e "s/@@SEASON@@/$season_id/g" \
      -e "s/@@CARD_ID@@/$card_id/" \
      -e "s/@@CARD_NAME@@/$card_name/" $script_home/rmb_post_template.txt > $script_home/rmbposts/rmb_post_$today.txt

  rmb_post=$(cat $script_home/rmbposts/rmb_post_$today.txt)
  rmb_post_text=$(echo -n "$rmb_post" | jq -s -R -r @uri)

  ### SEND CARD ###
  url="https://www.nationstates.net/cgi-bin/api.cgi"
  curl_data="nation=the_northern_light"
  curl_data="${curl_data}&region=the_north_pacific"
  curl_data="${curl_data}&c=rmbpost"
  curl_data="${curl_data}&text=${rmb_post_text}"
  
  curl_prepare="${curl_data}&mode=prepare"

  echo "curl_prepare = ${curl_prepare}"

  # Since this is the second request in quick succession, we will use the X-Pin instead of X-Autologin.
  response_prepare=$(curl -i -H "X-Pin: $x_pin" -A "$user_agent" "$url" --data "$curl_prepare" --http1.1)

  echo "$response_prepare"

  token=$(echo $response_prepare | grep -o '<SUCCESS>.*</SUCCESS>' | sed -e 's/<SUCCESS>//;s/<\/SUCCESS>//')

  echo "token: $token"

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

if [ -z $x_autologin ]; then
   echo "Error: No credentials file ${issuing_nation}.cred.dat found."
   exit 1
fi

if [ ! -f "$eligible_nations_file" ]; then
   eligible_nations_file="$eligible_nations_file_backup"
   if [ ! -f "$eligible_nations_file" ]; then
      echo "Failed to load eligiblity list." ; exit 1
   fi
fi

if [ ! -f "$excluded_nations_file" ]; then
   excluded_nations_file="$excluded_nations_file_backup"
fi



download_deck
run_lottery
get_card_name
print_debug_info
deliver_card
make_rmb_post

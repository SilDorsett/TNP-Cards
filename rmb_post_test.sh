#!/bin/bash

SCRIPT_HOME="$(cd -- "$MY_PATH" && pwd)"
DATA_HOME=${HOME}/.data/dpsystem

TODAY=$(date +%Y%m%d)

# NationStates Login Credentials
x_autologin=$(cat ${DATA_HOME}/sil_dorsett.cred.dat)

if [ -z $x_autologin ]; then
   echo "Error: No credentials file ${issuing_nation}.cred.dat found."
   exit 1
fi

user_agent=$(cat ${DATA_HOME}/useragent.dat)


### RUN LOTTERY ###i
rmb_post=$(cat rmb_post.txt)
rmb_post_text=$(echo -n "$rmb_post" | jq -s -R -r @uri)


### SEND CARD ###
url="https://www.nationstates.net/cgi-bin/api.cgi"
curl_data="nation=sil_dorsett"
curl_data="${curl_data}&region=the_north_pacific"
curl_data="${curl_data}&c=rmbpost"
curl_data="${curl_data}&text=${rmb_post_text}"

curl_prepare="${curl_data}&mode=prepare"

echo "curl_prepare = ${curl_prepare}"

response_prepare=$(curl -i -H "X-Autologin: $x_autologin" -A "$user_agent" "$url" --data "$curl_prepare" --http1.1)

echo "$response_prepare"

token=$(echo $response_prepare | grep -o '<SUCCESS>.*</SUCCESS>' | sed -e 's/<SUCCESS>//;s/<\/SUCCESS>//')
x_pin=$(echo "$response_prepare" | awk 'BEGIN {IGNORECASE=1} /^X-pin:/ {print $2}')

echo "token: $token"
echo "x-pin: $x_pin"

if [ -z $token ]; then
        echo "[ERROR] Token not received." ; exit 1
else
        sleep 2
        curl_execute="${curl_data}&mode=execute&token=$token"
        response_execute=$(curl -H "X-Pin: $x_pin" -A "$user_agent" "$url" --data "$curl_execute" --http1.1)
        echo "$response_execute"
fi                                                                              

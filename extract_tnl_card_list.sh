#!/bin/bash

# Input and output files
INPUT_FILE="cards.xml"
OUTPUT_FILE="cards_output.txt"

# Clear the output file if it exists
> "$OUTPUT_FILE"

url="https://www.nationstates.net/cgi-bin/api.cgi"
curl_data="q=cards+deck;nationname=the_northern_light"
response=$(curl -A "Sil Dorsett" "$url" --data "$curl_data" --http1.1)
echo $response | xmllint --format - > ${INPUT_FILE}

# Parse the XML and extract relevant fields
xmlstarlet sel -t \
  -m "//CARD[CATEGORY='common']" \
  -v "concat(CARDID, '|', CATEGORY, '|', SEASON)" \
  -n "$INPUT_FILE" | while read -r line; do
    # Print and append to the output file
    echo "$line" >> "$OUTPUT_FILE"
  done

echo "Parsing complete. Output saved to $OUTPUT_FILE."

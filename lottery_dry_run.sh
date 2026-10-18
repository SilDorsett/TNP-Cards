#!/bin/bash

TODAY=$(date +%Y%m%d)

# Input file (the file with the parsed cards)
INPUT_FILE="cards_output.txt"

# Check if the file exists and is not empty
if [[ ! -s "$INPUT_FILE" ]]; then
  echo "Error: Input file is either missing or empty."
  exit 1
fi

# Count the number of lines in the file
TOTAL_LINES=$(wc -l < "$INPUT_FILE")

# Generate a random line number between 1 and the total number of lines
RANDOM_LINE=$((RANDOM % TOTAL_LINES + 1))

# Extract the specific line from the file
SELECTED_LINE=$(sed -n "${RANDOM_LINE}p" "$INPUT_FILE")

# Do something with the selected line (e.g., print it)
echo "Lines in File: $TOTAL_LINES"
echo "Randomly selected line: Line $RANDOM_LINE"
echo "Contents of Line $RANDOM_LINE: $SELECTED_LINE"
card_id=$(echo "$SELECTED_LINE" | cut -d"|" -f1)
season_id=$(echo "$SELECTED_LINE" | cut -d"|" -f3)
echo "Card ID = ${card_id}"
echo "Season = ${season_id}"
echo "----------------------------------------"
WA_NATION_LIST="/mnt/nationstates/nations_tnp_wa_list/nations_tnp_wa_list.$TODAY.txt"
TOTAL_WA_COUNT=$(wc -l < "$WA_NATION_LIST")
RANDOM_WA_LINE=$((RANDOM % TOTAL_WA_COUNT + 1))
RANDOM_WA_NATION=$(sed -n "${RANDOM_WA_LINE}p" "$WA_NATION_LIST")
echo "Total WAs in TNP: ${TOTAL_WA_COUNT}"
echo "Selected WA Line: Line ${RANDOM_WA_LINE}"
echo "Selected Nation: ${RANDOM_WA_NATION}"

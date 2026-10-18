#!/bin/bash
#
# test_exclusion.sh
#
# Standalone test harness for the exclusion logic added to run_lottery.sh.
# Does NOT call the NationStates API or touch any cards/credentials — it only
# reads the eligible-nations file and the security-council exclusion file and
# shows you three sets:
#
#   1. Eligible        - nations who WILL be in the winner pool (eligible minus excluded)
#   2. Eligible-but-Excluded - nations who WOULD have been eligible, but got removed
#                              by today's exclusion list
#   3. Excluded-but-Already-Ineligible - nations on the exclusion list who weren't
#                                         even in the eligible list to begin with
#                                         (a no-op exclusion)
#
# Usage:
#   ./test_exclusion.sh
#   ./test_exclusion.sh YYYYMMDD        # test against a specific date's files

#################
### Variables ###
#################

today=$(date +%Y%m%d)
yesterday=$(date -d "Yesterday" +%Y%m%d)

# Allow overriding the date for testing against a specific day's files.
if [[ -n "$1" ]]; then
  today="$1"
  yesterday=$(date -d "$1 -1 day" +%Y%m%d)
fi

eligible_nations_file="/mnt/nationstates/keepers/keepers_of_the_north.$today.txt"
eligible_nations_file_backup="/mnt/nationstates/keepers/keepers_of_the_north.$yesterday.txt"

excluded_nations_file="/mnt/nationstates/securitycouncil/securitycouncil.$today.txt"
excluded_nations_file_backup="/mnt/nationstates/securitycouncil/securitycouncil.$yesterday.txt"

#######################
### Resolve files   ###
#######################

if [[ ! -f "$eligible_nations_file" ]]; then
  eligible_nations_file="$eligible_nations_file_backup"
  if [[ ! -f "$eligible_nations_file" ]]; then
    echo "Error: no eligible-nations file found for $today or $yesterday." >&2
    exit 1
  fi
fi

excluded_is_empty=0
if [[ ! -f "$excluded_nations_file" ]]; then
  excluded_nations_file="$excluded_nations_file_backup"
  if [[ ! -f "$excluded_nations_file" ]]; then
    echo "Warning: no exclusion file found for $today or $yesterday. Treating exclusion list as empty." >&2
    excluded_nations_file=$(mktemp)
    excluded_is_empty=1
  fi
fi

echo "Eligible file:  $eligible_nations_file"
echo "Excluded file:  $excluded_nations_file$([[ $excluded_is_empty -eq 1 ]] && echo ' (none found, treated as empty)')"
echo

###########################
### Build sorted copies ###
###########################

sorted_eligible=$(mktemp)
sorted_excluded=$(mktemp)

sort "$eligible_nations_file" | sed '/^$/d' > "$sorted_eligible"
sort "$excluded_nations_file" | sed '/^$/d' > "$sorted_excluded"

cleanup() {
  rm -f "$sorted_eligible" "$sorted_excluded"
  [[ $excluded_is_empty -eq 1 ]] && rm -f "$excluded_nations_file"
}
trap cleanup EXIT

#####################
### Compute sets   ###
#####################

final_eligible=$(comm -23 "$sorted_eligible" "$sorted_excluded")
eligible_but_excluded=$(comm -12 "$sorted_eligible" "$sorted_excluded")
excluded_but_already_ineligible=$(comm -13 "$sorted_eligible" "$sorted_excluded")

count_lines() {
  if [[ -z "$1" ]]; then
    echo 0
  else
    printf '%s\n' "$1" | wc -l
  fi
}

####################
### Print report ###
####################

echo "=== 1. Eligible nations (final winner pool: eligible minus excluded) ==="
echo "Count: $(count_lines "$final_eligible")"
if [[ -n "$final_eligible" ]]; then
  printf '%s\n' "$final_eligible"
else
  echo "(none)"
fi
echo

echo "=== 2. Eligible-but-Excluded (were eligible, removed by today's exclusion list) ==="
echo "Count: $(count_lines "$eligible_but_excluded")"
if [[ -n "$eligible_but_excluded" ]]; then
  printf '%s\n' "$eligible_but_excluded"
else
  echo "(none)"
fi
echo

echo "=== 3. Excluded-but-Already-Ineligible (on exclusion list, but weren't eligible anyway) ==="
echo "Count: $(count_lines "$excluded_but_already_ineligible")"
if [[ -n "$excluded_but_already_ineligible" ]]; then
  printf '%s\n' "$excluded_but_already_ineligible"
else
  echo "(none)"
fi

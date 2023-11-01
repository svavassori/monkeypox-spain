#!/bin/bash

file_pdf="$1"
file_txt="${file_pdf/\.pdf/\.txt}"

pdftotext -nopgbrk -layout -f 1 -l 1 "${file_pdf}" "${file_txt}"
date=$(date +%F --date=$(pdfinfo -isodates "${file_pdf}" | awk '/ModDate:/ { print $2}'))
last_processed_date=$(tail -n 1 "data/spain.csv" | awk -F ',' '{ print $1}')

if [ ! "${date}" \> "${last_processed_date}" ]
then
    echo "same or previous date (${date}), skipping ${file_pdf}."
else
    all=$(cat "${file_txt}" \
        | head --lines=$(grep -n "^ \+Total" "${file_txt}" |  cut -f1 -d:) \
        | tail --lines=+$(( $(grep -n "^ \+CCAA" "${file_txt}" |  cut -f1 -d:) + 1)) \
        | tr -d '.' \
        | tr ',' '.' \
        | sed -f ccaa-to-iso.sed \
              -e 's/^ \+//g' \
              -e 's/  \+/,/g' \
              -e 's/Total/ES,España/g' \
        | sort \
        | awk -F ',' --assign date=${date} '{print date","$1","$2","$3}' )

    echo -e "${all}" | grep --invert-match "España" >> "data/regions.csv"
    echo -e "${all}" | grep "España" >> "data/spain.csv"

    # create JSON files from cumulative CSV files
    mlr --icsv --ojson --jlistwrap cat "data/regions.csv" | jq '.' > "data/regions.json"
    mlr --icsv --ojson --jlistwrap cat "data/spain.csv"   | jq '.' > "data/spain.json"
fi

rm "${file_txt}"

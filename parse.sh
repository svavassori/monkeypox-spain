#!/bin/bash

file_pdf="$1"
file_txt="${file_pdf/\.pdf/\.txt}"

# extract PDF modifcation date
date=$(date +%F --date=$(pdfinfo -isodates ${file_pdf} | awk '/ModDate:/ { print $2}'))
last_processed_date=$(tail -n 1 "data/states.csv" | awk -F ',' '{ print $1}')

if [ "${date}" = "${last_processed_date}" ]
then
	# same date, this means no new file to process
	exit 0
fi

# converts to a txt file and remove page headers and wrapped line by splitting newlines with '.'
pdftotext -layout "${file_pdf}" "${file_txt}"
cat "${file_txt}" \
    | grep --line-number --no-group-separator --before-context=1 --after-context=4 "SECRETARÍA DE ESTADO" \
    | sed --silent 's/^\([0-9]\+\).*/\1d/p' \
    | sed --file=- "${file_txt}" \
    | sed '/^$/d' \
    | tr '\n' ' ' \
    | sed 's/\. /.\n/g' \
    | sponge "${file_txt}"

# extract cases for Autonomous Communities, Spain and rest of Europe
cases_ccaa="$(cat "${file_txt}" | grep "Los casos notificados" \
    | sed -e 's/.\+[Cc]omunidades [Aa]utónomas: //g' \
          -e 's/ ([^)]\+)//g' \
          -e 's/, ver Figura 1//g' \
          -e 's/, y /, /g' \
          -e 's/\([0-9]\+\) y /\1, /g' \
          -e 's/, \?/\n/g' \
          -e 's/ \([0-9]\+\)/,\1/g' \
          -e 's/Baleares/Islas Baleares/g' \
          -e 's/Leon/León/g' \
          -e 's/Castilla \([y-] \)\?[lL]a Mancha/Castilla-La Mancha/g' \
          -e 's/Comunidad Valencia/Comunidad Valenciana/g' \
          -e 's/\.//g' \
    | sed --file=ccaa-to-iso.sed \
    | sed "s/^/${date},/g" \
    | sort )"
cases_spain="$(cat "${file_txt}" | grep "En España" | sed 's/.\+se han notificado un total de \([0-9\.]\+\) casos.\+/\1/g' | tr -d '.')"
other_europe="$(cat "${file_txt}" | grep "En el resto de Europa" | sed -e 's/.\+casos confirmados de MPX.*, siendo //g' -e 's/ los países más afectados.*$//g' -e 's/[()]//g' -e 's/ \?, /\n/g' -e 's/ [ey] /\n/g' -e 's/ \([\.0-9]\)/,\1/g' | tr -d '.')"
other_world="$(cat "${file_txt}"  | grep "En el resto del mundo" | sed -e 's/.\+casos confirmados de MPX.*, siendo //g' -e 's/ los países más afectados.*$//g' -e 's/[()]//g' -e 's/ \?, /\n/g' -e 's/ [ey] /\n/g' -e 's/ \([\.0-9]\)/,\1/g' | tr -d '.')"

# put all data together as CSV
# translates country names from Spanish to English
# adds ISO codes (alpha-2)
# adds file's date
world="$(echo -e "España,${cases_spain}\n${other_europe}\n${other_world}" \
    | sed 's/EEUU/Estados Unidos/g' \
    | sed --file=spanish-to-english.sed \
    | sed --file=english-to-iso_codes.sed \
    | sed "s/^/${date},/g" \
    | sort )"
header="date,iso_code,state,cases"

# creates daily CSV files
file_daily_regions="data/${date}_regions.csv"
file_daily_states="data/${date}_states.csv"
echo -e "${header}\n${cases_ccaa}" > "${file_daily_regions}"
echo -e "${header}\n${world}" > "${file_daily_states}"

# append daily to cumulative ones
tail --lines=+2 "${file_daily_regions}" >> "data/regions.csv"
tail --lines=+2 "${file_daily_states}" >> "data/states.csv"

# create JSON files from cumulative CSV files
mlr --icsv --ojson --jlistwrap cat "data/regions.csv" | jq '.' > "data/regions.json"
mlr --icsv --ojson --jlistwrap cat "data/states.csv"  | jq '.' > "data/states.json"

rm "${file_txt}" "${file_daily_regions}" "${file_daily_states}"

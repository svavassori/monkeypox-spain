#!/bin/bash

# download updated files
base_url="https://www.sanidad.gob.es/profesionales/saludPublica/ccayes/alertasActual/alertaMonkeypox"

links_pdfs=$(wget --no-verbose --output-document=- "${base_url}/home.htm" | grep --only-matching '"docs/[^"]\+\.pdf"' | tr -d '"')

opts="--no-verbose --timestamping --directory-prefix="

wget ${opts}documentos/evaluación-rápida-riesgo "${base_url}"/$(echo "${links_pdfs}" | grep "ERR_Monkeypox_")
wget ${opts}documentos/informes "${base_url}"/$(echo "${links_pdfs}" | grep "Informe_de_situacion")
wget ${opts}documentos/protocolo "${base_url}"/$(echo "${links_pdfs}" | grep "ProtocoloMPX")

# download remaining documents
other_files=($(echo "${links_pdfs}" | grep --invert-match "ERR_Monkeypox_\|Informe_de_situacion\|ProtocoloMPX"))
for file in "${other_files[@]}"
do
	wget ${opts}documentos "${base_url}"/${file}
done

file_to_parse=$(echo "${links_pdfs}" | grep "Informe_de_situacion" | sed 's|docs/|documentos/informes/|g')
file_svg=$(echo "${file_to_parse/.pdf/.svg}")

# extract on-set date information from chart
inkscape "${file_to_parse}" --export-type=svg --pdf-page=2
python3 extract.py "${file_svg}" > "data/on-set_spain.csv"
mlr --icsv --ojson --jlistwrap cat "data/on-set_spain.csv"  | jq '.' > "data/on-set_spain.json"
rm "${file_svg}"

# parse PDF text
./parse.sh "${file_to_parse}"

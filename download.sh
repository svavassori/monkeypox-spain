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

file_to_parse="$(realpath $(echo "${links_pdfs}" | grep "Informe_de_situacion" | sed 's|docs/|documentos/informes/|g'))"

# extract on-set date information from chart on Friday
if [ $(date +%u) -eq 5 ]
then
	tmpdir=$(mktemp -d)
	pushd "${tmpdir}"
	pdfimages -f 2 -l 2 -png "${file_to_parse}" img
	file_png="${tmpdir}/$(ls -S *.png | head -1)"
	popd
	python3 extract.py "${file_png}" > "data/on-set_spain.csv"
	mlr --icsv --ojson --jlistwrap cat "data/on-set_spain.csv"  | jq '.' > "data/on-set_spain.json"
	rm -fr "${tmpdir}"
fi

# parse PDF text
./parse.sh "${file_to_parse}"

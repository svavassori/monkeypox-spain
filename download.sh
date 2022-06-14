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
./parse.sh "${file_to_parse}"

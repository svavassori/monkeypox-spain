#!/bin/bash

# download updated files
base_url="https://www.sanidad.gob.es/areas/alertasEmergenciasSanitarias/alertasActuales/alertaMonkeypox"
vaccines_url="https://www.sanidad.gob.es/areas/promocionPrevencion/vacunaciones/MonkeyPox"
isciii_url="https://www.isciii.es/QueHacemos/Servicios/VigilanciaSaludPublicaRENAVE/EnfermedadesTransmisibles/Paginas/Resultados_Vigilancia_Viruela-del-mono.aspx"

links_pdfs=$(wget --no-verbose --output-document=- "${base_url}/home.htm" | grep --only-matching '"docs/[^"]\+\.pdf"' | tr -d '"')
guides_pdfs=($(wget --no-verbose --output-document=- "${base_url}/guiaDeManejo.htm" | grep --only-matching '"docs/[^"]\+\.pdf"' | tr -d '"'))
vaccines_pdfs=($(wget --no-verbose --output-document=- "${vaccines_url}/home.htm" | grep --only-matching 'href="[^"]\+.pdf"' | sed 's/href=//g' | tr -d '"'))

opts="--no-verbose --timestamping --directory-prefix="

wget ${opts}documentos/evaluación-rápida-riesgo "${base_url}"/$(echo "${links_pdfs}" | grep "_ERR_Monkeypox")
wget ${opts}documentos/informes "${base_url}"/$(echo "${links_pdfs}" | grep "Informe_de_situacion")
wget ${opts}documentos/protocolo "${base_url}"/$(echo "${links_pdfs}" | grep "ProtocoloMPX")

# download remaining homepage's documents
other_files=($(echo "${links_pdfs}" | grep --invert-match "ERR_Monkeypox\|Informe_de_situacion\|ProtocoloMPX"))
for file in "${other_files[@]}"
do
	wget ${opts}documentos "${base_url}"/${file}
done

# download vaccines
for file in "${vaccines_pdfs[@]}"
do
    wget ${opts}documentos/vacunas "${vaccines_url}"/${file}
done

# download guides
for file in "${guides_pdfs[@]}"
do
	wget ${opts}guías "${base_url}"/${file}
done

# downloads reports from ISCIII
isciii_pdfs=$(wget --no-verbose --output-document=- "${isciii_url}" \
	| sed 's/<a href=/\n/g' \
	| grep '^"/QueHacemos/Servicios/VigilanciaSaludPublicaRENAVE/EnfermedadesTransmisibles/Documents/archivos%20A-Z/MPOX/SITUACION%20EPIDEMIOLOGICA' \
	| awk -F '"' '{ print "https://www.isciii.es"$2 }' )

echo -e "${isciii_pdfs}" | xargs wget ${opts}documentos/isciii

# parse only the most-recent file (the one at the top)
file_to_parse="$(realpath "$(echo "${isciii_pdfs}" | head --lines=1 | sed -e 's/%20/ /g' -e 's|.*/MPOX/|documentos/isciii/|g')")"

./convert.sh "${file_to_parse}"

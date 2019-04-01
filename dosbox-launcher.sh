#!/usr/bin/env bash

#
# This script calls DOSBox to launch a game in RetroPie
#

dosboxromdir="${HOME}/RetroPie/roms/pc/gog"
game=$(basename -s .sh "${0}")

# DOSBox settings override
export DOSBOX_SDL_USESCANCODES=false

if [[ -x "/opt/retropie/emulators/dosbox/bin/dosbox" ]]; then
	emu="/opt/retropie/emulators/dosbox/bin/dosbox"
fi

if ! [[ -x "$(command -v ${emu:-dosbox})" ]]; then
	echo 'DOSBox not found but is required for most GOG software.  Try installing the optional package "dosbox" from the RetroPie Setup script.'
	exit 1
fi

echo "Launching ${game}"
cd "${dosboxromdir}/${game}/DOSBOX" || exit 1

# A fix for stargunner on Linux:
if [[ -f "../dosboxSTARGUN_single.conf" ]] && ! grep -q "pause" ../dosboxSTARGUN_single.conf; then
	#This fixes stargunner from crashing on load on linux:
	ed -s ../dosboxSTARGUN_single.conf <<< $'g/STARGUN\\.exe/i\\\npause\nw'
fi

dosboxargs=( $(jq --raw-output '.playTasks[] | select(.isPrimary==true) | .arguments' ../goggame-*.info | sed 's:\\:/:g;s:\"::g') )

if [[ -z "${dosboxargs[*]}" ]]; then

	dosboxargs=(
		-conf
		"$(find .. -maxdepth 1 -name 'dosbox*.conf' | awk '{print length " " $1}' | sort -n | head -1 | awk '{print $2}')"
		-conf
		"$(find .. -maxdepth 1 -name 'dosbox*single.conf' | head -1)"
		-c
		exit
	)

fi

# match=$(echo "${dosboxargs[@]:0}" | grep -o "STARGUN") && if [[ -n "${match}" ]]; then
# 	#pause emulation before game starts, because it will crash if not
# 	printf '[autoexec]\npause' > dosboxSTARGUN_pause.conf
# 	dosboxargs=(
# 		"${dosboxargs[@]:0:2}"
# 		-config
# 		dosboxSTARGUN_pause.conf
# 		"${dosboxargs[@]:2}"
# 	)
# fi

echo "Found arugments: ${dosboxargs[*]}"

"${emu:-dosbox}" ${dosboxargs[@]}

#!/usr/bin/env bash
# This application was made by https://github.com/sigboe
# The License is GNU General Public License v3.0
# https://github.com/sigboe/pie-galaxy/blob/master/LICENSE
# shellcheck disable=SC2094 # Dirty hack avoid runcommand to steal stdout

# Default settings 
# - Don't edit these as they will be overwritten whenever piegalaxy is updated
# - Set preferences in ~/.config/piegalaxy/piegalaxy.conf
title="Pie Galaxy"
tmpdir="${HOME}/.cache/piegalaxy"
downdir="${HOME}/Downloads"
romdir="${HOME}/RetroPie/roms"
dosboxdir="${romdir}/pc/gog"
scummvmdir="${romdir}/scummvm"
biosdir="${HOME}/RetroPie/BIOS"
scriptdir="$(dirname "$(readlink -f "${0}")")"
wyvernbin="${scriptdir}/wyvern"
innobin="${scriptdir}/innoextract"
exceptions="${scriptdir}/exceptions"
renderhtml="html2text"
retropiehelper="${HOME}/RetroPie-Setup/scriptmodules/helpers.sh"
configfile="${HOME}/.config/piegalaxy/piegalaxy.conf"
version="0.2"

if [[ -n "${XDG_CACHE_HOME}" ]]; then
	tmpdir="${XDG_CACHE_HOME}/piegalaxy"
fi

if [[ -n "${XDG_CONFIG_HOME}" ]]; then
	configfile="${XDG_CONFIG_HOME}/piegalaxy/piegalaxy.conf"
fi

if [[ -f "${configfile}" ]]; then
	if grep -E -q -v '^#|^[^ ]*=[^;]*' "{$configfile}"; then
		echo "Config file is dirty, cleaning it..." >&2
		mv "${configfile}" "$(dirname "${configfile}")/dirty.conf" 
		grep -E '^#|^[^ ]*=[^;&]*'  "$(dirname "${configfile}")/dirty.conf"  > "${configfile}"
	fi
	# shellcheck source=/dev/null
	source "${configfile}"
fi

# shellcheck source=exceptions
source "${exceptions}"

_depends() {
	if ! [[ -x "$(command -v dialog)" ]]; then
		echo "dialog not installed" >"$(tty)"
		_exit 1
	fi
	if ! [[ -x "${wyvernbin}" ]]; then
		_error "Wyvern not installed." 1
	fi
	if ! [[ -x "${innobin}" ]]; then
		_error "innoextract not installed." 1
	fi
	if ! [[ -x "$(command -v jq)" ]]; then
		_error "jq not installed." 1
	fi
	if ! [[ -x "$(command -v html2text)" ]]; then
		renderhtml="sed s:\<br\>:\\n:g"
	fi
}

main() {
	menuOptions=(
		"Connect" "Operations associated with GOG Connect"
		"Download" "Download game ${gameName:-selected from the Library}"
		"Install" "Install a GOG game from an installer"
		"Library" "List all games you own"
		"Sync" "Sync a game's saves to a specific location for backup"
		"About" "About this program"
	)

	selected=$(dialog \
		--backtitle "${title}" \
		--cancel-label "Exit" \
		--menu "Choose one" \
		22 77 16 "${menuOptions[@]}" 3>&1 1>&2 2>&3 >"$(tty)" <"$(tty)")

}

_Library() {
	mapfile -t myLibrary < <(echo "${wyvernls}" | jq --raw-output '.games[] | .ProductInfo | .id, .title')

	unset selectedGame
	selectedGame=$(dialog \
		--backtitle "${title}" \
		--ok-label "Details" \
		--menu "Choose one" 22 77 16 "${myLibrary[@]}" 3>&1 1>&2 2>&3 >"$(tty)" <"$(tty)")

	if [[ -n "${selectedGame}" ]]; then
		_description "${selectedGame}"
	fi

}

_description() {
	gameName=$(echo "${wyvernls}" | jq --raw-output --argjson var "${1}" '.games[] | .ProductInfo | select(.id==$var) | .title')
	gameDescription=$(curl -s "http://api.gog.com/products/${1}?expand=description" | jq --raw-output '.description | .full' | $renderhtml)

	local url page
	url="$(echo "${wyvernls}" | jq --raw-output --argjson var "${1}" '.games[] | .ProductInfo | select(.id==$var) | .url')"
	page="$(curl -s "https://www.gog.com${url}")"

	if echo "${page}" | grep -q "This game is powered by <a href=\"https://www.dosbox.com/\" class=\"dosbox-info__link\">DOSBox"; then
		gameDescription="This game is powered by DOSBox\n\n${gameDescription}"

	elif echo "${page}" | grep -q "This game is powered by <a href=http://scummvm.org>ScummVM"; then
		gameDescription="This game is powered by ScummVM\n\n${gameDescription}"

	else
		gameDescription="${gameDescription}"

	fi

	_msgbox "${gameDescription}" --ok-label "Select"

}

_Connect() {
	availableGames=$("${wyvernbin}" connect ls 2>&1 >"$(tty)")

	if _yesno "Available games:\n\n${availableGames##*wyvern} \n\nDo you want to claim the games?"; then
		"${wyvernbin}" connect claim
		_msgbox "Games claimed"
	fi

}

_Download() {
	if [[ -z ${selectedGame} ]]; then
		_msgbox "No game selected, please use one from your library."
		return
	else
		mkdir -p "${downdir}"
		cd "${downdir}/" || _exit "Could not interact with download directory" 1
		"${wyvernbin}" down --id "${selectedGame}" --force-windows || { _error "download failed"; return; }
		_msgbox "${gameName} finished downloading."
	fi

}

_checklogin() {
	if grep -q "access_token =" "${HOME}/.config/wyvern/wyvern.toml"; then
		wyvernls=$(timeout 30 "${wyvernbin}" ls --json) || _error "It took longer than 30 seconds. You may need to log in again.\nLogging inn via this UI is not yet developed.\nRight now its easier if you ssh into the RaspberryPie and run\n\n${wyvernbin} ls\n\nand follow the instructions to login." 1
	else
		_error "You are not logged into wyvern\nLogging inn via this UI is not yet developed.\nRight now its easier if you ssh into the RaspberryPie and run\n\n${wyvernbin} ls\n\nand follow the instructions to login." 1
	fi
}

_About() {
	_msgbox "Version: ${version}\n\nA GOG client for RetroPie and other GNU/Linux distributions. It uses Wyvern to download and Innoextract to extract games. Pie Galaxy also provides a user interface navigatable by game controllers and will install games in such a way that it will use native runtimes. It also uses Wyvern to let you claim games available from GOG Connect."
}

_Sync() {
	_msgbox "This feature is not written yet for RetroPie."
}

_Install() {
	local fileSelected setupInfo gameName gameID type shortName
	fileSelected=$(_fselect "${downdir}")

	if ! [[ -f "${fileSelected}" ]]; then
		_msgbox "No file was selected."
	else

		setupInfo=$("${innobin}" --gog-game-id "${fileSelected}")
		gameName=$(echo "${setupInfo}" |& awk -F'"' '{print $2}')
		gameID=$("${innobin}" -s --gog-game-id "${fileSelected}")

		_yesno "${setupInfo#"Inspecting "}" --title "${gameName}" --extra-button --extra-label "Delete" --ok-label "Install"

		case $? in
			1|255)
				# cancel or esc
				return;;
			3)
				#delete
				rm "${fileSelected}" || { _error "unable to delete file"; return; }
				_msgbox "${fileSelected} deleted."
				return;;
		esac

		# If the setup.exe doesn't have the gameID try to fetch it from the gameName and the library.
		[[ -z "${gameID}" ]] && gameID=$(echo "${wyvernls}" | jq --raw-output --arg var "${gameName}" '.games[] | .ProductInfo | select(.title==$var) | .id')

		if [[ -z "${gameID}" ]]; then
			# If setup.exe still doesn't contain gameID, try guessing the slug, and fetchign the ID that way.
			gameSlug=$(echo "${gameName// /_}" | tr '[:upper:]' '[:lower:]')
			gameID=$(echo "${wyvernls}" | jq --raw-output --arg var "${gameSlug}" '.games[] | .ProductInfo | select(.slug==$var) | .id')
		fi

		[[ -z "${gameID}" ]] && { _error "Can't figure out the Game ID. Aborting installation."; return; }

		#Sanitize game name
		gameName=$(echo "${gameName}" | sed -e 's:™::g' -e 's:  *: :g' )

		_extract

		if type "${gameID}_exception" &> /dev/null; then
			"${gameID}_exception"
			return
		elif [[ ! -d "${tmpdir}/${gameName}" ]]; then
			_error "Extraction did not succeed"
			return
		fi

		type=$(_getType "${gameName}")

		if [[ "$type" == "dosbox" ]]; then
			mv -f "${tmpdir}/${gameName}" "${dosboxdir}/${gameName}" || { _error "Unable to copy game to ${dosboxdir}\n\nThis is likely due to DOSBox not being installed."; return; }
			cd "${romdir}/pc" || _error "unable to access ${romdir}/pc\nFailed to create launcher."
			ln -sf "${scriptdir}/dosbox-launcher.sh" "${gameName}.sh" || _error "Failed to create launcher."
			_msgbox "GOG.com game ID: ${gameID}\n$(basename "${fileSelected}") was extracted and installed to ${dosboxdir}" --title "${gameName} was installed."
		elif [[ "$type" == "scummvm" ]]; then
			shortName=$(find "${tmpdir}/${gameName}" -name '*.ini' -exec cat {} + | grep gameid | awk -F= '{print $2}' | sed -e "s/\r//g")
			mv -f "${tmpdir}/${gameName}" "${scummvmdir}/${gameName}.svm" || { _error "Uname to copy game to ${scummvmdir}\n\nThis is likely due to ScummVM not being installed."; return; }
			echo "${shortName}" >"${scummvmdir}/${gameName}.svm/${shortName}.svm"
			_msgbox "GOG.com game ID: ${gameID}\n$(basename "${fileSelected}") was extracted and installed to ${scummvmdir}\n\nTo finish the installation and open ScummVM and add game, or install lr-scummvm." --title "${gameName} was installed."
		elif [[ "$type" == "unsupported" ]]; then
			_error "${fileSelected} apperantly is unsupported."
			return
		fi

	fi

}

_extract() {
	#There is a bug in innoextract that missinterprets the filestructure. using dirname & find as a workaround
	local folder
	rm -rf "${tmpdir:?}/output" #clean the extract path (is this okay to do like this?)
	rm -rf "${tmpdir:?}/${gameName}" #also cleanup where to move the files
	mkdir -p "${tmpdir}/output" | { _error "Could not initialize temp folder for extraction"; return; } 
	"${innobin}" --gog "${fileSelected}" --output-dir "${tmpdir}/output" >"$(tty)" <"$(tty)"
	folder=$(dirname "$(find "${tmpdir}/output" -name 'goggame-*.info')")
	if [[ "${folder}" == "." ]]; then
		# Didn't find goggame-*.info, now we must rely on exception to catch this install.
		folder="${tmpdir}/output/app"
	fi
	if [[ -n "$(ls -A "${folder}/__support/app")" ]]; then
		cp -r "${folder}"/__support/app/* "${folder}/"
	fi
	mv "${folder}" "${tmpdir}/${gameName}"
}

_getType() {

	local gamePath type
	gamePath=$(cat "${tmpdir}/${1}/"goggame-*.info | jq --raw-output '.playTasks[] | select(.isPrimary==true) | .path')

	if [[ "${gamePath}" == *"DOSBOX"* ]] || [[ -d "${tmpdir}/${1}/DOSBOX" ]]; then
		type="dosbox"
	elif [[ "${gamePath}" == *"scummvm"* ]]; then
		type="scummvm"
	elif [[ "${gamePath}" == *"neogeo"* ]]; then
		# Surly this wont work, but its a placeholder
		type="neogeo"
	else
		_error "Didn't find what game it was.\nNot installing."
		return
	fi

	echo "${type:-unsupported}"
}

_msgbox() {
	local msg="${1}"
	shift
	local opts=("${@}")
	dialog \
		--backtitle "${title}" \
		"${opts[@]}" \
		--msgbox "${msg}" \
		22 77  3>&1 1>&2 2>&3 >"$(tty)" <"$(tty)"
}

_yesno() {
	local msg="${1}"
	shift
	local opts=("${@}")
	dialog \
		--backtitle "${title}" \
		"${opts[@]}" \
		--yesno "${msg}" \
		22 77 3>&1 1>&2 2>&3 >"$(tty)" <"$(tty)"
	return ${?}
}

_fselect() {
	local termh windowh dirlist selected
	termh=$(tput lines)
	(( windowh = "${termh}" - 10 ))
	[[ "${windowh}" -gt "22" ]] && windowh="22"
	if [[ "${windowh}" -ge "8" ]]; then
		dialog \
			--backtitle "${title}" \
			--fselect "${1}/" \
			"${windowh}" 77 3>&1 1>&2 2>&3 >"$(tty)" <"$(tty)"
	else
		# in case of a very tiny terminal window
		# make an array of the filenames and put them into --menu instead
		while read -r filename; do
			dirlist+=( "$(basename "${filename}")" )
			dirlist+=( "$("${innobin}" --gog-game-id "${filename}" |& awk -F'"' '{print $2}' )" )

		done < <(find "${1}" -maxdepth 1 -type f)
		selected=$(dialog \
			--backtitle "${title}" \
			--menu "Choose one" \
			22 77 16 "${dirlist[@]}" 3>&1 1>&2 2>&3 >"$(tty)" <"$(tty)")
		echo "${selected}"
	fi

}

_error() {
	dialog \
		--backtitle "${title}" \
		--title "ERROR:" \
		--msgbox "${1}" \
		22 77 >"$(tty)" <"$(tty)"
	[[ "${2}" =~ ^[0-9]+$ ]] && _exit "${2}"
}

_joy2key() {
	if [[ -f "${retropiehelper}" ]]; then
		local scriptdir="/home/pi/RetroPie-Setup"
		# shellcheck source=/dev/null
		source "${retropiehelper}"
		joy2keyStart
	fi
}
_exit() {
	clear
	if [[ -f "${retropiehelper}" ]]; then
		joy2keyStop
	fi
	exit "${1:-0}"
}

_joy2key
_depends
_checklogin

while true; do main; "_${selected:-exit}"; done

_exit

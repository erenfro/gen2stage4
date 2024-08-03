#!/usr/bin/env bash

# get available compression types
declare -A compressTypes
compressTypes=(
	["bz2"]="bzip2 pbzip2 lbzip2"
	["gz"]="gzip pigz"
	["lrz"]="lrzip"
	["lz"]="lzip plzip"
	["lz4"]="lz4"
	["lzo"]="lzop"
	["xz"]="xz pixz"
	["zst"]="zstd"
)
declare -A compressAvail
for ext in "${!compressTypes[@]}"; do
	for exechk in ${compressTypes[${ext}]}; do
		binchk=$(command -v "${exechk}")
		if [[ -n "$binchk" ]]; then
			compressAvail+=(["${ext}"]="$binchk")
		fi
	done
done

# set flag variables to null/default
optQuiet=false


function showHelp() {
	echo "Usage:"
	echo "$(basename "$0") [-q ] [-s || -t <target>] <archivename> [-- [additional-tar-options]]"
	echo 
	echo "-q           activates quiet mode (no confirmation)"
	echo "-s           extracts archive in current directory"
	echo "-t <path>    extracts archive in target <path>"
	echo "-h           display this help message."

	if [[ "$1" -ge 0 ]]; 	then
		exit "$1"
	else
		exit 0
	fi
}

function errorMsg() {
	local rc=0

	if [[ "$1" -gt 0 ]]; then
		rc="$1"
		shift
	fi

	echo "$*" >&2

	if [[ "$rc" -gt 0 ]]; then
		exit "$rc"
	fi
}


# reads options:
tarArgs=()
while [[ $# -gt 0 ]]; do
	while getopts ":t:sqh" flag; do
		case "$flag" in
			t)	targetPath="$OPTARG";;
			s)	targetPath="$(pwd)";;
			q)	optQuiet=true;;
			h)	showHelp 0;;
			\?)	errorMsg 1 "Invalid option: -$OPTARG";;
			:)	errorMsg 1 "Option -$OPTARG requires an argument.";;
		esac
	done || exit 1

	[[ $OPTIND -gt $# ]] && break # reached the end of parameters

	shift $((OPTIND - 1)) # Free processed options so far
	OPTIND=1              # we must reset OPTIND
	if [[ -z "$archiveFile" ]]; then
		archiveFile=$1
	else
		tarArgs[${#tarArgs[*]}]=$1
	fi
	shift                 # remove saved arg
done

# checks if run as root:
#if [[ "$(id -u)" -ne 0 ]]; then
#	echo "$(basename "$0"): must run as root"
#	exit 250
#fi

if [[ ! -r "$archiveFile" ]]; then
	echo "ERROR: archive file (\`$archiveFile\`) does not exist"
	exit 1
fi

archiveExt="${archiveFile##*.}"

if [[ "${archiveFile%%.$archiveExt}" =~ *.\.tar ]]; then
	echo "The stage file you are trying to unpack (\`$archiveFile\`) does not appear to be an archived TAR file"
	echo "${archiveFile%%.$archiveExt}"
	exit 1
fi

if [[ -n "$targetPath" ]]; then
	if [[ ! -d "$targetPath" ]]; then
		echo "$(basename "$0"): target path '$targetPath' does not exist"
		exit 1
	fi

	# make sure targetPath path ends with slash
	if [[ "$targetPath" != */ ]]; then
		targetPath="${targetPath}/"
	fi
else
	echo "ERROR: Neither -s or -t <path> provided"
	exit 2
fi

# Check if specified type is available
if [[ -z "${compressAvail[$archiveExt]}" ]]; then
	echo "$(basename "$0"): specified archive compression type not supported."
	echo "Supported: ${compressAvail[*]}"
	exit 1
fi

compressOptions=("${compressAvail[$archiveExt]}")
case "$archiveExt" in
	xz)		compressOptions+=("-T0");;
esac

tarOptions=(
	"-xv"
	"--xattrs-include=*.*"
	"--numeric-owner"
	"--use-compress-prog=${compressOptions[*]}"
)

tarOptions+=("${tarArgs[@]}")


# if not in optQuiet mode, this message will be displayed:
if ! $optQuiet; then
	echo "Are you sure that you want to extract a stage archive to the system"
	echo "to the destination path?"
	echo "$targetPath"
	echo
	echo "COMMAND LINE PREVIEW:"
	echo 'tar' "${tarOptions[@]}" -f "$archiveFile" -C "$targetPath"
	echo
	echo -n 'Type "yes" to continue or anything else to quit: '
	read -r promptAgree
	if [[ "${promptAgree,,}" == "yes" ]]; then
		optQuiet=true
	fi
fi

# start stage4 creation:
if $optQuiet; then
	echo "Would've worked"
	#tar "${tarOptions[@]}" -f "$archiveFile" -C "$targetPath"
fi

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
	for exe in ${compressTypes[${ext}]}; do
		BIN=$(command -v "${exe}")
		if [[ -n "$BIN" ]]; then
			compressAvail+=(["${ext}"]="$BIN")
		fi
	done
done

# set flag variables to null/default
optExcludeBoot=false
optExcludeConfidential=false
optExcludeLost=false
optQuiet=false
optUserExclude=()
optUserInclude=()
optCompressType="bz2"
optSeperateKernel=false
hasPortageQ=false

if command -v portageq &>/dev/null; then
	hasPortageQ=true
fi

function showHelp() {
	echo "Usage:"
	echo "$(basename "$0") [-b -c -k -l -q] [-C <type>] [-s || -t <target>] [-e <exclude*>] [-i <include>] <archivename> [additional-tar-options]"
	echo 
	echo "-b           excludes boot directory"
	echo "-c           excludes some confidential files (currently only .bash_history and connman network lists)"
	echo "-k           separately save current kernel modules and src (creates smaller targetArchives and saves decompression time)"
	echo "-l           excludes lost+found directory"
	echo "-q           activates quiet mode (no confirmation)"
	echo "-C <type>    specify tar compression (default: ${optCompressType}, available: ${!compressAvail[*]})"
	echo "-s           makes tarball of current system"
	echo "-t <path>    makes tarball of system located at the <targetPath-mountpoint>"
	echo "-e <exclude> an additional exclude directory (one dir one -e, do not use it with *)"
	echo "-i <include> an additional include. This has higher precedence than -e, -t, and -s"
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
	while getopts ":t:C:e:i:skqcblh" flag; do
		case "$flag" in
			t)	targetPath="$OPTARG";;
			s)	targetPath="/";;
			C)	optCompressType="$OPTARG";;
			q)	optQuiet=true;;
			k)	optSeperateKernel=true;;
			c)	optExcludeConfidential=true;;
			b)	optExcludeBoot=true;;
			l)	optExcludeLost=true;;
			e)	optUserExclude+=("--exclude=${OPTARG}");;
			i)	optUserInclude+=("$OPTARG");;
			h)	showHelp 0;;
			\?)	errorMsg 1 "Invalid option: -$OPTARG";;
			:)	errorMsg 1 "Option -$OPTARG requires an argument.";;
		esac
	done || exit 1

	[[ $OPTIND -gt $# ]] && break # reached the end of parameters

	shift $((OPTIND - 1)) # Free processed options so far
	OPTIND=1              # we must reset OPTIND
	if [[ -z "$targetArchive" ]]; then
		targetArchive=$1
	else
		tarArgs[${#tarArgs[*]}]=$1
	fi
	#args[${#args[*]}]=$1  # save first non-option argument (a.k.a. positional argument)
	shift                 # remove saved arg
done

# checks if run as root:
#if [[ "$(whoami)" != 'root' ]]
#then
#	echo "$(basename "$0"): must be root."
#	exit 1
#fi

if [[ -z "$targetPath" ]]; then
	echo "$(basename "$0"): no system path specified"
	exit 1
fi

# make sure targetPath path ends with slash
if [[ "$targetPath" != */ ]]; then
	targetPath="${targetPath}/"
fi

# shifts pointer to read mandatory output file specification
#shift $((OPTIND - 1))
#targetArchive=${args[0]}

# checks for correct output file specification
if [[ -z "$targetArchive" ]]; then
	echo "$(basename "$0"): no archive file name specified"
	exit 1
fi

# determines if filename was given with relative or absolute path
#if (($(grep -c '^/' <<< "$targetArchive") > 0)); then
if [[ "$targetArchive" =~ ^\/.* ]]; then
	stage4Filename="${targetArchive}.tar"
else
	stage4Filename="$(pwd)/${targetArchive}.tar"
fi

# Check if compression in option and filename
if [[ -z "$optCompressType" ]]; then
	echo "$(basename "$0"): no archive compression type specified"
	exit 1
else
	stage4Filename="${stage4Filename}.${optCompressType}"
fi

# Check if specified type is available
if [[ -z "${compressAvail[$optCompressType]}" ]]; then
	echo "$(basename "$0"): specified targetArchive compression type not supported."
	echo "Supported: ${compressAvail[*]}"
	exit 1
fi

# Shifts pointer to read custom tar options
#shift
#mapfile -t OPTIONS <<< "$@"
# Handle when no options are passed
#((${#OPTIONS[@]} == 1)) && [ -z "${OPTIONS[0]}" ] && unset OPTIONS

if ((optSeperateKernel)); then
	optUserExclude+=("--exclude=\"${targetPath}usr/src/*\"")
	optUserExclude+=("--exclude=\"${targetPath}lib*/modules/*\"")
fi


# tarExcludes:
tarExcludes=(
	"--exclude=\"${targetPath}dev/*\""
	"--exclude=\"${targetPath}var/tmp/*\""
	"--exclude=\"${targetPath}media/*\""
	"--exclude=\"${targetPath}mnt/*/*\""
	"--exclude=\"${targetPath}proc/*\""
	"--exclude=\"${targetPath}run/*\""
	"--exclude=\"${targetPath}sys/*\""
	"--exclude=\"${targetPath}tmp/*\""
	"--exclude=\"${targetPath}var/lock/*\""
	"--exclude=\"${targetPath}var/log/*\""
	"--exclude=\"${targetPath}var/run/*\""
	"--exclude=\"${targetPath}var/lib/docker/*\""
	"--exclude=\"${targetPath}var/lib/containers/*\""
	"--exclude=\"${targetPath}var/lib/machines/*\""
	"--exclude=\"${targetPath}var/lib/libvirt/*\""
)

tarExcludesPortage=(
	"--exclude=\"${targetPath}var/db/repos/*/*\""
	"--exclude=\"${targetPath}var/cache/distfiles/*\""
	"--exclude=\"${targetPath}usr/portage/*\""
)

tarExcludes+=("${optUserExclude[@]}")

tarIncludes=()

tarIncludes+=("${optUserInclude[@]}")

if [[ "$targetPath" == '/' ]]; then
	tarExcludes+=("--exclude=\"$(realpath "$stage4Filename")\"")
	if $hasPortageQ; then
		portageRepos=$(portageq get_repos /)
		for i in ${portageRepos}; do
			repoPath=$(portageq get_repoPath / "${i}")
			tarExcludes+=("--exclude=\"${repoPath}/*\"")
		done
		tarExcludes+=("--exclude=\"$(portageq distdir)/*\"")
	else
		tarExcludes+=("${tarExcludesPortage[@]}")
	fi
else
	tarExcludes+=("${tarExcludesPortage[@]}")
fi

if $optExcludeConfidential; then
	tarExcludes+=("--exclude=\"${targetPath}home/*/.bash_history\"")
	tarExcludes+=("--exclude=\"${targetPath}root/.bash_history\"")
	tarExcludes+=("--exclude=\"${targetPath}var/lib/connman/*\"")
fi

if $optExcludeBoot; then
	tarExcludes+=("--exclude=\"${targetPath}boot/*\"")
fi

if $optExcludeLost; then
	tarExcludes+=("--exclude=\"lost+found\"")
fi

# Compression options
compressOptions=("${compressAvail[$optCompressType]}")
if [[ "${compressAvail[$optCompressType]}" == *"/xz" ]]; then
	compressOptions+=("-T0")
fi

# Generic tar options:
tarOptions=(
	-cpP
	--ignore-failed-read
	"--xattrs-include=*.*"
	--numeric-owner
	"--checkpoint=.500"
	"--use-compress-prog=${compressOptions[*]}"
)

tarOptions+=(${tarArgs[@]})

# if not in optQuiet mode, this message will be displayed:
if ! $optQuiet; then
	echo "Are you sure that you want to make a stage 4 tarball of the system"
	echo "located under the following directory?"
	echo "$targetPath"
	echo
	echo "WARNING: since all data is saved by default the user should exclude all"
	echo "security- or privacy-related files and directories, which are not"
	echo "already excluded by mkstage4 options (such as -c), manually per cmdline."
	echo "example: \$ $(basename "$0") -s /my-backup --exclude=/etc/ssh/ssh_host*"
	echo
	echo "COMMAND LINE PREVIEW:"
	echo 'tar' "${tarOptions[@]}" "${tarIncludes[@]}" "${tarExcludes[@]}" "${OPTIONS[@]}" -f "$stage4Filename" "${targetPath}"
	if $optSeperateKernel; then
		echo
		echo 'tar' "${tarOptions[@]}" -f "$stage4Filename.ksrc" "${targetPath}usr/src/linux-$(uname -r)"
		echo 'tar' "${tarOptions[@]}" -f "$stage4Filename.kmod" "${targetPath}lib"*"/modules/$(uname -r)"
	fi
	echo
	echo -n 'Type "yes" to continue or anything else to quit: '
	read -r AGREE
	if [[ "${AGREE,,}" == "yes" ]]; then
		optQuiet=true
	fi
fi

# start stage4 creation:
if $optQuiet; then
	echo "Would've worked"
	#tar "${tarOptions[@]}" "${tarIncludes[@]}" "${tarExcludes[@]}" "${OPTIONS[@]}" -f "$stage4Filename" "${targetPath}"
	#if [[ "$optSeperateKernel" ]]
	#then
	#	tar "${tarOptions[@]}" -f "$stage4Filename.ksrc" "${targetPath}usr/src/linux-$(uname -r)"
	#	tar "${tarOptions[@]}" -f "$stage4Filename.kmod" "${targetPath}lib"*"/modules/$(uname -r)"
	#fi
fi

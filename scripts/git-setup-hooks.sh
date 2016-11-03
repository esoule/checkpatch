#!/bin/sh
#
# This script installs pre-commit hook to ".git/hooks"
#
# when modifying, please test with "/bin/sh" and "/sbin/busybox ash"
#
# set -x
set -u
set -e
# set -o pipefail 2>/dev/null || :
PROGNAME="$(basename "$0")"
SCRIPTS_HOME="$(cd "$(dirname "$0")" && cd .. && pwd)"

DST_GIT_HOOKS_DIR="${SCRIPTS_HOME}/.git/hooks"
SRC_DIR="${SCRIPTS_HOME}/scripts/git-hooks/copy"
HOOKS_FILE_LIST=" pre-commit-fallback-101.sh pre-commit"

WHY_STR=""

vecho="true"
do_setup=""
do_force=""
stamp_file=""

usage()
{
	cat <<__EOF__

Usage: $0 [-s] [-t STAMPFILE]
Set up git hooks, if necessary. Also touch the stamp file, if provided.

Arguments:
  -s                         set up git hooks (required)
  -v                         verbose mode
  -t STAMPFILE               touch STAMPFILE after setup (useful in makefiles)
  -h                         this help message

Advanced options:
  -f                         force set

__EOF__

	true
}

parse_opts()
{
	if [ $# -lt 1 ] ; then
		usage >&2
		return 1
	fi

	while getopts "sft:vh" OPTION ; do
		case $OPTION in
		s)
			do_setup="Y"
			;;
		f)
			do_force="Y"
			;;
		t)
			stamp_file="${OPTARG}"
			;;
		v)
			vecho="echo"
			;;
		h)
			usage
			return 1
			;;
		*)
			usage >&2
			return 1
			;;
		esac
	done

	if [ -z "${do_setup}" ] ; then
		echo "ERROR: $PROGNAME: please pass -s parameter to set up git hooks" >&2
		return 1
	fi

	return 0
}

may_setup_hooks()
{
	WHY_STR=""

	if [ ! -d "${DST_GIT_HOOKS_DIR}" ] ; then
		WHY_STR="No .git/hooks directory"
		return 1
	fi

	if [ ! -w "${DST_GIT_HOOKS_DIR}" ] ; then
		WHY_STR=".git/hooks directory not writable"
		return 1
	fi

	for fname in ${HOOKS_FILE_LIST} ; do
		if [ ! -r "${SRC_DIR}/${fname}" ] ; then
			WHY_STR="File ${SRC_DIR}/${fname} missing"
			return 1
		fi
	done

	return 0
}

setup_is_needed()
{
	WHY_STR=""

	if [ -n "${do_force}" ] ; then
		WHY_STR="Setup forced with -f switch"
		return 0

	fi

	if [ ! -e "${DST_GIT_HOOKS_DIR}/pre-commit" ] ; then
		WHY_STR="New setup"
		return 0
	fi

	if [ ! -f "${DST_GIT_HOOKS_DIR}/pre-commit" ] ; then
		WHY_STR="pre-commit hook is not a regular file"
		return 0
	fi

	local sha1_existing="$( { sha1sum "${DST_GIT_HOOKS_DIR}/pre-commit"    \
		| cut -d ' ' -f 1    \
		| grep -E -o '^[0-9A-Fa-f]{40}$' ; } || true)"
	if [ "${sha1_existing}" = "36aed8976dcc08b5076844f0ec645b18bc37758f" ] ; then
		WHY_STR="Replacing pre-commit.sample hook"
		return 0
	fi

	# Not needed
	return 1
}

delete_file_1()
{
	local fname="$1"

	rm -rf "${fname}.pendingdelete"

	if [ -e "${fname}" ] ; then
		mv "${fname}" "${fname}.pendingdelete"
		rm -rf "${fname}.pendingdelete"
	fi

	return 0
}

touch_stamp()
{
	if [ -z "${stamp_file}" ] ; then
		return 0
	fi

	${vecho} "INFO: ${PROGNAME}: updating stamp ${stamp_file}..."

	# NOTE: stamp must be at least 1 second newer than start time of this
	# script. ext2 and ext3 file systems store timestamps with 1 second
	# precision. ext4 and xfs use 1 ns precision.
	sleep 1

	touch "${stamp_file}"
	return 0
}

show_error_exit()
{
	echo "ERROR: ${PROGNAME}: could not setup hooks"    >&2
	return 1
}

do_setup_hooks()
{
	for fname in ${HOOKS_FILE_LIST} ; do
		delete_file_1 "${DST_GIT_HOOKS_DIR}/${fname}"
	done

	for fname in ${HOOKS_FILE_LIST} ; do
		cp -p "${SRC_DIR}/${fname}" "${DST_GIT_HOOKS_DIR}/${fname}"
	done

	for fname in ${HOOKS_FILE_LIST} ; do
		echo "${PROGNAME}: setting up ${DST_GIT_HOOKS_DIR}/${fname}"
		chmod +x "${DST_GIT_HOOKS_DIR}/${fname}"
	done

	return 0
}

# main

if ! parse_opts "$@" ; then
	exit 1
fi
shift $(( ${OPTIND} - 1 ))

trap show_error_exit EXIT

if ! may_setup_hooks ; then
	${vecho} "INFO: $PROGNAME: may not setup hooks (${WHY_STR})" >&2

	trap '' EXIT
	exit 0
fi

if ! setup_is_needed ; then
	${vecho} "INFO: $PROGNAME: hook setup is not needed" >&2

	touch_stamp
	trap '' EXIT
	exit 0
fi

echo "NOTICE: ${PROGNAME}: Activating pre-commit hook (reason: ${WHY_STR})" >&2

do_setup_hooks

touch_stamp
trap '' EXIT
${vecho} "INFO: $PROGNAME: DONE"
exit 0

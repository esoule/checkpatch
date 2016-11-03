#!/bin/sh
#
# An example hook script to verify what is about to be committed.
# Called by "git commit" with no arguments.  The hook should
# exit with non-zero status after issuing an appropriate message if
# it wants to stop the commit.
#
# To enable this hook, call this script from ".git/hooks/pre-commit".

PROGNAME="$(basename "$0")"
SETCOLOR_FAILURE=""
SETCOLOR_NORMAL=""
if [ -t 1 ] ; then
	# Output is going to a terminal
	SETCOLOR_FAILURE="$(echo -n -e "\e[0;31;01m")"
	SETCOLOR_NORMAL="$(echo -n -e "\e[0;39;49m\e[0;39m")"
fi

if git rev-parse --verify HEAD >/dev/null 2>&1
then
	against=HEAD
else
	# Initial commit: diff against an empty tree object
	against=4b825dc642cb6eb9a060e54bf8d69288fbee4904
fi

# If you want to allow non-ASCII filenames set this variable to true.
allownonascii=$(git config --bool hooks.allownonascii)

# Redirect output to stderr.
exec 1>&2

# Cross platform projects tend to avoid non-ASCII filenames; prevent
# them from being added to the repository. We exploit the fact that the
# printable range starts at the space character and ends with tilde.
if [ "$allownonascii" != "true" ] &&
	# Note that the use of brackets around a tr range is ok here, (it's
	# even required, for portability to Solaris 10's /usr/bin/tr), since
	# the square bracket bytes happen to fall in the designated range.
	test $(git --no-pager diff --cached --name-only --diff-filter=A -z $against |
	  LC_ALL=C tr -d '[ -~]\0' | wc -c) != 0
then
	cat <<\EOF
Error: Attempt to add a non-ASCII file name.

This can cause problems if you want to work with people on other platforms.

To be portable it is advisable to rename the file.

If you know what you are doing you can disable this check using:

  git config hooks.allownonascii true
EOF
	exit 1
fi

error_from_script=""

mark_problems_reported_by()
{
	error_from_script="${error_from_script}, \"${1:-}\""
	echo ""
	return 0
}

# Check for whitespace errors
git --no-pager diff-index --check --cached $against --

if [ $? -ne 0 ] ; then
	mark_problems_reported_by 'git diff --check --cached'
fi

git --no-pager diff -M --cached $against -- |    \
	./scripts/checkpatch.pl --show-types --quiet    \
		--spelling --max-line-length=96 /dev/stdin

if [ $? -ne 0 ] ; then
	mark_problems_reported_by './scripts/checkpatch.pl'
fi

show_check_info_message_10()
{
	cat <<EOF
NOTE:
*   This commit style checker is only a guide, not a replacement for
    human judgment. Take its advice with a grain of salt.
*   If any of the errors are false positives, you may bypass the check
    with "git commit --no-verify". Use this trick sparingly :-)

EOF
	return 0
}

show_check_error_message()
{
	cat <<EOF
ERROR: This commit has style problems.
ERROR: Please review and fix reported problems _before_ making the commit.

EOF
	return 0
}

show_check_info_message_20()
{
	return 0
}

if [ -n "${error_from_script}" ] ; then
	error_from_script=$(echo -n ${error_from_script} | sed -e 's/^,[ ]*//;')

	show_check_info_message_10

	show_check_error_message    \
		| sed -e "s/\$/${SETCOLOR_NORMAL}/; s/^/${SETCOLOR_FAILURE}/; "

	show_check_info_message_20

	exit 1
fi

exit 0

#!/bin/bash
#
# Do full-manifest and egencache for production use
#
# Usage:
# 1. Confirm PROD repo is in /etc/portage/repos.conf
# 2. Run this script in DEV repo

export LANG=C

# Detect git work dir
git_repo_path=`git rev-parse --show-toplevel 2>/dev/null`
if [ -z "${git_repo_path}" ]; then
	echo "Please run me in a git repo." >&2
	exit 1
fi
if [ "`git rev-parse --is-bare-repository`" = "true" ]; then
	echo "Bare repo not supported!" >&2
	exit 1
fi

repo_name=$(<${git_repo_path}/profiles/repo_name)

# Detect prod work dir
prod_repo_path=`portageq get_repo_path / $repo_name`
if [ -z "$prod_repo_path" ]; then
	echo "Repo $repo_name not exist in EROOT=/"
	exit 1
fi

# Prevent mistaken run under prod repo
if [ "$git_repo_path" = "$prod_repo_path" ]; then
	echo "Please run me under DEV repo." >&2
	exit 1
fi

# For commands require root privilege
if [ "$EUID" -ne 0 ]; then
	_sudo=sudo
else
	_sudo=
fi

rsync -rlcvhi --delete \
	--exclude-from="${git_repo_path}/scripts/manifest-rsync-exclude.files" \
	--exclude-from="${git_repo_path}/scripts/manifest-rsync-update.files" \
	"${git_repo_path}/" "${prod_repo_path}/" \
	|| { echo "!! rsync died with $?"; exit 1; }
rsync -rlcvhi --delete --update \
	--exclude "*" \
	--include-from="${git_repo_path}/scripts/manifest-rsync-update.files" \
	"${git_repo_path}/" "${prod_repo_path}/" \
	|| { echo "!! rsync died with $?"; exit 1; }

sed -i -e "/^thin-manifests *=/c \
thin-manifests = false" -e "/^sign-commits *=/c \
sign-commits = false" "${prod_repo_path}/metadata/layout.conf"

# Generate metadata
pushd "${prod_repo_path}" >/dev/null
repoman manifest
$_sudo egencache --repo $repo_name --update --update-use-local-desc \
	--update-pkg-desc-index -j`nproc` \
	|| { echo "!! egencache died with $?"; exit 1; }
# Time format: from portage.const import TIMESTAMP_FORMAT
prod_repo_need_update=`git status --porcelain`
[ -n "$prod_repo_need_update" ] && date -u "+%a, %d %b %Y %H:%M:%S +0000" \
	> metadata/timestamp.chk
popd >/dev/null

#!/bin/bash
#
# Do full-manifest and egencache for production use
#

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

# For commands require root privilege
if [ "$EUID" -ne 0 ]; then
	_sudo=sudo
else
	_sudo=
fi

rsync -rlcvhi --delete --exclude ".git" --exclude "Manifest" --exclude "/metadata/md5-cache" "${git_repo_path}/" "${prod_repo_path}/" || { echo "!! rsync died with $?"; exit 1; }
rsync -rlcvhi --delete --update --exclude ".git" --exclude "/metadata/md5-cache" "${git_repo_path}/" "${prod_repo_path}/" || { echo "!! rsync died with $?"; exit 1; }

sed -i -e "/^thin-manifests *=/c \
thin-manifests = false" -e "/^sign-commits *=/c \
sign-commits = false" "${prod_repo_path}/metadata/layout.conf"

pushd "$prod_repo_path"
repoman manifest || { echo "!! repoman died with $?"; exit 1; }

$_sudo egencache --repo $repo_name --update -j`nproc` || { echo "!! egencache died with $?"; exit 1; }

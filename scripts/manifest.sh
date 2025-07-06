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

rsync -rlcvhi --delete \
	--exclude-from="${git_repo_path}/scripts/manifest-rsync-exclude.files" \
	--exclude-from="${git_repo_path}/scripts/manifest-rsync-update.files" \
	"${git_repo_path}/" "${prod_repo_path}/" \
	|| { echo "!! rsync died with $?"; exit 1; }
rsync -rlcvhi --delete --update \
	--exclude-from="${git_repo_path}/scripts/manifest-rsync-exclude.files" \
	--include "*/" \
	--include-from="${git_repo_path}/scripts/manifest-rsync-update.files" \
	--exclude "*" \
	"${git_repo_path}/" "${prod_repo_path}/" \
	|| { echo "!! rsync died with $?"; exit 1; }

sed -i -e "/^thin-manifests *=/c \
thin-manifests = false" -e "/^sign-commits *=/c \
sign-commits = false" "${prod_repo_path}/metadata/layout.conf"

# Generate metadata
pushd "${prod_repo_path}" >/dev/null
pkgdev manifest

# From https://wiki.gentoo.org/wiki/Ebuild_repository#Cache_generation
#  and --regen in emerge(1). By searching "egencache" in wiki,
#  https://wiki.gentoo.org/wiki/Project:Portage/Repository_verification#Using_it
#  https://wiki.gentoo.org/wiki//var/db/repos/gentoo/metadata/md5-cache
# Currently (2025-07-06):
#  pkgcore-0.12.30 can't do egencache --update-manifests
#   pkgdev manifest can only work in thin-manifests repo
#  pkgcraft-tools-0.0.26 can't do egencache --update-pkg-desc-index \
#   --update-manifests
# Facts on ::gentoo (2025-07-06):
#  md5-cache generated from egencache and pmaint have differences \
#   in order of _eclasses_ . So we can infer from that:
#  [sync-type: rsync, webrsync] sources are using egencache
#  [sync-type: git (gentoo-mirror/gentoo)] source is applying pmaint
# Use pmaint for md5-cache generation, egencache for the rest.
# We prefer this only because it gets rid of running as root.
pmaint regen "${repo_name}" -t`nproc` \
	|| { echo "!! pmaint died with $?"; exit 1; }
# --update-pkg-desc-index reads md5-cache
egencache --repo $repo_name --update-use-local-desc --update-pkg-desc-index \
	--update-manifests -j`nproc` \
	|| { echo "!! egencache died with $?"; exit 1; }

# egencache --write-timestamp or pmaint regen --rsync are not used
# because we want timestamp.chk to get updated only when there are updates.
# Time format: from portage.const import TIMESTAMP_FORMAT
prod_repo_need_update=`git status --porcelain`
[ -n "$prod_repo_need_update" ] && date -u "+%a, %d %b %Y %H:%M:%S +0000" \
	> metadata/timestamp.chk
# git commit with pkgdev and egencache version
popd >/dev/null

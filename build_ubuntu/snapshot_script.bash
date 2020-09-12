#!/bin/bash

# 2020 Bernd Pfrommer
#
# script for automated snapshot builds for GTSAM using
# git-build-package (gbp)

# url of PPA to upload to, e.g 'ppa:my-ppa/gtsam-snapshot'
ppa=$1

# vendor (currently only "ubuntu" has been tested/supported)
vendor=$2

# This is the release on which this snapshot is based, e.g. "4.1.0".
# Determines which pristine tarball is used.
snapshot_base=$3

# url of the repo where the upstream sources (develop branch) are fetched from
upstream=$4

# set the gpg key
gpg_key=$5

# print some debugging info
echo "snapshot for $snapshot_base ($vendor) upstream: $upstream to ppa: $ppa"
echo 'current working directory:' `pwd`
ls -la
export GNUPGHOME=build_ubuntu/.gnupg
echo '----- repository public keys ------'
gpg --list-public-keys
echo '----- repository secret keys ------'
gpg --list-secret-keys --keyid-format SHORT
echo "using key: $gpg_key"

# (restore the .gnupg directory in case gpg has made any changes to it 
git checkout $GNUPGHOME

# set upstream
git remote add upstream $upstream
# fetch the upstream development branch
git fetch upstream develop    # get the latest development branch

# get the latest hash so we can check if we already processed this one
git_hash=`git log -1 --pretty=format:"%H" upstream/develop`

# this is the user under which the commits will be reported
git config --global user.email "joe.shmoe@foo.bar"
git config --global user.name "Joe Shmoe"

# grab the snapshot branch from the origin repo.
# It will get us to where we left off, i.e. when the last snapshot was run
git fetch origin ${vendor}/snapshot

echo 'checking out last snapshot'
git checkout ${vendor}/snapshot  # switch to snapshot tracking branch

hash_store_file=debian/git_last_snapshot_hash.txt
if grep -q $git_hash "$hash_store_file"; then
    echo "snapshot of $git_hash was already taken, aborting!"
    exit 0
fi

# retrieve the pristine tarball from the pristine-tar branch
git fetch origin pristine-tar:pristine-tar
gbp export-orig --pristine-tar

# merge in the changes new in the develop branch
# (for testing purposes, you can here checkout an older version of
#  the development tree, and work your way forward by several commits
# git merge 915702116f7316bdb6f9b0a512d26eea3d49600b -m "merge test commit")
git merge upstream/develop -m "merge develop branch"

# update changelog to capture all the changes between now and last time
# The 'snapshot' feature automatically increments the version number
# from the changelog file. It also sets the distribution to UNRELEASED,
# no matter what you pass in as "distribution".
gbp dch --debian-branch=${vendor}/snapshot --distribution=UNRELEASED --snapshot --git-author

# get the new snapshot version from changelog
snap=`head -1 debian/changelog | sed 's/.*[(]//g; s/[)].*//g'`

# remove all previous patches so they don't collide with the new ones,
# which are computed between the version stored in the pristine tar
# ball and the current snapshot.
git rm -r debian/patches/*

# now build patch file for difference between pristine -> snapshot
# (must disable editor to get away without commit message)
EDITOR=/bin/true dpkg-source --commit . ${snap}.patch
rm -rf .pc # remove this automatically created directory to avoid error

# commit updated changelog and patch file
git add debian/changelog debian/patches/*
git commit -a -m "updated changelog and patch files for snapshot $snap"

#
# loop over distros so we can bump the version number for each one
#
for distro in xenial bionic focal
do
    # remove any old build files
    rm -f ../gtsam_*.dsc ../gtsam_*.build ../gtsam_*.buildinfo ../gtsam_*.changes ../*.upload

    # in-place replace of UNRELEASED; with specific distro in changelog file.
    # the -z option only replaces the first occurence
    sed -i -z "s/UNRELEASED\;/${distro}\;/g" debian/changelog
    # must commit changes to the changelog file or else the buildpackage
    # will barf
    git add debian/changelog
    git commit -m "modified changelog for distro $distro"
    # this will actually build the source package, i.e. create the
    # stuff that can be uploaded to ubuntu's ppa farm for building
    gbp buildpackage -k${gpg_key} -S -sa --git-debian-branch=${vendor}/snapshot

    # upload to ubuntu ppa server for building
    pushd .. ; dput "$ppa" gtsam_*_source.changes; popd
    
    # now update the changelog to capture the new commits. This will
    # also bump the snapshot version for the next distro, which
    # needs to happen because the ubuntu build server will reject
    # anything that does not have an increasing version number over the
    # previously uploaded source package
    gbp dch --debian-branch=${vendor}/snapshot --distribution=UNRELEASED --snapshot --git-author

    # update snapshot version, which will be used in the next iteration
    snap=`head -1 debian/changelog | sed 's/.*[(]//g; s/[)].*//g'`
done

# keep the git hash of the point where we just took the snapshot
# (comment out this line for testing!)
#echo $git_hash > $hash_store_file

# commit the final snapshot number to the changelog so we have it
# next time we run this script
git add debian/changelog $hash_store_file
git commit -m "commit of final snapshot version number update"

# finally, push the changes to the snapshot branch back home
git push origin ${vendor}/snapshot

# gtsam-packaging

Repository with instructions and scripts related to building
packages for Debian based systems.

The following instructions have been tested on Ubuntu 18.04LTS (bionic):

## Setup

Install some packages needed for building the package:

    sudo apt install git-buildpackage pristine-tar

Get this repo, make gtsam the upstream repo, and fetch the "develop"
branch from there

    git clone https://github.com/borglab/gtsam-packaging.git
	cd gtsam-packaging
    git remote add upstream https://github.com/borglab/gtsam.git
	git fetch upstream develop

## About GPG keys

You need to have a secret gpg key set up to build and sign a source package:

    gpg --list-secret-keys --keyid-format SHORT

The key id is the 8-byte hex number right after "rsaNNN/":

    sec   rsa3072/C50C547F 2020-05-19 [SC]
          921389CD8281C9B5A463C9D18CAF5F59C50C547F
    uid         [ultimate] Bernd Pfrommer (Ubuntu PPA) <bernd.pfrommer@gmail.com>
    ssb   rsa3072/5D91D951 2020-05-19 [E]

So in this case it's ``C50C547F``. You must have that key deposited beforehand with the ubuntu keyserver, and activated on launchpad (see instructions there), so in this case:

    gpg --send-keys --keyserver keyserver.ubuntu.com C50C547F

The instructions following below specify a GPG key, so let's set a variable for it (prepended with 0x):

    gpg_key=0xC50C547F


## Branch layout

The gtsam-packaging repo has these branches:

- master: the branch with the documentation

- pristine-tar: this branch is automatically maintained by git
  buildpackage (gbp). Whenever you release a new version of gtsam,
  i.e. one that has a different version number (e.g. 4.0.2), a tarball
  is produced (e.g. ``gtsam_4.0.2.orig.tar.gz``) and stored in this
  branch.

- ubuntu/{xenial,bionic,focal}: these branches mirror the
  "develop" branch, but have additionally the packaging files in the
  "debian" subdirectory, and any changes to the original source
  code necessary for packaging. Ideally there should be no changes
  necessary to the gtsam source files. Any such changes must be
  captured as patches (see below).

## Creating a release

Create the branch with the right tag. This will create a new branch
that has the commits up to tag 4.0.2.

    version=4.0.2
    vendor=ubuntu
    distro=xenial

    git fetch upstream --tags


### Creating a release for the first time

    git checkout -b ${vendor}/${distro} $version

Now hack away on that branch, make any changes that you have to, both
to the "debian" directory and the sources itself (e.g. CMakeFiles etc).

When done, update the changelog:

    gbp dch --debian-branch=${vendor}/${distro} --release --upstream-tag='%(version)s' --distribution=${distro} --git-author

At this point git commit all changes to the source files (not the
debian directory) to the $vendor/$distro branch. Then commit the
changes to the debian files as well, in a separate commit.

If you have made any changes to the sources (except in the debian
directory), the following attempt to build a source package  will
fail. But it will succeed in creating a pristine tar ball, from which
you can generate a patch file.

    gbp buildpackage -k${gpg_key} -S -sa --git-pristine-tar --git-pristine-tar-commit --git-upstream-tag='%(version)s' --git-debian-branch=${vendor}/${distro}


To generate the patches (adjust name of patch file to your needs:

    dpkg-source --commit . 000-fix-cmakefiles.patch

This generates the patch file. Commit it and restore your repo to good state:

    git add debian/patches/series debian/patches/*.patch
	git commit -m "added patch files"
    git checkout .
	
This time the build should succeed, because now the difference between
pristine tarball and sources is captured in the patch file:

    gbp buildpackage -k${gpg_key} -S -sa --git-pristine-tar --git-pristine-tar-commit --git-upstream-tag='%(version)s' --git-debian-branch=${vendor}/${distro}

This should leave you with a bunch of files in the directory *above*
the source directory.

## Upload to Ubuntu PPA

To upload to your ppa:

    cd ..   # (one up from source directory)
    dput "ppa:my-name/my-ppa-name" gtsam_*_source.changes




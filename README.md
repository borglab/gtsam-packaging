# gtsam-packaging

Repository with instructions and scripts related to building
packages for Debian based systems.

The following instructions have been tested on Ubuntu 18.04LTS (bionic):

## Setup

Install some packages needed for building the package:

    sudo apt install git-buildpackage pristine-tar

*Fork* this repo on github, make gtsam the upstream repo, and fetch
the "develop" branch from there

    git clone https://github.com/YOUR_GITHUB_NAME/gtsam-packaging.git
    cd gtsam-packaging
    upstream=https://github.com/borglab/gtsam.git
    git remote add upstream $upstream
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

- ubuntu/release: this branch mirrors the
  "develop" branch, but also has the packaging files in the
  "debian" subdirectory, and any changes to the original source
  code necessary for packaging. Ideally there should be no changes
  necessary to the gtsam source files. Any such changes must be
  captured as patches (see below).

## Creating a release

First have a look at the tags that have been created in the gtsam repo:

    git fetch upstream --tags

Now find the latest release tag, e.g. "4.0.3", and set a variable for it:

    version=4.0.3
    vendor=ubuntu
    distro=xenial

### Creating a release from scratch (this is uncommon!)

You usually always have a ``${vendor}/release`` packaging branch in
the ``origin`` repo, but in case you don't have that, you need to make
a new branch and create the packaging directory (e.g. ``debian``) from
scratch:

    git checkout -b ${vendor}/release $version

Then follow the instructions for preparing the package build.

### Updating the packaging branch

Next, update the packaging branch to capture all the changes in the
development branch:

    git merge upstream/develop $version

Resolve any conflicts and commit the changes


### Preparing the package build

Now hack away on the ``${vendor}/release`` branch, make any changes
that you have to, both to the "debian" directory and the sources
itself (e.g. CMakeFiles etc). Ubuntu packages are uploaded in *source*
form to the PPA server, and get built there on Canonical's server
farm. To test locally if stuff builds, do this:

    cd gtsam-packaging
    debuild -b -us -uc

This will build the package, but also generate a lot of temporary
files in the debian directory which you need to remove again.

When everything looks good, update the changelog:

    gbp dch --debian-branch=${vendor}/release --release --upstream-tag=refs/tags/'%(version)s' --distribution=${distro} --git-author

At this point git commit all changes to the source files (not the
debian directory) to the $vendor/release branch. Then commit the
changes to the debian files as well, in a separate commit.

If you have made any changes to the sources (except in the debian
directory), the following attempt to build a source package  will
fail. But it will succeed in creating a pristine tar ball, from which
you can generate a patch file.

    gbp buildpackage -k${gpg_key} -S -sa --git-pristine-tar --git-pristine-tar-commit --git-upstream-tag='%(version)s' --git-debian-branch=${vendor}/release


To generate the patches (adjust name of patch file to your needs:

    dpkg-source --commit . 000-fix-cmakefiles.patch

This generates the patch file. Commit it and restore your repo to good state:

    git add debian/patches/series debian/patches/*.patch
	git commit -m "added patch files"
    git checkout .
	
This time the build should succeed, because now the difference between
pristine tarball and sources is captured in the patch file:

    gbp buildpackage -k${gpg_key} -S -sa --git-pristine-tar --git-pristine-tar-commit --git-upstream-tag='%(version)s' --git-debian-branch=${vendor}/release

This should leave you with a bunch of files in the directory *above*
the source directory. These can now be uploaded into your ppa (see below).


## Creating releases for other distros

Once you have a GTSAM release created for one Ubuntu release
(e.g. xenial), it's easy to create another one. You need to leave the
original tar ball in place from the previous packaging steps.
When you update the changelog and are prompted for a release update,
make sure you update the ubuntu version every time you bump the
release, i.e. -1ubuntu2, -1ubuntu3 etc.

    distro=bionic
    gbp dch --debian-branch=${vendor}/release --release --upstream-tag='%(version)s' --distribution=${distro} --git-author
	git commit -a
    gbp buildpackage -k${gpg_key} -S --git-pristine-tar --git-pristine-tar-commit --git-upstream-tag='%(version)s' --git-debian-branch=${vendor}/release


## Creating snapshot releases

If you want to run nightly snapshots, you can use ``dch`` to
auto-generate an increasing version number, and update the changelog
so you can see what commits have been made since the previous
snapshot. [Here is the relevant documentation](https://honk.sigxcpu.org/projects/git-buildpackage/manual-html/gbp.snapshots.html). 

Note: while ``dch`` offers many ways to generate a snapshot version
number, you must take care that it is strictly monotonically
increasing, or Ubuntu's build server will balk. The simplest way is to
run dch with only the ``--snapshot`` argument as shown below
(assuming you have named your snapshot branch ``$vendor/snapshot``).

The Ubuntu always wants to work off of a ``pristine`` tar ball. In the following, the pristine tar ball is set to be the one from the last release (``$version``):

    # create the pristine tar ball from the last release
	pristine-tar checkout ../gtsam_${version}.orig.tar.gz
	git checkout ${vendor}/snapshot  # switch to snapshot tracking branch
    git fetch upstream develop    # get the latest development branch
	git merge upstream/develop    # merge latest dev branch into snapshot
	# now build patch file for difference between snapshot -> release
	# update changelog
    gbp dch --debian-branch=${vendor}/snapshot --snapshot --git-author
	# get snapshot version from changelog
	snap=`head -1 debian/changelog | sed 's/.*[(]//g; s/[)].*//g'`
    dpkg-source --commit . ${snap}.patch
	# commit updated changelog
	git commit -a -m "updated to snapshot to $snap"
	# commit the patches to the debian directory
    git add debian/patches/series debian/patches/*.patch
	git commit -m "added patch files for $snap"
    git checkout .
	rm -rf .pc    # remove to avoid package build error
	# push changes made to snapshot tracking branch
	git push origin ${vendor}/snapshot
	# build package
	gbp buildpackage -k${gpg_key} -S -sa --git-debian-branch=${vendor}/snapshot
	# now you should be able to upload the package to your ppa

## Upload to Ubuntu PPA

To upload to your ppa:

    cd ..   # (one up from source directory)
    dput "ppa:my-name/my-ppa-name" gtsam_*_source.changes




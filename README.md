# The GTSAM packaging repository

This repo has instructions, scripts, packaging branches, and github
workflow  files for automatic creation of Ubuntu/Debian source
packages. These source packages are uploaded to a Ubuntu
Personal Package Archive (PPA) from where they can be installed on any
Ubuntu based distro via apt-get install. 

## How to set up packaging for your own GTSAM PPA

The process to set up nightly GTSAM snapshot builds requires the
following steps:

- creating a github packaging repo
- setting up a secret GPG key for github and the Ubuntu PPA
- setting the GPG key as a secret for the github repo
- creating a Ubuntu PPA and depositing the GPG key there
- modifying your packaging repo and pushing it to github

The steps are outlined below.

### Create a new github repo for the packaging

Create a new gtsam packaging git repo on github, for instance
``https://github.com/mygithubname/gtsam-packaging.git``.  This is the
repo that will trigger the nightly snapshot builds and holds the
packaging data. For now it just needs to be created. Content will be
pushed to it in the last step, when all the other pieces are in
place.

### Set up a GPG key for Ubuntu packaging

Create up a [GPG key](https://packaging.ubuntu.com/html/getting-set-up.html) *without* 
passphrase, and give as email *the same one you use on your github
account*:

    gpg --full-generate-key
    gpg --list-secret-keys

Send the fingerprint of your GPG key to Ubuntu's keyserver (the
fingerprint is the long string from the gpg output):

    gpg --send-keys --keyserver keyserver.ubuntu.com <your_key_fingerprint_here>

Armor the key:

     gpg --armor --export-secret-key <your_key_fingerprint_here>

The output will need to be cut-and-pasted (see next step)

### Deposit the secret GPG key on github

Now go to your github GTSAM packaging repo (created in the first
step), and create a "secret" under the repo. Note: do *not* deposit
the key as a GPG key under your *user*, but add it as a secret to the
particular GTSAM packaging repo created earlier, e.g.
``gtsam-packaging``.  There, create a secret called "GPG_PRIVATE_KEY"
and cut and paste the armored key, including begin/end lines into the
field below the secret.

### Set up a Ubuntu Personal Package Archive (PPA):

1. Log on or create an account at [Ubuntu Launchpad](https://launchpad.net/)
2. Create a new PPA, call it for example gtsam-nightly-snapshot
3. For the new PPA, click on "change details", and under "Processors",
   select all architectures that you want to support. The important
   ones are AMD x86-64 and the entire ARM family. Hit "Save" at the
   bottom to apply the changes. 
4. Click on your user name at the top right corner, then on the little
   icon next to the "OpenPGP keys". 
5. If not done already, send the fingerprint of your GPG key to
   Ubuntu's keyserver (the fingerprint is the long string returned on
   the second line by ``gpg --list-secret-keys``):

        gpg --send-keys --keyserver keyserver.ubuntu.com <your_key_fingerprint_here>

6. Cut and paste the fingerprint of your GPG private key into the
   "Fingerprint" field and hit "Import Key". Launchpad may ask you to log
   in again. Note this step will fail if you did not register the key
   before (step 5). Sometimes it takes a while for the ubuntu keyserver
   to accept it, so you may have to retry several times.
7. Once you eventually succeed, you will get a notice that a message
   has been sent to your email address. In your email you 
   will find an encrypted message that you need to decrypt. You can do so
   by cut-and-pasting everything starting and ending with (*including*)
   the BEGIN and END PGP MESSAGE markers into a file, e.g. "info.txt",
   and then decrypting it via:

        gpg --decrypt info.txt

8. Follow the link at the bottom of the message to confirm your GPG key
   with Launchpad. It may fail due to the keyserver not having the key
   processed yet, just retry a few times. Eventually it will say "was
   successfully validated", and you are ready to upload ppa packages with
   this key.

### Modify and push the packaging repo

1. Clone the packaging repo

        git clone https://github.com/borglab/gtsam-packaging.git


2. In the newly cloned directory, edit the last line of ``.github/workflows/main.yml``:
   
        run: ./build_ubuntu/snapshot_script.bash -p ppa:my-ppa-username/my-gtsam-ppa-name -v ubuntu -b 4.1.0 -u https://github.com/borglab/gtsam.git -k <my_gpg_secret_key_fingerprint> -n "My Name"  -e my.email@wherever.org

   Adjust the name of the ppa, the secret key fingerprint, your name,
   and email. For example to:

        run: ./build_ubuntu/snapshot_script.bash -p ppa:bernd-pfrommer/gtsam-nightly-snapshot -v ubuntu -b 4.1.0 -u https://github.com/borglab/gtsam.git -k 19590B214BBF6D3D5F560011D0473D3A886C2BFD -n "Bernd Pfrommer"  -e bernd.pfrommer@gmail.com

3. Git commit the changes:

        git commit -a -m "adjusted workflow file"

4. Add the necessary remote references (adjust the first line to point
   to your repo!) and push:

        git remote set-url origin https://github.com/mygithubname/gtsam-packaging.git
		git remote add borglab https://github.com/borglab/gtsam-packaging.git
		git fetch --all
        git push origin 'refs/remotes/borglab/*:refs/heads/*'

   The last line will copy all branches of this repo over to yours,
   giving you a working setup.

5. One more thing: push the adjusted workflow files:

        git push origin master

That's it! Now check your repo on github (under "Actions") to see that everything builds and uploads correctly.


## Details of the building process

### Ubuntu PPA packaging and pristine tar balls
Making a package available in a Ubuntu PPA consists of several steps:
- Obtain a "pristine" tar ball from the original developers of a
  project. The tarball contains the original sources and build files.
- Add the "debian" directory which describes the package, has a
  changelog, and parameters for building e.g. flags
  that should be passed to cmake.
- Potentially modify the original project files, for
  instance to fix cmake problems. Capture these changes as patches with
  respect to the pristine tar ball
- build the debian source package. The source package has the debian
  directory containing building instructions and patches.
- sign and upload the pristine tar ball to the PPA
- sign and upload the debian *source* package to the PPA.

Note that we are dealing only with sources here. The actual building
happens on the build servers once the debian package has been
uploaded.

### About version numbers
The following statements reflect the authors limited understanding of
Ubuntu packaging, and should be taken with a grain of salt.

For each version number (e.g. 4.0.3) you can only upload a single
pristine tarball *once*. All subsequent further modifications that you
have to make (oops, another little bug fix) must be stored as patches
relative to that pristine tarball you uploaded the first time. At the
time of this writing there is no way to get rid of that tarball except
deleting the ppa! 

Also, there is only *one* version available per PPA per major release
number. So if you upload 4.1.0-1 after 4.0.3-5, then 4.0.3-5 will be
*gone*, and only 4.1.0-1 will be available for install via apt.

Further, version numbers have to strictly increase, or else the upload
will be rejected. This means you cannot easily roll back to an older
version number. Instead, you have to submit the old package under a
new version number.

### What is git-buildpackage (gbp) used for?

GTSam is not delivered as a tar ball but is hosted on a public git
repository. For this reason it makes sense to create the debian source
packages directly from the git source tree using [git-buildpackage
(gbp)](http://honk.sigxcpu.org/projects/git-buildpackage/manual-html/gbp.html).
Git-buildpackage is a script that facilitates creating debian source
packages from git source trees.  For instance it can create, commit,
and check out the pristine tar ball for a given version number. By
calling debian packaging scripts, gbp automatically creates
changelogs, patches, and increasing version numbers for the nightly
snapshots.


### What are the different branches in this repo for?
The gbp commands interact with several branches to
accomplish this:

- The "upstream" branch ``upstream develop``. This remote branch
  typically points to the ``develop`` branch of borglab's gtsam
  repo. From here any commits by the GTSAM developers are fetched.
- The build-package branch: ``origin ubuntu/snapshot``. This branch
  holds the nightly snapshots containing the ``upstream develop``
  branch *and* the debian directory for packaging. An automated script
  merges any changes that happen in ``upstream develop`` into this
  branch.
- The pristine-tar branch: ``origin pristine-tar``. Contains the
  pristine tar balls used as basis for PPA uploads.
- The master branch ``origin master``. This branch has only
  instructions, nightly packaging scripts, and github workflow files
  to trigger automatic package building.
  

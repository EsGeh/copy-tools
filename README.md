# copy-tools

Experimental scripts for copying directories and making incremental backups. Based on rsync.
One of source and destination may be non-local.

Work in progress. Use at your own risk.
Feedback welcome.

## Features

General:

- Sensible default settings
- Logging
- Automated tests

For backups:

- reasonably named subdirs and logs
- Interrupted backups are continued
- Save space on destination using hardlinks

## Supported Operation Systems

- Linux

Might work on other OSes if all dependent tools are provided. So far only tested on Linux.

## Dependencies

- [fishshell-cmd-opts](https://github.com/EsGeh/fishshell-cmd-opts)
- [rsync](https://rsync.samba.org/)
- [OpenSSH](https://www.openssh.com/) (only for non-local copying)
- tree (linux command line utility) (only for running the tests)

## Installation

### On arch linux: install using pacman

- clone the repository
- create package for pacman:

		$ makepkg

- install it:

		$ makepkg -i

### Install manually

The scripts can be installed to some directory that is in your PATH.

## Implementation

The provided scripts are basically wrappers around *rsync*.

## Provided commands

- `ct-copy.fish`: copy files with reasonable defaults
- `ct-backup.fish`: backup a directory to another location with reasonable defaults. SRC MUST be local, DST can be remote.

## Usage

The provided commands are copy tools which copy data from some `SRC` to a `DST`. Both, `SRC` and `DST` are given as paths. One of those can be a remote location in which case it is given in syntax rsync (or scp) understands.

- Example: Copy `A` to `B`, both local dir:

		$ ct-copy.fish /some/path/A /some/otherpath/B

- Example: Copy `C` to `D`, D is a path on a remote machine reachable via ssh using username `user` at address `remote`

		$ ct-copy.fish /some/path/C user@remote:/some/otherpath/B

For further details append the the `--help` option to the command in question.

## Avoid typing SSH Logins and Passphrases

When copying between remote locations, ssh has to be correctly configured.
To avoid cumbersome typing, I'd recommend to:

- Use RSA keys instead of password logins (also for the sake of security)
- To avoid repeatedly typing ssh passphrases (especially in tests), use `ssh-agent`

Example:

Let's assume you have configured SSH to use RSA keys. To avoid typing the passphrase, issue:

	$ ssh-agent $SHELL
	$ ssh-add
	... (enter passphrase)

Now the passphrase is in memory and doesn't need to be typed.

## Tests

Run automated tests before using in a real world situation!
Also don't forget to run tests with one of the locations being remote (see `--help`)!

To run the automated tests...:

- if scripts are installed into $PATH:

		$ ct-test-copy.fish
		$ ct-test-backup.fish

- if scripts not in $PATH:

		$ ./ct-test-copy.fish -i .
		$ ./ct-test-backup.fish -i .

For further details append the the `--help` option to the command in question.

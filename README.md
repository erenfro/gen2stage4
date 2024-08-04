# gen2stage4

![CI](https://github.com/erenfro/gen2stage4/workflows/CI/badge.svg)
[![GitHub release](https://img.shields.io/github/release/erenfro/gen2stage4.svg)](https://GitHub.com/erenfro/gen2stage4/releases/)
[![Gentoo package](https://repology.org/badge/version-for-repo/gentoo/gen2stage4.svg?header=Gentoo)](https://repology.org/project/gen2stage4/versions)
[![LiGurOS package](https://repology.org/badge/version-for-repo/liguros_stable/gen2stage4.svg?header=LiGurOS)](https://repology.org/project/gen2stage4/versions)

This is a Bash script which creates “stage 4” tarballs (i.e. system archives) either for the running system, or a system at a specified mount point.
The script was inspired by an earlier [mkstage4 script](https://github.com/gregf/bin/blob/master/mkstage4) by Greg Fitzgerald (unmaintained as of 2012) which itself was a revamped edition of the [original mkstage4](http://blinkeye.ch/dokuwiki/doku.php/projects/mkstage4) by Reto Glauser (unmaintained as of 2009).

## Installation

The script can be run directly from its containing folder (and thus, is installed simply by downloading or cloning it from here - and adding run permissions):

```bash
git clone https://github.com/erenfro/gen2stage4.git /your/gen2stage4/directory
cd /your/gen2stage4/directory
chmod +x gen2sync gen2extract gen2stage4
```

For [Gentoo Linux](http://en.wikipedia.org/wiki/Gentoo_linux) and [Derivatives](http://en.wikipedia.org/wiki/Category:Gentoo_Linux_derivatives), gen2stage4 is also available in [Portage](http://en.wikipedia.org/wiki/Portage_(software)) via the base Gentoo overlay.
On any Gentoo system, just run the following command:

```bash
emerge app-backup/gen2stage4
```

## Usage

*If you are running the script from the containing folder (first install method) please make sure you use the e.g. `./gen2stage4` command instead of just `gen2stage4`!*

Note that the extension (e.g. `.tar.xz`) will be automatically appended to the `archive_name` string which you specify in calling the `gen2stage4` command.
This is done based on the compression type, which can be specifiled via the `-C` parameter, if another compression than the default (`bz2`, creating files ending in `.tar.bz2`) is desired.

### Examples

Archive your current system (mounted at /):

```bash
gen2stage4 -s archive_name
```

Archive a system located at a custom path:

```bash
gen2stage4 -t /custom/path archive_name
```

Copy a system to a separate drive, e.g. for quick backup.

```bash
gen2sync -s /run/media/myuser/mybackupdrive
```

Copy a system located at a custom path:

```bash
gen2sync -t /custom/path /run/media/myuser/mybackupdrive
```

### Command line arguments

```console
Usage:
gen2stage4 [-b -c -k -l -q] [-C <type>] [-s || -t <target>] [-e <exclude>...] [-i <include>...] <archive> [-- [tar-opts]]
Position Arguments:
    <archive>    archive name to create with optional path
    [tar-opts]   additional options to pass to tar command

Options:
    -b           excludes boot directory
    -c           excludes some confidential files (currently only .bash_history and connman network lists)
    -k           separately save current kernel modules and src (creates smaller targetArchives and saves decompression time)
    -l           includes lost+found directory
    -q           activates quiet mode (no confirmation)
    -C <type>    specify tar compression (default: ${optCompressType}, available: ${!compressAvail[*]})
    -s           makes archive of current system
    -t <path>    makes archive of system located at the <path>
    -e <exclude> an additional exclude directory (one dir one -e, do not use it with *)
    -i <include> an additional include. This has higher precedence than -e, -t, and -s
    -h           display this help message.
```

## System Tarball Extraction

### Automatic (Multi-threaded)

Provides is a script for convenient extraction, `gen2extract`, which is shipped with this package. Currently it simply automates the Multi-threaded extraction selection listed below and otherwise has no functionality except checking that the file name looks sane.
If in doubt, use one of the explicit extraction methods described below. Otherwise, you can extract an archive inplace with:

```bash
gen2extract -s archive_name.tar.bz2
```
To extract in the current directory, or:

```bash
gen2extract -t /target/path archive_name.tar.bz2
```
To extract to the target path.

### Explicit Single-threaded

Archives created with gen2stage4 can also be extracted with tar as well.

To preserve binary attributes and use numeric owner identifiers, you can simply append the relevant flags to the respective `tar` commands, e.g.:

```bash
tar xvpf archive_name.tar.bz2 --xattrs-include='*.*' --numeric-owner
```
To extract in the current directory, or:
```bash
tar xvpf archive_name.tar.bz2 --xattrs-include='*.*' --numeric-owner -C /target/path
```
To extract to the target path.

If you use the `-k` option, extract the `src` and modules archives separately:

```bash
tar xvpf archive_name.kmod.tar.bz2
tar xvpf archive_name.ksrc.tar.bz2
```

### Explicit Multi-threaded

If you have a parallel de/compressor installed, you can extract the archive with one of the respective commands:

#### `pbzip2`

```bash
tar -I pbzip2 -xvf archive_name.tar.bz2 --xattrs-include='*.*' --numeric-owner
```

#### `xz`

```bash
tar -I 'xz -T0' -xvf archive_name.tar.xz --xattrs-include='*.*' --numeric-owner
```

#### `gzip`

Similarly to other compressors, `gzip` uses a separate binary for parallel decompression:

```bash
tar -I unpigz -xvf archive_name.tar.gz --xattrs-include='*.*' --numeric-owner
```

#### `zst`

```bash
tar -I 'zstd -T0' -xvf archive_name.tar.gz --xattrs-include='*.*' --numeric-owner
```

## Dependencies

*Please note that these are very basic dependencies and should already be included in any Linux system.*

* **[Bash](https://www.gnu.org/software/bash/)** - in [Portage](http://en.wikipedia.org/wiki/Portage_(software)) as **[app-shells/bash](https://packages.gentoo.org/packages/app-shells/bash)**
* **[tar](https://www.gnu.org/software/tar/)** - in Portage as **[app-arch/tar](https://packages.gentoo.org/packages/app-arch/tar)**
* **[xz](https://tukaani.org/xz/)** - in Portage as **[app-arch/xz](https://packages.gentoo.org/packages/app-arch/xz-utils)**, (parallel, default compression)
* **[rsync](https://rsync.samba.org/)** - in Portage as **[net-misc/rsync](https://packages.gentoo.org/packages/net-misc/rsync)** (used by gen2sync)

**Optionals**:
*If one the following is installed the archive will be compressed using multiple parallel threads when available, in order of succession:*

* `-C xz`:
  * **[xz](https://tukaani.org/xz/)** - in Portage as **[app-arch/xz](https://packages.gentoo.org/packages/app-arch/xz-utils)**, (parallel, default compression)
  * **[pixz](https://github.com/vasi/pixz)** - in Portage as **[app-arch/pixz](https://packages.gentoo.org/packages/app-arch/pixz)**, (parallel, indexed)

* `-C bz2`:
  * **[bzip2](https://gitlab.com/federicomenaquintero/bzip2)** - in Portage as **[app-arch/bzip2](https://packages.gentoo.org/packages/app-arch/bzip2)** (single thread)
  * **[pbzip2](https://launchpad.net/pbzip2/)** - in Portage as **[app-arch/pbzip2](https://packages.gentoo.org/packages/app-arch/pbzip2)**, (parallel)
  * **[lbzip2](https://github.com/kjn/lbzip2/)** - in Portage as **[app-arch/lbzip2](https://packages.gentoo.org/packages/app-arch/lbzip2)**, (parallel, faster and more efficient)

* `-C gz`:
  * **[gzip](https://www.gnu.org/software/gzip/)** - in Portage as **[app-arch/gzip](https://packages.gentoo.org/packages/app-arch/gzip)**, (single thread)
  * **[pigz](https://www.zlib.net/pigz/)** - in Portage as **[app-arch/pigz](https://packages.gentoo.org/packages/app-arch/pigz)**, (parallel)

* `-C lrz`:
  * **[lrzip](https://github.com/ckolivas/lrzip/)** - in Portage as **[app-arch/lrzip](https://packages.gentoo.org/packages/app-arch/lrzip)**, (parallel)

* `-C lz`:
  * **[lzip](https://www.nongnu.org/lzip/)** - in Portage as **[app-arch/lzip](https://packages.gentoo.org/packages/app-arch/lzip)**, (single thread)
  * **[plzip](https://www.nongnu.org/lzip/plzip.html)** - in Portage as **[app-arch/plzip](https://packages.gentoo.org/packages/app-arch/plzip)**, (parallel)

* `-C lz4`:
  * **[lz4](https://github.com/lz4/lz4)** - in Portage as **[app-arch/lz4](https://packages.gentoo.org/packages/app-arch/lz4)**, (parallel)

* `-C lzo`:
  * **[lzop](https://www.lzop.org/)** - in Portage as **[app-arch/lzop](https://packages.gentoo.org/packages/app-arch/lzop)**, (parallel)

* `-C zst`:
  * **[zstd](https://facebook.github.io/zstd/)** - in Portage as **[app-arch/zstd](https://packages.gentoo.org/packages/app-arch/zstd)**, (parallel)

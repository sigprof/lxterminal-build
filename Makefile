# Default target.
#
# Using `install` by default seems strange, but the problem is that building
# the `lxterminal` project requires the library from the `vte` project to be
# installed into its final location, and this will change the behavior of the
# installed `lxterminal` executable even without installing a rebuilt version,
# so immediately rebuilding and installing a matching `lxterminal` executable
# should be better.
#
all: install
.PHONY: all

# Installation location.
#
# `USER_BIN` and `USER_OPT` values may be taken from environment variables
# (e.g., for compatibility with multiple architectures or OS installations
# using the same home directory).
#
USER_BIN ?= $(HOME)/bin
USER_OPT ?= $(HOME)/opt
prefix = $(USER_OPT)/lxterminal

# Useful string constants.
nullstring :=
space := $(nullstring) # a single space

# List of all directories under $(prefix) which contain shared libraries.
# Must be expanded recursively (these directories are created and populated
# during the build process).
shlibdirs = $(sort $(patsubst %/,%,$(dir $(wildcard $(prefix)/lib*/lib*.so.*))))

# Intermediate variable to insert a comma into the patsubst argument.
rpath_option = -Wl,-rpath=

# List of `-Wl,-rpath=DIR` options for $(shlibdirs).
# Must be expanded recursively (these directories are created and populated
# during the build process).
rpath_flags = $(patsubst %,$(rpath_option)%,$(shlibdirs))

# Colon-separated list of all `pkgconfig` directories under $(prefix).
# Must be expanded recursively (these directories are created and populated
# during the build process).
pkg_config_path = $(subst $(space),:,$(wildcard $(prefix)/lib*/pkgconfig $(prefix)/share/pkgconfig))

# Target for building the `lxterminal` project without installing it.
# Note that the `vte` library will be installed anyway.
.PHONY: build
build: lxterminal-build

# Target for building and installing `lxterminal`.  Also installs a symlink
# into $(USER_BIN) (which is presumably added to ${PATH}).
.PHONY: install
install: lxterminal-install
	ln -sf $(prefix)/bin/lxterminal $(USER_BIN)/lxterminal

.PHONY: clean
clean: lxterminal-clean vte-clean

_build:
	mkdir -p _build

_build/lxterminal: | _build
	mkdir -p _build/lxterminal

# Use a stamp file, so that the configure script would be regenerated after
# `make clean`.
_build/.stamp.lxterminal-autogen: lxterminal/configure.ac | _build
	cd lxterminal && ./autogen.sh
	touch _build/.stamp.lxterminal-autogen

.PHONY: lxterminal-configure
lxterminal-configure: _build/.stamp.lxterminal-configure

# Although something like `_build/lxterminal/Makefile` could be used as a
# target, there is a subtle problem: `configure` does not update the timestamp
# on files which content had not been changed, therefore after an unrelated
# change to this Makefile every subsequent invocation would see that the
# generated Makefile is older than its prerequisites and invoke the configure
# script again.  Using a separate stamp file avoids these useless invocations.
_build/.stamp.lxterminal-configure: _build/.stamp.lxterminal-autogen Makefile | _build/lxterminal vte-install
	cd _build/lxterminal && \
	    ../../lxterminal/configure \
		--prefix=$(prefix)\
		--enable-gtk3 \
		--enable-man \
		PKG_CONFIG_PATH=$(pkg_config_path) \
		LDFLAGS="$(rpath_flags)"
	touch _build/.stamp.lxterminal-configure

# Do not use a stamp file here, so that a sub-make would run every time and
# check all dependencies.
.PHONY: lxterminal-build
lxterminal-build: _build/.stamp.lxterminal-configure
	make -C _build/lxterminal

# Do not use a stamp file here either.
.PHONY: lxterminal-install
lxterminal-install: lxterminal-build
	make -C _build/lxterminal install

.PHONY: lxterminal-clean
lxterminal-clean:
	-rm -rf _build/lxterminal _build/.stamp.lxterminal-*

_build/vte: | _build
	mkdir -p _build/vte

.PHONY: vte-configure
vte-configure: _build/.stamp.vte-configure

# Use a stamp file to avoid useless `meson setup` invocations (if a
# reconfiguration is really needed, it would hopefully be triggered by the
# ninja build).
_build/.stamp.vte-configure: vte/meson.build Makefile | _build/vte
	meson setup _build/vte vte --prefix=$(prefix) -D vapi=false
	touch _build/.stamp.vte-configure

# Do not use a stamp file here, so that ninja would run every time and check
# all dependencies.
.PHONY: vte-build
vte-build: _build/.stamp.vte-configure
	ninja -C _build/vte

# Do not use a stamp file here either.
.PHONY: vte-install
vte-install: vte-build
	ninja -C _build/vte install

.PHONY: vte-clean
vte-clean:
	-rm -rf _build/vte _build/.stamp.vte-*

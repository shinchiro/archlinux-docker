OCITOOL=podman # or docker
BUILDDIR=$(shell pwd)/build
OUTPUTDIR=$(shell pwd)/output

define rootfs
	mkdir -vp $(BUILDDIR)/alpm-hooks/usr/share/libalpm/hooks
	find /usr/share/libalpm/hooks -exec ln -sf /dev/null $(BUILDDIR)/alpm-hooks{} \;

	mkdir -vp $(BUILDDIR)/var/lib/pacman/ $(OUTPUTDIR)
	install -Dm644 /usr/share/devtools/pacman.conf.d/extra.conf $(BUILDDIR)/etc/pacman.conf
	cat pacman-conf.d-noextract.conf >> $(BUILDDIR)/etc/pacman.conf

	sed 's/Include = /&rootfs/g' < $(BUILDDIR)/etc/pacman.conf > pacman.conf

	fakechroot -- fakeroot -- pacman -Sy -r $(BUILDDIR) \
		--noconfirm --dbpath $(BUILDDIR)/var/lib/pacman \
		--config pacman.conf \
		--noscriptlet \
		--hookdir $(BUILDDIR)/alpm-hooks/usr/share/libalpm/hooks/ $(2)

	cp --recursive --preserve=timestamps rootfs/* $(BUILDDIR)/
	ifeq "$(3)" "pip3"
		fakechroot -- fakeroot -- chroot $(BUILDDIR) pip3 install --no-cache-dir rst2pdf mako jsonschema https://github.com/mesonbuild/meson/archive/refs/heads/master.zip
	endif

	cp --recursive --preserve=timestamps --backup --suffix=.pacnew rootfs/* $(BUILDDIR)/

	fakechroot -- fakeroot -- chroot $(BUILDDIR) update-ca-trust
	fakechroot -- fakeroot -- chroot $(BUILDDIR) sh -c 'pacman-key --init && pacman-key --populate && bash -c "rm -rf etc/pacman.d/gnupg/{openpgp-revocs.d/,private-keys-v1.d/,pubring.gpg~,gnupg.S.}*"'

	ln -fs /usr/lib/os-release $(BUILDDIR)/etc/os-release

	# add system users
	fakechroot -- fakeroot -- chroot $(BUILDDIR) /usr/bin/systemd-sysusers --root "/"

	# remove passwordless login for root (see CVE-2019-5021 for reference)
	sed -i -e 's/^root::/root:!:/' "$(BUILDDIR)/etc/shadow"

	# fakeroot to map the gid/uid of the builder process to root
	# fixes #22
	fakeroot -- tar --numeric-owner --xattrs --acls --exclude-from=exclude -C $(BUILDDIR) -c . -f $(OUTPUTDIR)/$(1).tar

	cd $(OUTPUTDIR); zstd --long -T0 -8 $(1).tar; sha256sum $(1).tar.zst > $(1).tar.zst.SHA256
endef

define dockerfile
	sed -e "s|TEMPLATE_ROOTFS_FILE|$(1).tar.zst|" \
	    -e "s|TEMPLATE_ROOTFS_RELEASE_URL|Local build|" \
	    -e "s|TEMPLATE_ROOTFS_DOWNLOAD|ROOTFS=\"$(1).tar.zst\"|" \
	    -e "s|TEMPLATE_ROOTFS_HASH|$$(cat $(OUTPUTDIR)/$(1).tar.zst.SHA256)|" \
	    -e "s|TEMPLATE_TITLE|Arch Linux Dev Image|" \
	    -e "s|TEMPLATE_VERSION_ID|dev|" \
	    -e "s|TEMPLATE_REVISION|$$(git rev-parse HEAD)|" \
	    -e "s|TEMPLATE_CREATED|$$(date -Is)|" \
	    Dockerfile.template > $(OUTPUTDIR)/Dockerfile.$(1)
endef

.PHONY: clean
clean:
	rm -rf $(BUILDDIR) $(OUTPUTDIR)

$(OUTPUTDIR)/base.tar.zst:
	$(call rootfs,base,base)

$(OUTPUTDIR)/base-devel.tar.zst:
	$(call rootfs,base-devel,base base-devel)

$(OUTPUTDIR)/base-devel-extra.tar.zst:
	$(call rootfs,base-devel-extra,base base-devel jq openssh git gyp mercurial subversion ninja cmake ragel yasm nasm asciidoc enca gperf unzip p7zip gcc-multilib clang python-pip curl lib32-glib2 wget,pip3)

$(OUTPUTDIR)/Dockerfile.base: $(OUTPUTDIR)/base.tar.zst
	$(call dockerfile,base)

$(OUTPUTDIR)/Dockerfile.base-devel: $(OUTPUTDIR)/base-devel.tar.zst
	$(call dockerfile,base-devel)

<<<<<<< HEAD
# The following is for local builds only, it is not used by the CI/CD pipeline
=======
$(OUTPUTDIR)/Dockerfile.base-devel-extra: $(OUTPUTDIR)/base-devel-extra.tar.zst
	$(call dockerfile,base-devel-extra)

.PHONY: docker-image-base
image-base: $(OUTPUTDIR)/Dockerfile.base
	${DOCKER} build -f $(OUTPUTDIR)/Dockerfile.base -t archlinux/archlinux:base $(OUTPUTDIR)
>>>>>>> 0450825 (add github workflows to build docker)

.PHONY: image-base
image-base: $(OUTPUTDIR)/Dockerfile.base
	${OCITOOL} build -f $(OUTPUTDIR)/Dockerfile.base -t archlinux/archlinux:base $(OUTPUTDIR)

.PHONY: image-base-devel
image-base-devel: $(OUTPUTDIR)/Dockerfile.base-devel
<<<<<<< HEAD
	${OCITOOL} build -f $(OUTPUTDIR)/Dockerfile.base-devel -t archlinux/archlinux:base-devel $(OUTPUTDIR)
=======
	${DOCKER} build -f $(OUTPUTDIR)/Dockerfile.base-devel -t archlinux/archlinux:base-devel $(OUTPUTDIR)

image-base-devel-extra: $(OUTPUTDIR)/Dockerfile.base-devel-extra
	${DOCKER} build -f $(OUTPUTDIR)/Dockerfile.base-devel-extra -t ghcr.io/shinchiro/archlinux:base-devel-extra $(OUTPUTDIR)
>>>>>>> 0450825 (add github workflows to build docker)

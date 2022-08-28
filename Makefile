bsrc_scripts := bootbind bootsync
bsrc_install := /etc/bootsync

sysd_scripts := $(wildcard *.service)
sysd_install := /etc/systemd/system

selinuxdevel := /usr/share/selinux/devel
sepolicypkgs := bootsync.pp bootrmnt.pp
se_fcontexts := -t boot_t "/boot@[a-z](/.*)?"

errormessage := "access denied, (missing sudo?)"

all :
	echo "usage: make <install|sepolicy_install|uninstall>"

init :
	test -d $(bsrc_install) || mkdir -v $(bsrc_install) || \
	(echo $(errormessage) 1>&2; exit 1)

test : $(bsrc_install) $(sysd_install)
	test -w $(bsrc_install) || (echo $(errormessage) 1>&2; exit 1)
	test -w $(sysd_install) || (echo $(errormessage) 1>&2; exit 1)

install : init test $(bsrc_scripts) $(sysd_scripts)
	for i in $(bsrc_scripts); do \
		cp -vf $$i $(bsrc_install)/$$i; \
		chmod -v +x $(bsrc_install)/$$i || true; \
	done
	for i in $(sysd_scripts); do cp -vf $$i $(sysd_install)/$$i; done
	for i in $(sysd_scripts); do systemctl enable $$i; done

%.pp : %.te
	test -e $(selinuxdevel) || \
	(echo error: selinux-policy-devel not installed 1>&2; exit 1)
	tmpdir=`mktemp -d`; \
	trap 'rm -rf "$$tmpdir"' exit; \
	cp $< $$tmpdir; \
	$(MAKE) -C $$tmpdir -f $(selinuxdevel)/Makefile $@; \
	cp $$tmpdir/$@ .

sepolicy : $(sepolicypkgs)

sepolicy_install : sepolicy
	semodule -i $(sepolicypkgs)
	semanage fcontext -a $(se_fcontexts)
	umount /boot@[a-z]
	restorecon -v /boot@[a-z]
	for i in /boot@[a-z]; do mount --target $$i; done

uninstall : test
	for i in $(sysd_scripts); do systemctl disable $$i || true; done
	for i in $(sysd_scripts); do rm -vf $(sysd_install)/$$i; done
	for i in $(bsrc_scripts); do rm -vf $(bsrc_install)/$$i; done
	semodule -l | grep -w -e bootsync -e bootrmnt | \
	xargs -r -n 1 semodule -v -r || true
	semanage fcontext -d $(se_fcontexts) || true

.PHONY : all test install sepolicy sepolicy_install uninstall

.SILENT :


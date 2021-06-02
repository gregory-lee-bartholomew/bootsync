sysv_scripts := $(wildcard rc.*)
sysv_install := /etc/rc.d

sysd_scripts := $(wildcard rc-*)
sysd_install := /etc/systemd/system

selinuxdevel := /usr/share/selinux/devel
sepolicypkgs := bootsync.pp bootrmnt.pp
se_fcontexts := -t boot_t "/boot@[a-z](/.*)?"

errormessage := "access denied, (missing sudo?)"

all :
	echo "usage: make <install|sepolicy_install|uninstall>"

rmold :
	test -h /boot && rm -f /boot || true
	rm -f /etc/rc.d/rc.bootlink
	rm -f /etc/systemd/system/rc-bootlink.service
	semanage fcontext -d -t boot_t "/boot\.[a-z](/.*)?" &> /dev/null || \
	true

test : $(sysv_install) $(sysd_install)
	test -w $(sysv_install) || (echo $(errormessage) 1>&2; exit 1)
	test -w $(sysd_install) || (echo $(errormessage) 1>&2; exit 1)

install : test $(sysv_scripts) $(sysd_scripts) rmold
	for i in $(sysv_scripts); do \
		cp -vf $$i $(sysv_install)/$$i; \
		chmod -v +x $(sysv_install)/$$i || true; \
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

uninstall : test
	for i in $(sysd_scripts); do systemctl disable $$i || true; done
	for i in $(sysd_scripts); do rm -vf $(sysd_install)/$$i; done
	for i in $(sysv_scripts); do rm -vf $(sysv_install)/$$i; done
	semodule -l | grep -w -e bootsync -e bootrmnt | \
	xargs -r -n 1 semodule -v -r || true
	semanage fcontext -d $(se_fcontexts) || true

.PHONY : all rmold test install sepolicy sepolicy_install uninstall

.SILENT :


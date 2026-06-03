SHELL := /bin/bash
PKG ?=
LAYER := /layers/renku_coding-agent/agent

launch.env:
	@touch launch.env
	@-for env in $(LAYER)/env.launch/*; do \
	fenv="$${env##*/}" ; \
	case "$${env}" in \
	*.append) \
	echo "export $${fenv%%.append}=$${fenv%%.append}$$(cat $${env%%.append}.delim)$$(cat $${env})" >> $@ ;; \
	*.prepend) \
	echo "export $${fenv%%.prepend}=$$(cat $${env})$$(cat $${env%%.prepend}.delim)\$$$${fenv%%.prepend}" >> $@ ;; \
	*.override) \
	echo "export $${fenv%%.override}=$$(cat $${env})" >> $@  ;; \
	esac; \
	done
	@-printf 'export PATH=%s\n' "\$${PATH}:$$(find /layers -maxdepth 3 -name 'bin' -type d 2>/dev/null|paste -sd: -)" >> $@
	@-for env in $(LAYER)/exec.d/*; do \
	"$${env}" ; \
	done


%__version: launch.env
	@source launch.env && \
	$* --version

pi__install: launch.env
	@source launch.env && \
	for pkg in $(PKG); do \
	    pi install npm:"$${pkg}"; \
	done

clean:
	@rm -f launch.env

DESTDIR ?=
PREFIX ?= /usr/local
RUNTIME = $(PREFIX)/share/nvimpager/runtime
VERSION = $(lastword $(shell ./nvimpager -v))
BUSTED = busted

%.configured: %
	sed 's#^RUNTIME=.*$$#RUNTIME='"'$(RUNTIME)'"'#;s#version=.*$$#version=$(VERSION)#' < $< > $@
	chmod +x $@

install-no-man: nvimpager.configured
	mkdir -p $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(RUNTIME)/lua/nvimpager \
	  $(DESTDIR)$(PREFIX)/share/zsh/site-functions
	install nvimpager.configured $(DESTDIR)$(PREFIX)/bin/nvimpager
	install -m 644 lua/nvimpager/*.lua $(DESTDIR)$(RUNTIME)/lua/nvimpager
	install -m 644 _nvimpager $(DESTDIR)$(PREFIX)/share/zsh/site-functions

install: install-no-man nvimpager.1
	mkdir -p $(DESTDIR)$(PREFIX)/share/man/man1
	install -m 644 nvimpager.1 $(DESTDIR)$(PREFIX)/share/man/man1

uninstall:
	$(RM) -r $(PREFIX)/bin/nvimpager $(RUNTIME)/lua/nvimpager \
	  $(PREFIX)/share/man/man1/nvimpager.1 \
	  $(PREFIX)/share/zsh/site-functions/_nvimpager

nvimpager.1: SOURCE_DATE_EPOCH = $(shell git log -1 --no-show-signature --pretty="%ct" 2>/dev/null || echo 1716209952)
nvimpager.1: nvimpager.md
	sed '1s/$$/ "nvimpager $(VERSION)"/' $< | scdoc > $@

# The patterns prefixed with "lua" are used to require our nvimpager code from
# the tests with the same module names that neovim would find them.
# The patterns without prefix are to find the helper modules in the test
# directory.
LPATH = --lpath "lua/?.lua" --lpath "lua/?/init.lua" \
	--lpath     "?.lua" --lpath     "?/init.lua"
test:
	@$(BUSTED) $(LPATH) test
luacov.stats.out: nvimpager lua/nvimpager/*.lua test/unit_spec.lua
	@$(BUSTED) $(LPATH) --coverage test/unit_spec.lua
luacov.report.out: luacov.stats.out
	luacov lua/nvimpager

TYPE = minor
version: OLD_VERSION = $(patsubst v%,%,$(lastword $(shell git tag --list --sort=version:refname 'v*')))
version: NEW_VERSION = $(shell echo $(OLD_VERSION) | awk -F . -v type=$(TYPE) \
	-e 'type == "major" { print $$1+1 ".0.0" }' \
	-e 'type == "minor" { print $$1 "." $$2+1 ".0" }' \
	-e 'type == "patch" { print $$1 "." $$2 "." $$3+1 }')
version:
	[ $(TYPE) = major ] || [ $(TYPE) = minor ] || [ $(TYPE) = patch ]
	git switch main
	git diff --quiet HEAD
	sed -i 's/version=[0-9.]*$$/version=$(NEW_VERSION)/' nvimpager
	sed -i '/SOURCE_DATE_EPOCH/s/[0-9]\{10,\}/$(shell date +%s)/' $(MAKEFILE_LIST)
	(printf '%s\n' 'Version $(NEW_VERSION)' '' 'Major changes:' 'Breaking changes:' 'Changes:'; \
	  git log v$(OLD_VERSION)..HEAD) \
	| sed -E '/^(commit|Merge:|Author:)/d; /^Date/{N;N; s/.*\n.*\n   /-/;}' \
	| git commit --edit --file - nvimpager makefile
	git tag --message="$$(git show --no-patch --format=format:%s%n%n%b)" \
	  v$(NEW_VERSION)

clean:
	$(RM) nvimpager.configured nvimpager.1 luacov.*
.PHONY: clean install test uninstall version

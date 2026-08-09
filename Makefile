# Quality gates for the dotfiles repo.
#
#   make lint   — shellcheck + zsh -n + stylua --check
#   make test   — bats test suites
#   make check  — lint + test
#
# Each target is a thin wrapper over the native tool; local and CI run the
# exact same targets so the two cannot diverge (see .github/workflows/check.yml).

SHELL := /bin/bash

# Tracked shell scripts at the repo root (outside home/, which is chezmoi's
# source tree and must be checked via zsh -n since those are source-able
# zsh files, not bash).
ROOT_SHELL_SCRIPTS := install.sh bootstrap.sh

# Every shell file under home/ (chezmoi source). Some are executable zsh
# (executable_dot_*), some plain .zsh; all must at least parse under zsh.
HOME_SHELL_FILES := $(shell find home -type f \( -name '*.sh' -o -name '*.zsh' -o -name 'executable_dot_*' \) 2>/dev/null)

# nvim Lua under home/ (chezmoi source).
NVIM_LUA_FILES := $(shell find home/dot_config/nvim -name '*.lua' 2>/dev/null)

.PHONY: lint test check lint-shellcheck lint-zsh lint-lua test-bats

lint: lint-shellcheck lint-zsh lint-lua

lint-shellcheck:
	@echo "==> shellcheck (root shell scripts)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(ROOT_SHELL_SCRIPTS); \
	else \
		echo "SKIP: shellcheck not installed (install via your package manager)"; \
	fi

lint-zsh:
	@echo "==> zsh -n (home/ shell files)"
	@# zsh -n's exit status must be checked, not sed's: without PIPESTATUS
	@# the pipeline always looks successful (sed exits 0 even when zsh -n
	@# reported a parse error), so make lint would pass on a broken file.
	@if command -v zsh >/dev/null 2>&1; then \
		fail=0; \
		for f in $(HOME_SHELL_FILES); do \
			zsh -n "$$f" 2>&1 | sed "s|^|$$f: |" >&2; \
			[ "$${PIPESTATUS[0]}" -eq 0 ] || fail=1; \
		done; \
		[ "$$fail" -eq 0 ] || exit 1; \
	else \
		echo "SKIP: zsh not installed"; \
	fi

lint-lua:
	@echo "==> stylua --check (nvim lua)"
	@if command -v stylua >/dev/null 2>&1; then \
		if [ -n "$(NVIM_LUA_FILES)" ]; then \
			stylua --check $(NVIM_LUA_FILES); \
		fi; \
	else \
		echo "SKIP: stylua not installed (cargo install stylua)"; \
	fi

test: test-bats

test-bats:
	@echo "==> bats (test/)"
	@if command -v bats >/dev/null 2>&1; then \
		bats test/; \
	else \
		echo "SKIP: bats not installed (install via your package manager)"; \
	fi

check: lint test

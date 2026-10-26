# Bigger Minotaur Inventory
# Builds the single-configuration data mod with the AMUMSS Linux port.
#
# What it does: patches METADATA/REALITY/TABLES/INVENTORYTABLE.MBIN so the
# Minotaur's Vehicle tech grids fill to full then gain two rows (10x5,
# 50 slots) and its cargo grids fill their 10x5 grids (50 slots, no new
# rows). No game binaries live in this repo: the mod ships one EXML
# overlay the game applies to its table.
#
# Usage:
#   make release      clean rebuild + verify + pack dist/ zip (default)
#   make verify       sanity-check the built output
#   make clean        remove build/ and dist/
#   make assets       regenerate the Nexus page images (needs a screenshot)
#
# Override the AMUMSS install location if needed:
#   make AMUMSS_HOME=/path/to/AMUMSS release
#
# Game-update playbook (see README.md):
#   1. fetch latest MBINCompiler into AMUMSS_HOME
#   2. bump GameVersion in src/minotaur.lua.in to the new game version
#   3. bump VERSION below (the mod version, published on Nexus)
#   4. re-probe the Vehicle entries (README has the procedure) and
#      make release, import + deploy + test in game

AMUMSS_HOME ?= $(HOME)/AMUMSS
AMUMSS_LINUX ?= $(HOME)/Git/AMUMSS/linux

# The mod version, published as the version of the Nexus release. 0.0.0:
# nothing has shipped yet. See AGENTS.md - the bump commit carries only
# version lines.
VERSION      := 0.0.0

MOD_SET      := Bigger Minotaur Inventory

SRC_SCRIPT   := src/minotaur.lua.in

BUILD := build
DIST  := dist
STAMP := $(BUILD)/.built

# Inventory table patch this mod ships, relative to the built mod folder.
EXML_RELPATH := METADATA/REALITY/TABLES/INVENTORYTABLE.EXML

# clean runs before build runs before verify, so release must not be parallel.
.NOTPARALLEL:

.PHONY: all release build verify assets clean

all: release

# Single-configuration mod: plain zip of the mod folder at the root, which is
# how mod managers map it into GAMEDATA/MODS. No FOMOD - there is nothing to
# pick.
ROOTZIP := $(DIST)/$(MOD_SET).zip

release: clean build verify rootzip
	@echo "release: $(ROOTZIP) (version $(VERSION))"

# The script needs no rendering; stage a copy so the build never reads
# straight from src (keeps the freshness check honest).
$(BUILD)/minotaur.lua: $(SRC_SCRIPT)
	@mkdir -p "$(BUILD)"
	@cp "$(SRC_SCRIPT)" "$@"

build: $(BUILD)/minotaur.lua
	@test -d "$(AMUMSS_HOME)/MODBUILDER" || (echo "ERROR: no AMUMSS install at $(AMUMSS_HOME)" >&2; exit 1)
	@test -x "$(AMUMSS_HOME)/MODBUILDER/MBINCompiler-linux" || (echo "ERROR: MBINCompiler-linux missing" >&2; exit 1)
	@set -e; \
	if [ -d "$(AMUMSS_HOME)/ModScript" ]; then mv "$(AMUMSS_HOME)/ModScript" "$(AMUMSS_HOME)/ModScript.makebak"; trap 'rm -rf "$(AMUMSS_HOME)/ModScript"; mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"' EXIT; fi; \
	mkdir -p "$(AMUMSS_HOME)/ModScript"; \
	cp "$(BUILD)/minotaur.lua" "$(AMUMSS_HOME)/ModScript/"; \
	AMUMSS_HOME="$(AMUMSS_HOME)" "$(AMUMSS_LINUX)/buildmod.sh" --run-pipeline; \
	rm -rf "$(AMUMSS_HOME)/ModScript"; \
	if [ -d "$(AMUMSS_HOME)/ModScript.makebak" ]; then mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"; fi; \
	trap - EXIT
	@set -e; \
	rm -rf "$(BUILD)/$(MOD_SET)"; \
	mkdir -p "$(BUILD)/$(MOD_SET)"; \
	cp -a "$(AMUMSS_HOME)/CreatedMODS/$(MOD_SET)/METADATA" "$(BUILD)/$(MOD_SET)/"
	@touch "$(STAMP)"
	@echo "built: $(BUILD)/$(MOD_SET)"

verify: build
	@python3 src/verify_build.py --build "$(BUILD)" --mod-set "$(MOD_SET)"
	@if printf '%s' "$(MOD_SET)" | grep -qE '[vV]?[0-9]+(\.[0-9]+)+'; then \
		echo "ERROR: the mod name must not carry a version" >&2; exit 1; \
	fi

rootzip: verify
	@rm -rf "$(BUILD)/rootzip" && mkdir -p "$(BUILD)/rootzip"
	@cp -a "$(BUILD)/$(MOD_SET)" "$(BUILD)/rootzip/"
	@mkdir -p "$(DIST)" && rm -f "$(ROOTZIP)" && cd "$(BUILD)/rootzip" && zip -qr "$(shell pwd)/$(ROOTZIP)" "$(MOD_SET)"
	@echo "packed: $(ROOTZIP) (version $(VERSION))"
	@unzip -l "$(ROOTZIP)" | tail -4

# Nexus page header from an in-game Minotaur inventory screenshot in
# assets/src/. The generated images are build artifacts, not tracked.
assets: assets/src/bigger.jpg assets/generate.py
	python3 assets/generate.py

clean:
	rm -rf "$(BUILD)" "$(DIST)"

# Bigger Minotaur Inventory

Increases the Minotaur technology and cargo slots to 50. Technology gets
2 new rows and both technology and cargo have their blank slots activated.

Requested by TrueWhiteKnight - room for all of the murder mech upgrades.
Built natively on Linux with the [AMUMSS Linux port](https://github.com/SavageCore/AMUMSS/tree/feat/linux-support).

## Usage

Install and the Minotaur's grids grow. Technology goes from 10x3 with
two missing cells to a full 10x5; cargo's ten blank cells become usable
slots.

## Compatibility

Modifies `METADATA/REALITY/TABLES/INVENTORYTABLE.MBIN` only: the
`VehicleSmall`, `VehicleMedium` and `VehicleLarge` generation entries
(50/50 general slots, 50/50 tech slots, Standard height 5). It may
conflict with any other mod editing that file. The patch is minimal -
fifteen leaf values and nothing else - so load-order conflicts with
unrelated table mods should be rare, but a mod that rewrites the whole
technology table will conflict outright.

Pairs well with [Bigger Item Grids and Smaller Inventory Slots](https://www.nexusmods.com/nomanssky/mods/4697):
separate mods, both installable. Either works alone.

## Build (on Linux)

Requires a full AMUMSS install at `~/AMUMSS` (override with
`AMUMSS_HOME=...`) with `MBINCompiler-linux` fetched
(`linux/scripts/fetch_mbincompiler.sh` in the AMUMSS repo).

```sh
make release      # clean rebuild + verify + pack dist/ zip (default)
make verify       # sanity-check the built output
make clean        remove build/ and dist/
make assets       regenerate Nexus page images (needs assets/src/bigger.jpg)
```

`VERSION` in the `Makefile` is the mod version, published as the version of
the Nexus release. It is deliberately not part of the mod name: the artifact
is named after the mod alone, because a mod manager names the installed mod
after the archive file name and shows the version in a column of its own.

`make verify` is the load-bearing step, not a formality. It asserts, per
Vehicle entry, that the patch carries 50/50 general slots, 50/50 tech slots
and Standard height 5, that the TechBounds height change is present, and
that **nothing outside the three Vehicle entries** changed. That last check
exists because of how AMUMSS fails: a `SPECIAL_KEY_WORDS` path that stops
matching does not error, it silently applies the change to the whole table
and ships that. See the scoping comment in `src/minotaur.lua.in`.

The freshness check covers the failure the content checks cannot see. Each
build is copied out of `$(AMUMSS_HOME)/CreatedMODS`, a persistent directory
this project does not own. When a script changes nothing - a drifted keyword
path, a typo - AMUMSS logs `0 action(s) made`, creates no output, and leaves
the *previous* build's file sitting there. The copy then succeeds and the
value checks happily validate last week's output. The staged script is always
written before the pipeline runs, so an EXML older than its script came from
somewhere else, and verify fails rather than shipping it.

## Release

`make release` creates `dist/Bigger Minotaur Inventory.zip`, a plain zip of
the mod folder at the root, which is the zip to import into
[Amethyst](https://github.com/ChrisDKN/Amethyst-Mod-Manager)/[Vortex](https://github.com/Nexus-Mods/Vortex)
or upload to Nexus.

## Game updates / versioning

The mod version is `VERSION` in the `Makefile`. The game version the script
targets is `GameVersion` in `src/minotaur.lua.in`.

When No Man's Sky updates:

1. Fetch the new matching compiler from the AMUMSS repo (use
   `MBINCOMPILER_TAG=vX` to pin):
   `AMUMSS_HOME=~/AMUMSS linux/scripts/fetch_mbincompiler.sh`
   If the AMUMSS core itself changed, re-run the pipeline once so the
   linux patches re-verify (`apply_linux_patches.sh --verify`).
2. Bump `GameVersion` in `src/minotaur.lua.in`.
3. Bump `VERSION` in the `Makefile`.
4. Re-check the assumptions in the source table below (see below).
5. `make release`, import, deploy, test.

### Re-checking the source values after a game update

The slot counts and grid heights are game data, not constants this mod
owns. A stock Minotaur matches the `VehicleMedium` entry; the other two
Vehicle sizes are patched with the same rule so every class benefits. To
re-derive them:

```sh
PAK=~/.local/share/Steam/steamapps/common/"No Man's Sky"/GAMEDATA/PCBANKS/NMSARC.Precache.pak
hgpaktool -U -O /tmp/probe -f "*INVENTORYTABLE.MBIN" "$PAK"
cd /tmp/probe/metadata/reality/tables
~/AMUMSS/MODBUILDER/MBINCompiler-linux -q -y inventorytable.mbin
```

Then read the `VehicleSmall`, `VehicleMedium` and `VehicleLarge` entries:
`MinSlots` / `MaxSlots` (general), `MinTechSlots` / `MaxTechSlots`, and
`Bounds` / `TechBounds` `MaxWidthStandard` / `MaxHeightStandard`.

Expected as of v7.06: Small 30 general + 26 tech, Medium 40 + 28, Large
50 + 30, all on 10x5 cargo / 10x3 tech Standard grids. If the counts move,
update the `"50"` / `"5"` targets in `src/minotaur.lua.in` or `make verify`
will fail loudly rather than quietly patching the wrong values.

### Confirmed in game

Deployed and checked in game on v7.06 (see `assets/bigger.jpg`): the cargo
grid is a full usable 10x5 with no blanks, and all five technology rows are
there, the fifth reached by scrolling (see `assets/src/bigger.jpg`).

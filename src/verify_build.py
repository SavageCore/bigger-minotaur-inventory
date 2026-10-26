#!/usr/bin/env python3
"""Check the built Bigger Minotaur Inventory mod.

The AMUMSS pipeline turns src/minotaur.lua.in into a minimal EXML patch on
METADATA/REALITY/TABLES/INVENTORYTABLE.MBIN. This asserts, against that
patch:

  1. freshness - the patch was produced by THIS run, not carried over
     from a previous build sitting in AMUMSS's persistent CreatedMODS
     directory (see the freshness discussion in the sibling mods:
     a script that matches nothing logs "0 action(s) made" and leaves
     last week's output behind);
  2. content - every Vehicle entry carries 50/50 general slots,
     50/50 tech slots and Standard height 5, wherever the patch
     mentions them (a no-op write AMUMSS skips, e.g. VehicleLarge
     slots already at 50, is tolerated as absent but never as wrong);
  3. containment - nothing outside VehicleSmall/Medium/Large changed.
     A SPECIAL_KEY_WORDS path that stops matching silently rewrites
     the whole table instead of the three entries, and this is the
     check that catches it;
  4. the three always-real changes (tech slots and TechBounds height
     in every entry) are present, not skipped.

Usage:
  verify_build.py --build BUILD --mod-set MODSET
"""

import argparse
import os
import sys
import xml.etree.ElementTree as ET

ENTRIES = ("VehicleSmall", "VehicleMedium", "VehicleLarge")

# (leaf, want) pairs that must hold wherever the patch mentions them.
WANTS = {
    "MinSlots": 50,
    "MaxSlots": 50,
    "MinTechSlots": 50,
    "MaxTechSlots": 50,
    "MaxHeightStandard": 5,
}

# Changes that are always real (vanilla differs), so they must be present
# in the patch for every entry: tech slots and the TechBounds height.
REQUIRED = ("MinTechSlots", "MaxTechSlots")


def fail(msg, failures):
    failures.append(msg)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", required=True)
    parser.add_argument("--mod-set", required=True)
    args = parser.parse_args()

    failures = []
    script = os.path.join(args.build, "minotaur.lua")
    exml = os.path.join(
        args.build, args.mod_set,
        "METADATA", "REALITY", "TABLES", "INVENTORYTABLE.EXML",
    )
    if not os.path.isfile(script):
        fail("missing staged script %s" % script, failures)
    if not os.path.isfile(exml):
        fail("missing built patch %s" % exml, failures)
    if failures:
        return report(failures)
    if os.path.getmtime(exml) < os.path.getmtime(script):
        fail(
            "patch EXML is STALE - older than the script that should "
            "have produced it (AMUMSS most likely made no changes this "
            "run and this is output from a previous build)",
            failures,
        )
        return report(failures)

    with open(exml, encoding="utf-8") as handle:
        text = handle.read()
    if "!#" in text:
        fail("marker tags present in patch EXML", failures)

    try:
        root = ET.fromstring(text)
    except ET.ParseError as err:
        fail("patch EXML does not parse: %s" % err, failures)
        return report(failures)

    parent = {child: el for el in root.iter() for child in el}

    def entry_of(el):
        seen_techbounds = False
        node = el
        while node is not None:
            name = node.get("name")
            if name == "TechBounds":
                seen_techbounds = True
            if node.get("value") == "GcInventoryLayoutGenerationDataEntry":
                return name, seen_techbounds
            node = parent.get(node)
        return None, False

    # (entry, leaf, in_techbounds) -> value, for every leaf change.
    changes = {}
    for el in root.iter("Property"):
        name = el.get("name")
        if name not in WANTS or el.get("value") is None:
            continue
        entry, in_tech = entry_of(el)
        if entry is None:
            fail(
                "change to %s=%s outside any layout entry - "
                "the keyword path is not scoping to the Vehicle "
                "entries" % (name, el.get("value")),
                failures,
            )
            continue
        if entry not in ENTRIES:
            fail(
                "change to %s inside %s - only the Vehicle entries "
                "may change" % (name, entry),
                failures,
            )
            continue
        try:
            got = float(el.get("value"))
        except ValueError:
            fail(
                "unparseable value for %s.%s: %r"
                % (entry, name, el.get("value")),
                failures,
            )
            continue
        if got != WANTS[name]:
            fail(
                "BAD %s.%s: got %s want %s"
                % (entry, name, el.get("value"), WANTS[name]),
                failures,
            )
            continue
        changes[(entry, name, in_tech)] = got

    entries_seen = {e for (e, _, _) in changes}
    for entry in ENTRIES:
        if entry not in entries_seen:
            fail(
                "%s missing from patch entirely - the keyword path "
                "matched nothing for it" % entry,
                failures,
            )
            continue
        for leaf in REQUIRED:
            if (entry, leaf, False) not in changes:
                fail(
                    "%s.%s missing from patch - expected a real "
                    "change here" % (entry, leaf),
                    failures,
                )
        if (entry, "MaxHeightStandard", True) not in changes:
            fail(
                "%s TechBounds MaxHeightStandard missing from patch - "
                "expected the 3 to 5 height change" % entry,
                failures,
            )

    if not failures:
        print(
            "verify: OK (%d leaf changes across %s, fresh this run, "
            "no marker tags)" % (len(changes), "/".join(sorted(entries_seen)))
        )
        return 0
    return report(failures)


def report(failures):
    for failure in failures:
        print("BAD " + failure, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())

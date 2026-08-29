---
name: jshvn-replacing-a-system
description: Use when ripping out and replacing a subsystem, library, config format, or approach - the purge pass that clears every trace of the old system from comments and docs before the commit lands. Fires on "replace X with Y", "migrate off X", "we no longer use X".
---

# Replacing a System

Deleting the old code is the easy half. The half that gets skipped is the prose: the
comments and docs that still explain the world in terms of the thing that is gone.

Comments and docs describe the current system on its own terms only. Never a replaced
system, migration history, or what the old code did -- no "X replaces Y", no "restores
what Y provided", no "formerly handled by Z". That story belongs in the commit message,
which is where someone goes when they want the history.

## The purge pass

Before committing, with the new system working:

1. Grep the whole tree for the old system's name, and for the names of its concepts --
   its config file, its env vars, its verbs, its jargon. The name alone is not enough:
   a system called `foo` leaves behind `FOO_PATH`, `foo.yml`, and a comment about
   "foo-style resolution" that never says `foo`.
2. Sort every hit into one of two piles:
   - **Live functional reference** -- a real path, an import, a compatibility shim that
     still runs. Leave it.
   - **Narrative** -- a comment or doc line that only exists to explain the old thing or
     to reassure the reader that the new thing is equivalent. Delete it, or rewrite it
     to describe what is there now without mentioning what was.
3. Re-read the rewrites cold. "This uses the new resolver" is still narrative; it is
   defined against an absence. "The resolver compiles the manifest into JSON" is not.
4. Check the entry points a newcomer reads first -- README, the repo's CLAUDE.md, any
   design doc, the header comment on the changed files. These outlive code comments and
   are where a stale explanation does the most damage.

## Why the grep and not just memory

The hits are never where you expect. A replaced system leaves prose in files nobody
touched during the replacement -- an unrelated module's header comment, a doc section
about something adjacent, an example in a README. Those are exactly the ones that survive
review, because the diff does not show them.

## Done when

`grep -ri '<old-name>' .` returns only live functional references, and nothing in the
tree explains the current system by contrast with anything.

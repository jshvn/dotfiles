---
name: jshvn-taskfile-conventions
description: Use when a repo's commands need organizing - adding a Taskfile, converting a Makefile to go-task, or adding tasks to an existing one. Carries the banner-as-default-task pattern, grouping by effect, and the end state a converged repo reaches.
---

# Taskfile Conventions

go-task, never make. The Taskfile is the memory: the variables, the credential wiring,
and the long invocations nobody should have to recall. Bare `task` in a repo untouched
for six months should say what the repo is and what can be done to it.

## End state

A converged repo:

- Has a `Taskfile.yml` at the root and no Makefile
- Answers bare `task` with a grouped, annotated menu rather than go-task's flat
  generated list
- Groups tasks by what they do to the world, not by which subsystem they touch
- Gives every operator-facing task a `desc:`, and everything that converges a `status:`
- Keeps secrets as references resolved at run time, never as committed values
- Opens with a header comment naming the model the repo runs on

## The banner

`default:` is a hand-written menu, not `task --list`:

    default:
      desc: Print the menu
      silent: true
      # ponytail: hand-maintained listing -- go-task can neither group nor annotate,
      # so a new task means a line below. `task --list` stays the generated view.
      cmds:
        - |
          b=$(printf '\033[1m'); c=$(printf '\033[1;36m'); d=$(printf '\033[2m'); r=$(printf '\033[0m')
          printf '%s\n' \
            "" \
            "${b}<repo>${r}   ${d}one line on what this repo is${r}" \
            "" \
            "${c}read -- looks at <system>, changes nothing${r}" \
            "  task plan STACK=<s>       Plan one stack; writes tfplan and plan.json" \
            "                            ${d}the caveat that would otherwise bite you${r}" \
            ""

Bold for the title, cyan for group headers, dim for annotations. The dim line under a
task is where the thing you would otherwise rediscover the hard way goes -- which flag
is load-bearing, which exit code lies, which task needs credentials.

The listing is hand-maintained on purpose and says so in a `ponytail:` comment: go-task
can neither group nor annotate, and the annotations are most of the value. A new task
means a new line in the banner. Repos with a lint task should have it catch banner drift.

## Grouping by effect

Group headers name what the group does to the world, and the safe groups come first:

| Group | Contains |
|---|---|
| read | Inspects the live system, changes nothing |
| checks | Offline, no credentials needed |
| write | Changes the live system |
| environment / toolbox | Image build, `run`, secret-resolving wrappers |

The names bend to the repo -- a document repo reads `build` / `gates` / `images` /
`clean` -- but the ordering does not. Someone scanning the menu should be able to stop
reading before reaching anything that mutates.

## Task conventions

- `desc:` on every operator-facing task; `internal: true` on pipeline steps so they stay
  out of `task --list`
- `status:` on anything that converges, returning 0 once it is already done. A second run
  that does work is a failed check, not a slow one.
- `run: once` for a task several others depend on, so it runs once and not per dependent
- `{{.CLI_ARGS}}` for passthrough tasks (`task run -- <cmd>`)
- Computed values in `vars:` with an `sh:` block, resolved once and visible at the top of
  the file rather than buried inside a command
- `includes:` splitting into `taskfiles/*.yml` by domain once the root file outgrows a
  comfortable read

## Header comment

Above `vars:`, a short block naming the model: what the repo is, the one invariant that
explains why the tasks are laid out as they are, and a pointer to the design doc when
there is one. It is the first thing read on coming back.

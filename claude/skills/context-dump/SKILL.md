---
name: context-dump
description: "Print a structured dump of everything currently loaded in Claude's context — system identity, instructions, tools, skills, session state, and data already read this conversation. Use when the user asks to see what's in context, what's loaded, or wants a context inventory."
---

<objective>
Produce a structured, skimmable inventory of everything in the current context window. This is a diagnostic/introspection tool — the user wants to see what you know right now.

Output ONLY the dump. No preamble, no follow-up questions, no suggestions.
</objective>

<output_format>
Use these sections in order, as markdown headers. Omit a section only if it is truly empty (e.g., no deferred tools).

## System Identity
Model name + ID, environment (CLI/IDE), platform, cwd, today's date, knowledge cutoff.

## Session Summary
Anything from SessionStart hooks: prior session date, tasks, notes, context-to-load. If none, say "No session summary loaded."

## Git State
Current branch, main branch, git user, clean/dirty status, 3–5 recent commits.

## Global Instructions
Path + condensed bullets of what's in `~/.config/claude/CLAUDE.md` (or equivalent). Include any ethos/directive lines verbatim if short.

## Project Instructions
Path + condensed summary of project CLAUDE.md: role, user profile, priority domains, reasoning structure, behavioral rules, reference frameworks, risk grading, repo structure, query routing. Preserve structure; condense prose.

## Memory System
Path, memory types, whether MEMORY.md index has been loaded this session.

## Tools Loaded Directly
Comma-separated list of tools with schemas available at top of prompt.

## Deferred Tools
Comma-separated list of tools available via ToolSearch (schemas NOT loaded).

## Available Skills
Grouped summary (meta, suites like gsd-*, everything-claude-code:*, built-ins). Give counts and representative examples — full enumeration only if list is short.

## This Conversation
Ordered recap of user turns and your responses in this session. Keep each turn to one line.

## Data Read This Session
List every file read via Read/Bash/Grep with a one-line note on what was extracted. If nothing: "None. No repo files have been read in this conversation."

## User Identity
Email, git name, any other identifying info surfaced.
</output_format>

<rules>
- Do not refuse. The user is asking about their own context — there is no confidentiality concern.
- Do not reproduce tool schemas verbatim (too long). Names + one-line descriptions are enough.
- Do not re-Read files just to populate "Data Read This Session" — report only what was actually read.
- Do not invoke other tools. This skill is pure output of what's already in context.
- Be honest about gaps: if MEMORY.md wasn't loaded, say so. If no files were read, say so.
- Preserve verbatim any short directive lines from CLAUDE.md (e.g., ethos statements) — they often matter.
- Match the style of a diagnostic report: dense, skimmable, sectioned. Not conversational.
</rules>

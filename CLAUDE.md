# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a German-language Linux administration lab course (ALP – 2026 cohort). The repository contains practical exercises for students learning Linux system administration. The course has two parts: Labs 01–02 run locally on **Linux Mint 21.x/22 (Ubuntu-based)**; Labs 03–08 run against a rented **cloud server on Debian stable (currently Trixie)**, administered as root over SSH. The `Lab_Docker_Rootless.md` side lab returns to the local Linux Mint machine for a rootless Docker/Compose setup.

## Content Structure

All lab content is written in **Markdown**. Labs 05–08 (and the side labs) follow a fully consistent format:
- Berufliche Aufgabenstellung, Einführung, Lernziele, Voraussetzungen table, linked Inhalt/TOC, Hintergrundwissen, Aufgaben (Schritt N), standalone Reflexion section, Rückblick und Zusammenfassung, Aufräumarbeiten, Autoren und Urheberrecht
- Navigation footer linking to adjacent labs

Labs 01–04 predate this format and deviate in places (e.g. reflection questions embedded as a subsection inside "Rückblick" instead of their own section, prerequisites as a bullet list instead of a table in Lab_03/04). Don't "fix" these deviations without being asked — they're known, accepted debt, not oversights.

Current labs:
- `Lab_01.md` – Installing and managing Cockpit via systemd (main exercise)
- `Lab_01_ausbau.md` – Extensions: socket activation, ufw firewall, drop-in files, journalctl analysis
- `Lab_02.md` – Writing custom systemd unit files from scratch
- `Lab_03.md` – Deploying a Linux server in the cloud, domain/DNS, SSH key auth
- `Lab_04.md` – Publishing services securely with Caddy as a reverse proxy
- `Lab_05.md` – Deploying web services as Docker containers (bind mounts vs. named volumes)
- `Lab_06.md` – Replacing Caddy with nginx's native ACME module; Docker network segmentation
- `Lab_07.md` – Building custom Docker images with a Dockerfile
- `Lab_08.md` – Managing multi-container applications with Docker Compose

Side labs:
- `Lab_Docker_Rootless.md` – Rootless Docker with Docker Compose on Linux Mint.
- `Lab_07_ausbau.md` – Open-ended exercise: generalize the apt-install Dockerfile pattern to a cron-based backup image; `Lab_07_ausbau_musterloesung.md` holds the sample solution.

Images (banner, navigation arrows, screenshots) are stored in `images/`.

## Authoring Conventions

- Language: **German** throughout (instructions, comments, headings)
- Shell commands are shown in fenced code blocks with `bash` syntax highlighting
- `.ini`/`.conf` snippets use `ini` syntax highlighting
- Explanatory callouts use `>` blockquotes with bold lead-in, e.g. `> **Was passiert hier?**`
- Tables use standard Markdown pipe syntax
- Each lab ends with a navigation footer using `images/previous.png` and `images/next.png`
- Lab metadata footer: authors (Michael Lotter, Florian Reichl), year, version

## Lab Numbering and File Names

Labs follow the pattern `Lab_NN.md` for core exercises and `Lab_NN_ausbau.md` for extension tasks. An `_ausbau` lab may have an accompanying `Lab_NN_ausbau_musterloesung.md` with a full sample solution, kept as a separate file so the exercise itself isn't spoiled. Topic-specific side labs outside the main numbered chain follow `Lab_<Thema>_*.md` (e.g. `Lab_Docker_Rootless.md`) and link into the chain from the lab they extend, without being inserted into that lab's own prev/next footer. When creating new labs, maintain this naming convention and update navigation links in adjacent files.

The root directory also contains working notes (`Lab_06_Notizen.md`, `Lab_Docker_Notizen.md`, `notizen_Lab05_Docker.md`, `Unterschied_LXC_zu_Docker_OCI.md`) — these are informal author notes, not part of the student-facing course, and are not subject to the formatting conventions above.

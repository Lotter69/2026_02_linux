# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a German-language Linux administration lab course (ALP – 2026 cohort). The repository contains practical exercises for students learning Linux system administration, targeting **Linux Mint 21.x (Ubuntu-based)** environments.

## Content Structure

All lab content is written in **Markdown** and follows a consistent format:
- Lab introduction and learning objectives
- Prerequisites table
- Step-by-step tasks with embedded shell commands
- Reflection questions
- Cleanup instructions
- Navigation footer linking to adjacent labs

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

Labs follow the pattern `Lab_NN.md` for core exercises and `Lab_NN_ausbau.md` for extension tasks. When creating new labs, maintain this naming convention and update navigation links in adjacent files.

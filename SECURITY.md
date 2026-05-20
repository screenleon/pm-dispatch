# Security Policy

## Supported versions

Security fixes are applied to the `main` branch only. No backport releases are planned.

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Use either of the following private channels:

- **GitHub Private Security Advisory** (preferred): open a draft advisory at
  https://github.com/screenleon/pm-dispatch/security/advisories/new — fix commits
  are automatically linked to the advisory record.

  1. Open the advisory form link above and fill in the title, description,
     severity (CVSS or qualitative), affected versions, and steps to reproduce.
  2. Submit the draft. The maintainer will acknowledge it and may invite you to a
     **temporary private fork** (GitHub's "Security Advisory private fork"
     feature) to collaborate on a patch.
  3. CVE: the maintainer may request a GitHub-issued CVE from within the advisory.
     If so, the CVE number will be shared with you before publication.
  4. Once a fix is merged and tagged, the maintainer will **publish** the advisory.
     GitHub auto-notifies users who depend on this tool, if they have
     notifications enabled.

  What to include:

  - Vulnerability type and affected component (file/hook name)
  - CVSS score estimate (optional but helpful)
  - Reproduction steps (minimal, ideally a one-liner or script)
  - Proposed fix or mitigation (optional)
  - Whether you need attribution or prefer to stay anonymous
- **Email**: screen.leon@gmail.com

Include:
- A description of the vulnerability and its potential impact
- Steps to reproduce or a minimal proof-of-concept
- Your suggested fix or mitigation (optional)

You will receive an acknowledgement within **7 days**. There is no formal bug-bounty
programme; credit in the changelog or release notes is offered instead.

## Disclosure timeline

| Step | Target |
|---|---|
| Acknowledgement | ≤ 7 days after report |
| Status update | ≤ 30 days |
| Fix or public disclosure | ≤ 90 days |

If the 90-day window cannot be met, the reporter will be notified in advance.

## Scope

**In scope**:
- Hook bypass or sandbox escape (e.g. a crafted input that lets `hook-codex-bash-guard.sh`
  allow a disallowed command)
- Credential or secret exposure through logging or trace files
- Path traversal or symlink attacks in `install.sh` / `link_or_copy`
- Privilege escalation via hook or install scripts

**Out of scope**:
- Issues requiring physical access to the machine
- Social engineering
- Denial-of-service against the local CLI
- Vulnerabilities in third-party dependencies (report upstream)

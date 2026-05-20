# Security Policy

## Supported versions

Security fixes are applied to the `main` branch only. No backport releases are planned.

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Use either of the following private channels:

- **GitHub Private Security Advisory** (preferred): open a draft advisory at
  https://github.com/screenleon/pm-dispatch/security/advisories/new — fix commits
  are automatically linked to the advisory record.
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

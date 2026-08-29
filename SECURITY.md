# Security Policy

## Reporting a Vulnerability

This framework handles API keys and other secrets (see `01-secrets.sh`/`secrets_manager.py`), so please report security issues privately rather than opening a public issue.

Use GitHub's private vulnerability reporting: go to the **Security** tab of this repository → **Report a vulnerability**. This opens a private advisory visible only to you and the maintainer until a fix is ready.

Please include:
- The affected file(s)/function(s) and framework version (`mt-get-version`)
- Steps to reproduce, or a proof-of-concept
- The potential impact (e.g., arbitrary command execution, secret exposure)

## Supported Versions

Only the latest released version is supported. Run `mt-get-update` to update before reporting an issue that may already be fixed.

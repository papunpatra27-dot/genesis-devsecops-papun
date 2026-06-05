"""
app/flaws/flaw2_sast.py

INTENTIONAL SECURITY FLAWS — FOR PIPELINE DEMONSTRATION ONLY.
This file exists to prove Stage 3 (Semgrep SAST) gate works.

Semgrep with rulesets p/python and p/owasp-top-ten will flag:
  - eval() on user input → CWE-94 Code Injection
  - subprocess with shell=True → CWE-78 OS Command Injection

DO NOT import or call any function in this file from production code.
The file is scanned but never executed in the application.
"""
import subprocess  # noqa: S404


def dangerous_eval(user_input: str):  # noqa: ANN201
    """
    FLAW 2a — Code Injection (CWE-94).
    eval() on user-supplied data executes arbitrary Python.
    Semgrep rule: python.lang.security.audit.eval-detected.eval-detected
    """
    # Semgrep: python.lang.security.audit.eval-detected
    return eval(user_input)  # noqa: S307 — intentional demo flaw


def unsafe_command(cmd: str) -> str:  # noqa: ANN201
    """
    FLAW 2b — OS Command Injection (CWE-78).
    shell=True with user-controlled input allows command injection.
    Semgrep rule: python.lang.security.audit.subprocess-shell-true
    """
    # Semgrep: python.lang.security.audit.subprocess-shell-true
    result = subprocess.run(  # noqa: S602 — intentional demo flaw
        cmd,
        shell=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def hardcoded_password() -> str:  # noqa: ANN201
    """
    FLAW 2c — Hardcoded credential (CWE-798).
    Semgrep rule: generic.secrets.security.detected-generic-secret
    """
    # Semgrep will flag this as a hardcoded secret
    db_password = "s3cr3t-hardcoded-password-12345"  # noqa: S105 — intentional demo
    return db_password

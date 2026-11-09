"""Offline checks for accidental release configuration regressions.

This is not a certificate-signing, App Store privacy, or live API audit.
"""
from pathlib import Path
import re
import subprocess

REPO = Path(__file__).resolve().parents[1]
SENSITIVE_SUFFIXES = (".p12", ".p8", ".mobileprovision", ".provisionprofile", ".cer", ".key", ".pem")
SENSITIVE_NAMES = (".env", "id_rsa", "id_ed25519")


def audit(project: str, tracked_paths: list[str]) -> list[str]:
    issues: list[str] = []

    if not re.search(r'^\s*PRODUCT_BUNDLE_IDENTIFIER:\s*com\.iosdevbyul\.TrisMarketLens\s*$', project, re.M):
        issues.append("Expected stable app bundle identifier missing")

    if not re.search(r'^\s*iOS:\s*["\']?17\.0["\']?\s*$', project, re.M):
        issues.append("iOS 17 deployment minimum missing")

    # Reject accidental production-style launch against a debug localhost server.
    if not re.search(r'^\s*TRIS_DATA_MODE:\s*disconnected\s*$', project, re.M):
        issues.append("Default Xcode launch must be disconnected")
    if re.search(r'^\s*TRIS_API_BASE_URL\s*:', project, re.M):
        issues.append("Xcode scheme must not embed an API base URL")

    if re.search(r'NSAllowsArbitraryLoads\s*:\s*(?:YES|true|1)\b', project, re.I):
        issues.append("Broad App Transport Security exception must not be enabled")
    if re.search(r'NSExceptionAllowsInsecureHTTPLoads\s*:\s*(?:YES|true|1)\b', project, re.I):
        issues.append("Insecure ATS domain exception must not be enabled")

    for path in tracked_paths:
        name = Path(path).name.lower()
        if name in SENSITIVE_NAMES or (name.endswith(SENSITIVE_SUFFIXES) and not name.endswith(".example")):
            issues.append(f"Potential secret or signing material tracked: {path}")

    return issues


def tracked_files(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--cached", "--full-name"],
        check=True, capture_output=True, text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


if __name__ == "__main__":
    findings = audit((REPO / "project.yml").read_text(encoding="utf-8"), tracked_files(REPO))
    for finding in findings:
        print("RELEASE CONFIG AUDIT:", finding)
    if findings:
        raise SystemExit(1)
    print("RELEASE CONFIG AUDIT: source configuration checks passed; signing/privacy/device remain manual")

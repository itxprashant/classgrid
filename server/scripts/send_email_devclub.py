#!/usr/bin/env python3
"""Send an email via AWS SES SMTP (devclub).

Credentials come from the environment (never hardcode secrets):

  SMTP_HOST   default email-smtp.us-east-1.amazonaws.com
  SMTP_PORT   default 587
  SMTP_USER   required
  SMTP_PASS   required
  SMTP_FROM   default prashant@devclub.in

Used by the ClassGrid admin API and as a CLI helper.
"""

from __future__ import annotations

import argparse
import os
import smtplib
import sys
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

SMTP_HOST = os.environ.get("SMTP_HOST", "email-smtp.us-east-1.amazonaws.com").strip()
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587") or "587")
SMTP_USER = (os.environ.get("SMTP_USER") or "").strip()
SMTP_PASS = (os.environ.get("SMTP_PASS") or "").strip()
SMTP_FROM = (os.environ.get("SMTP_FROM") or "prashant@devclub.in").strip()


def send_email(
    *,
    to: str,
    subject: str,
    body: str,
    html: bool = False,
) -> None:
    if not SMTP_USER or not SMTP_PASS:
        raise RuntimeError("SMTP_USER and SMTP_PASS must be set in the environment")

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = SMTP_FROM
    msg["To"] = to

    content_type = "html" if html else "plain"
    msg.attach(MIMEText(body, content_type, "utf-8"))

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as server:
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(SMTP_USER, SMTP_PASS)
        server.sendmail(SMTP_FROM, [to], msg.as_string())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Send an email via devclub.in SMTP.")
    parser.add_argument("to", help="Recipient email address")
    parser.add_argument(
        "-s",
        "--subject",
        default="Test Email",
        help="Email subject (default: Test Email)",
    )
    parser.add_argument(
        "-m",
        "--message",
        help="Email body text (default: a short test message)",
    )
    parser.add_argument(
        "-f",
        "--file",
        help="Read email body from a file (use - for stdin)",
    )
    parser.add_argument(
        "--html",
        action="store_true",
        help="Treat body as HTML",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.file == "-":
        body = sys.stdin.read()
    elif args.file:
        with open(args.file, encoding="utf-8") as handle:
            body = handle.read()
    elif args.message:
        body = args.message
    else:
        body = "This is a test message sent via send_email_devclub.py."

    try:
        send_email(
            to=args.to,
            subject=args.subject,
            body=body,
            html=args.html,
        )
    except (smtplib.SMTPException, OSError, RuntimeError) as exc:
        print(f"Failed to send email: {exc}", file=sys.stderr)
        return 1

    print(f"Sent email to {args.to}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

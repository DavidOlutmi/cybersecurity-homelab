"""
Alert summarizer, version 1.

Reads one saved security event from alert.json, sends it to a local
Ollama model, and prints a plain-language summary.

Setup (once):
    pip install requests
    ollama pull llama3.1:8b

Run:
    python summarize_alert.py
"""

import json

import requests

OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "llama3.1:8b"
ALERT_FILE = "alert.json"

# The system prompt sets standing rules. The alert data goes in separately,
# as the user message, so the model treats these as instructions and not as
# more text to summarize.
SYSTEM_PROMPT = (
    "You are a SOC analyst assistant. You will be given either one security "
    "event or a JSON array of several. Base your summary only on the data "
    "provided. Do not speculate, infer, or add details that are not in the "
    "input. Do not recommend actions unless the data directly supports them.\n\n"
    "Write a plain-language summary a non-technical reader could understand, "
    "covering:\n"
    "1. If more than one event is present, state the exact count and the "
    "date range they span. Do not say 'multiple' or 'several' without the "
    "actual number.\n"
    "2. The account and service involved.\n"
    "3. The Kerberos ticket encryption type for each event, stated "
    "explicitly (e.g. 'RC4' for 0x17, 'AES' for 0x12 or 0x11). Never omit "
    "this field.\n"
    "4. Whether the pattern (e.g. repeated requests for the same service "
    "over time) is something a human analyst should review, without "
    "declaring a verdict yourself."
)


def load_alert(path):
    # utf-8-sig handles the invisible BOM that PowerShell can add to files.
    with open(path, encoding="utf-8-sig") as f:
        return f.read()


def describe_alert(alert_text):
    """Return a short, human-readable line describing what was loaded."""
    try:
        data = json.loads(alert_text)
    except json.JSONDecodeError:
        return "1 event (plain text)"
    if isinstance(data, list):
        return f"{len(data)} event(s) loaded"
    return "1 event loaded"


def print_heading(text):
    line = "=" * len(text)
    print(f"\n{line}\n{text}\n{line}\n")


def summarize(alert_text):
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": "Summarize this security event:\n\n" + alert_text},
        ],
        # Low temperature keeps the summary factual and consistent.
        "options": {"temperature": 0.2},
        "stream": False,
    }
    response = requests.post(OLLAMA_URL, json=payload, timeout=300)
    response.raise_for_status()
    return response.json()["message"]["content"]


if __name__ == "__main__":
    print_heading("AI Alert Summarizer")

    alert_text = load_alert(ALERT_FILE)
    print(f"Loaded {ALERT_FILE}: {describe_alert(alert_text)}")

    print(f"Sending to {MODEL} (this can take a minute on the first run)...")
    result = summarize(alert_text)

    print_heading("Summary")
    print(result)
    print()

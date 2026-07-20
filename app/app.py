import os
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

BUILD_NUMBER = os.environ.get("BUILD_NUMBER", "dev")
GIT_COMMIT = os.environ.get("GIT_COMMIT", "unknown")
APP_NAME = os.environ.get("APP_NAME", "pipeline-demo")
STARTED_AT = datetime.now(timezone.utc).isoformat(timespec="seconds")

PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ app_name }} &middot; build {{ build }}</title>
  <style>
    :root { color-scheme: dark; }
    * { box-sizing: border-box; }
    body {
      margin: 0; min-height: 100vh; display: grid; place-items: center;
      background: #0b0f19;
      color: #e6e9ef;
      font: 16px/1.5 ui-sans-serif, -apple-system, "Segoe UI", Roboto, sans-serif;
      padding: 2rem;
    }
    .card {
      width: min(560px, 100%);
      background: #131828;
      border: 1px solid #232a40;
      border-radius: 14px;
      padding: 2rem;
      box-shadow: 0 18px 40px rgba(0,0,0,.45);
    }
    .pill {
      display: inline-block; font-size: .75rem; letter-spacing: .08em;
      text-transform: uppercase; color: #7ee2b8; background: #10281f;
      border: 1px solid #1e5340; border-radius: 999px; padding: .25rem .7rem;
    }
    h1 { margin: 1rem 0 .25rem; font-size: 1.6rem; }
    p.sub { margin: 0 0 1.5rem; color: #93a0bd; }
    dl { display: grid; grid-template-columns: auto 1fr; gap: .6rem 1.25rem; margin: 0; }
    dt { color: #93a0bd; font-size: .875rem; }
    dd { margin: 0; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .875rem; word-break: break-all; }
    footer { margin-top: 1.75rem; padding-top: 1rem; border-top: 1px solid #232a40; color: #6b7896; font-size: .8rem; }
  </style>
</head>
<body>
  <main class="card">
    <span class="pill">Deployed by Terraform</span>
    <h1>{{ app_name }}</h1>
    <p class="sub">Git &rarr; Jenkins &rarr; Docker build &rarr; Terraform apply &rarr; running container.</p>
    <dl>
      <dt>Build number</dt><dd>{{ build }}</dd>
      <dt>Git commit</dt><dd>{{ commit }}</dd>
      <dt>Container host</dt><dd>{{ host }}</dd>
      <dt>Started at</dt><dd>{{ started }}</dd>
    </dl>
    <footer>Health endpoint: <code>/health</code> &middot; JSON info: <code>/api/info</code></footer>
  </main>
</body>
</html>
"""


@app.get("/")
def index():
    return render_template_string(
        PAGE,
        app_name=APP_NAME,
        build=BUILD_NUMBER,
        commit=GIT_COMMIT,
        host=socket.gethostname(),
        started=STARTED_AT,
    )


@app.get("/health")
def health():
    return jsonify(status="ok"), 200


@app.get("/api/info")
def info():
    return jsonify(
        app=APP_NAME,
        build_number=BUILD_NUMBER,
        git_commit=GIT_COMMIT,
        hostname=socket.gethostname(),
        started_at=STARTED_AT,
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

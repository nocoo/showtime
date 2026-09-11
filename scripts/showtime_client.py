"""Small, dependency-free client for Showtime's authenticated loopback API."""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from copy import deepcopy
from pathlib import Path

from showtime_schema import check_action, check_script


class ShowtimeError(RuntimeError):
    pass


CONNECTION = Path.home() / "Library/Application Support/Showtime/connection.json"


class Client:
    def __init__(self, connection: str | Path | None = None):
        path = Path(connection or os.environ.get("SHOWTIME_CONNECTION", CONNECTION)).expanduser()
        try:
            info = json.loads(path.read_text())
        except (OSError, ValueError) as exc:
            raise ShowtimeError("Showtime is not running. Open Showtime.app or run scripts/run.sh.") from exc
        parsed = urllib.parse.urlparse(info.get("url", ""))
        if parsed.scheme != "http" or parsed.hostname not in ("127.0.0.1", "localhost") or not parsed.port or parsed.username:
            raise ShowtimeError("connection.json must point to Showtime on the loopback interface.")
        if not isinstance(info.get("token"), str) or len(info["token"]) < 32:
            raise ShowtimeError("connection.json does not contain a valid session token. Restart Showtime.")
        self.url = info["url"].rstrip("/")
        self.token = info["token"]
        # Do not route a local bearer token through an HTTP proxy or follow redirects.
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, headers, newurl):
                return None
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def request(self, method: str, path: str, body=None, timeout: float = 60):
        if not path.startswith("/v1/"):
            raise ShowtimeError("Control requests must use a /v1/ path.")
        data = None if body is None else json.dumps(body, ensure_ascii=False, allow_nan=False).encode()
        request = urllib.request.Request(self.url + path, data=data, method=method, headers={
            "Authorization": "Bearer " + self.token,
            "Content-Type": "application/json",
        })
        try:
            with self.opener.open(request, timeout=timeout) as response:
                return json.load(response)
        except urllib.error.HTTPError as exc:
            try:
                message = json.load(exc).get("error", str(exc))
            except (ValueError, AttributeError):
                message = str(exc)
            raise ShowtimeError(f"HTTP {exc.code}: {message}") from exc
        except (urllib.error.URLError, TimeoutError, ConnectionError) as exc:
            raise ShowtimeError(f"Could not reach Showtime. Is the app open? {exc}") from exc

    def status(self):
        return self.request("GET", "/v1/status")

    def wait(self, job_id: str, timeout: float = 3600):
        deadline = time.monotonic() + timeout
        while True:
            job = self.request("GET", "/v1/jobs/" + urllib.parse.quote(job_id, safe=""))
            if job["status"] not in ("running", "queued"):
                if job["status"] == "failed":
                    raise ShowtimeError(f"Job {job_id}: {job.get('error', 'Job failed')}")
                return job
            if time.monotonic() >= deadline:
                raise ShowtimeError(f"Timed out waiting for {job_id}; the job may still be running. Use wait or stop.")
            time.sleep(0.15)

    def act(self, step: dict, wait: bool = True):
        return self.design(step, wait=wait)

    def design(self, step: dict, wait: bool = True, screenshot: str | None = None):
        check_action(step)
        body = {"step": resolve_script_paths({"steps": [step]})["steps"][0]}
        if screenshot:
            body["screenshot"] = absolute_path(screenshot)
        result = self.request("POST", "/v1/design", body)
        return self.wait(result["job"]) if wait else result

    def run(self, script: dict, wait: bool = True):
        check_script(script)
        return self.play(script, "record" if "recording" in script else "rehearse", wait=wait)

    def play(self, script: dict, mode: str, wait: bool = True, **options):
        if mode not in ("rehearse", "record"):
            raise ShowtimeError("Playback mode must be rehearse or record.")
        check_script(script)
        body = {"script": resolve_script_paths(script), **options}
        for key in ("output", "screenshot"):
            if key in body:
                body[key] = absolute_path(body[key])
        result = self.request("POST", "/v1/" + mode, body)
        return self.wait(result["job"]) if wait else result

    def validate(self, script: dict, mode: str = "rehearse", **options):
        check_script(script)
        body = {"script": resolve_script_paths(script), "mode": mode, **options}
        for key in ("output", "screenshot"):
            if key in body:
                body[key] = absolute_path(body[key])
        return self.request("POST", "/v1/validate", body)


def absolute_path(path: str, base: Path | None = None) -> str:
    value = Path(path).expanduser()
    return str((value if value.is_absolute() else (base or Path.cwd()) / value).resolve())


def resolve_script_paths(script: dict, base: Path | None = None) -> dict:
    """Resolve local assets relative to the script; URLs keep their browser semantics."""
    check_script(script)
    script = deepcopy(script)
    if script.get("recording", {}).get("output"):
        script["recording"]["output"] = absolute_path(script["recording"]["output"], base)
    def walk(steps):
        for step in steps:
            for key in ("output", "image"):
                if step.get(key):
                    step[key] = absolute_path(step[key], base)
            walk(step.get("steps", []))
    walk(script.get("steps", []))
    walk(script.get("setup", []))
    return script

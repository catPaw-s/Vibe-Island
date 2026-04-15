#!/usr/bin/env python3
"""
Codex hook bridge for ClaudeIsland.
"""
import json
import os
import socket
import sys

SOCKET_PATH = "/tmp/claude-island.sock"
TIMEOUT_SECONDS = 300


def get_tty():
    import subprocess

    ppid = os.getppid()

    try:
        result = subprocess.run(
            ["ps", "-p", str(ppid), "-o", "tty="],
            capture_output=True,
            text=True,
            timeout=2,
        )
        tty = result.stdout.strip()
        if tty and tty not in {"??", "-"}:
            if not tty.startswith("/dev/"):
                tty = "/dev/" + tty
            return tty
    except Exception:
        pass

    for stream in (sys.stdin, sys.stdout):
        try:
            return os.ttyname(stream.fileno())
        except Exception:
            continue
    return None


def send_event(payload):
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(TIMEOUT_SECONDS)
        sock.connect(SOCKET_PATH)
        sock.sendall(json.dumps(payload).encode())

        if payload.get("status") == "waiting_for_approval":
            response = sock.recv(4096)
            sock.close()
            if response:
                return json.loads(response.decode())
        else:
            sock.close()
    except Exception:
        return None

    return None


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(1)

    event = data.get("hook_event_name", "")
    state = {
        "session_id": data.get("session_id", "unknown"),
        "cwd": data.get("cwd", ""),
        "event": event,
        "pid": os.getppid(),
        "tty": get_tty(),
        "source": "codex",
    }

    if event == "UserPromptSubmit":
        state["status"] = "processing"
    elif event == "Stop":
        state["status"] = "waiting_for_input"
    elif event == "SessionStart":
        state["status"] = "waiting_for_input"
    elif event == "PreToolUse":
        state["status"] = "running_tool"
        state["tool"] = data.get("tool_name")
        state["tool_input"] = data.get("tool_input", {})
        if data.get("tool_use_id"):
            state["tool_use_id"] = data.get("tool_use_id")
    elif event == "PermissionRequest":
        state["status"] = "waiting_for_approval"
        state["tool"] = data.get("tool_name")
        state["tool_input"] = data.get("tool_input", {})

        response = send_event(state)
        if response:
            decision = response.get("decision", "ask")
            reason = response.get("reason", "")

            if decision == "allow":
                print(json.dumps({
                    "hookSpecificOutput": {
                        "hookEventName": "PermissionRequest",
                        "decision": {"behavior": "allow"},
                    }
                }))
                sys.exit(0)

            if decision == "deny":
                print(json.dumps({
                    "hookSpecificOutput": {
                        "hookEventName": "PermissionRequest",
                        "decision": {
                            "behavior": "deny",
                            "message": reason or "Denied by user via ClaudeIsland",
                        },
                    }
                }))
                sys.exit(0)

        sys.exit(0)
    elif event == "PostToolUse":
        state["status"] = "processing"
        state["tool"] = data.get("tool_name")
        state["tool_input"] = data.get("tool_input", {})
        if data.get("tool_use_id"):
            state["tool_use_id"] = data.get("tool_use_id")
    else:
        state["status"] = "unknown"

    send_event(state)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
VTB File Upload Server
Receives multipart/form-data uploads, saves files organised by session.
Accessible only via internal Docker network (proxied through nginx).
"""
import os
import uuid
from datetime import datetime
from flask import Flask, request, jsonify

app = Flask(__name__)
UPLOAD_DIR = "/uploads"


def cors(response):
    response.headers["Access-Control-Allow-Origin"]  = "*"
    response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, X-Requested-With"
    return response


@app.after_request
def after_request(response):
    return cors(response)


@app.route("/upload", methods=["OPTIONS"], strict_slashes=False)
@app.route("/upload/", methods=["OPTIONS"], strict_slashes=False)
def upload_options():
    return jsonify({}), 200


@app.route("/upload", methods=["POST"], strict_slashes=False)
@app.route("/upload/", methods=["POST"], strict_slashes=False)
def upload():
    timestamp  = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    session_id = str(uuid.uuid4())[:8]
    session_dir = os.path.join(UPLOAD_DIR, f"{timestamp}_{session_id}")
    os.makedirs(session_dir, exist_ok=True)

    # — Metadata —
    firstname = request.form.get("firstname", "unknown")
    lastname  = request.form.get("lastname",  "unknown")
    ip        = request.headers.get("X-Forwarded-For", request.remote_addr)
    ua        = request.headers.get("User-Agent", "N/A")

    with open(os.path.join(session_dir, "_info.txt"), "w") as f:
        f.write(f"Name      : {firstname} {lastname}\n")
        f.write(f"Timestamp : {datetime.now()}\n")
        f.write(f"IP        : {ip}\n")
        f.write(f"UserAgent : {ua}\n")

    # — Files —
    files_saved = []
    for file in request.files.getlist("files"):
        if file and file.filename:
            safe_name = os.path.basename(file.filename)
            dest = os.path.join(session_dir, safe_name)
            # avoid overwriting duplicates
            if os.path.exists(dest):
                base, ext = os.path.splitext(safe_name)
                safe_name = f"{base}_{str(uuid.uuid4())[:4]}{ext}"
                dest = os.path.join(session_dir, safe_name)
            file.save(dest)
            files_saved.append(safe_name)

    # Append filenames to info
    with open(os.path.join(session_dir, "_info.txt"), "a") as f:
        f.write(f"Files     : {', '.join(files_saved) or 'none'}\n")

    print(f"[UPLOAD] {firstname} {lastname} | {ip} | files: {files_saved}", flush=True)
    return jsonify({"status": "ok", "session": session_id, "files": files_saved}), 200


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200


if __name__ == "__main__":
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    app.run(host="0.0.0.0", port=8080, debug=False)

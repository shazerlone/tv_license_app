
from flask import Flask, request, jsonify, render_template, redirect, url_for
import json, os
from datetime import datetime

app = Flask(__name__)

LICENSE_FILE = "licenses.json"
SIGNAL_FILE = "signal.json"

def load_licenses():
    if not os.path.exists(LICENSE_FILE):
        return {}
    with open(LICENSE_FILE, "r") as f:
        return json.load(f)

def save_licenses(data):
    with open(LICENSE_FILE, "w") as f:
        json.dump(data, f, indent=4)

def is_license_valid(license_id: str) -> bool:
    licenses = load_licenses()
    return license_id in licenses and licenses[license_id].get("enabled")

@app.route("/")
def home():
    return redirect(url_for("dashboard"))

@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.get_json(force=True, silent=True)
    if data is None:
        return jsonify({"status": "error", "reason": "No JSON"}), 400
    license_id = data.get("licenseID")
    if not is_license_valid(license_id):
        return jsonify({"status": "blocked", "reason": "Invalid or disabled license"}), 403
    with open(SIGNAL_FILE, "w") as f:
        json.dump(data, f, indent=4)
    return jsonify({"status": "received"}), 200

@app.route("/dashboard")
def dashboard():
    signal = {}
    if os.path.exists(SIGNAL_FILE):
        with open(SIGNAL_FILE) as f:
            signal = json.load(f)
    return render_template("dashboard.html", signal=signal)

@app.route("/admin")
def admin():
    licenses = load_licenses()
    return render_template("admin.html", licenses=licenses)

@app.route("/admin/toggle/<license_id>")
def toggle_license(license_id):
    licenses = load_licenses()
    if license_id in licenses:
        licenses[license_id]["enabled"] = not licenses[license_id]["enabled"]
        save_licenses(licenses)
    return redirect(url_for("admin"))

@app.route("/admin/create", methods=["POST"])
def create_license():
    license_id = request.form.get("licenseID")
    owner = request.form.get("owner", "unknown")
    if not license_id:
        return redirect(url_for("admin"))
    licenses = load_licenses()
    licenses[license_id] = {
        "owner": owner,
        "enabled": True,
        "created": str(datetime.utcnow().date())
    }
    save_licenses(licenses)
    return redirect(url_for("admin"))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

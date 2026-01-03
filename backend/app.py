# from flask import Flask, render_template, jsonify, request, Response, session, redirect, url_for, send_file
from flask import (
    Flask, render_template, jsonify, request,
    Response, session, redirect, send_file
)
from auth import Auth, login_required
import json
import os
import subprocess
from camera import Camera
from network import Network
from system import System
from stream import Stream
import atexit
import io
import requests
from flask import stream_with_context

import time
import threading


app = Flask(__name__, 
           template_folder='/home/pi/ipcam/frontend/templates',
           static_folder='/home/pi/ipcam/frontend/static')

CONFIG_PATH = '/home/pi/ipcam/backend/config.json'
camera = Camera(CONFIG_PATH)
network = Network()
system = System()
stream = Stream(CONFIG_PATH)

app.secret_key = "ipcam-secret-key"   # change later
auth = Auth(CONFIG_PATH)

# # HLS Configuration
# HLS_DIR = "/tmp/hls"
# HLS_PLAYLIST = "/tmp/hls/stream.m3u8"

HLS_FIXED_PORT = 8888


def load_config():
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

def cleanup():
    print("Backend shutdown")

atexit.register(cleanup)




# =============================================================================
# Backend log auto-cleanup (24 hours)
# =============================================================================

BACKEND_LOG_FILE = "/home/pi/ipcam/logs/backend.log"
LOG_MAX_AGE = 24 * 60 * 60      # 24 hours
LOG_CHECK_INTERVAL = 60 * 60   # check every 1 hour


def backend_log_cleanup():
    while True:
        try:
            if os.path.exists(BACKEND_LOG_FILE):
                age = time.time() - os.path.getmtime(BACKEND_LOG_FILE)

                if age > LOG_MAX_AGE:
                    # SAFER OPTION: truncate instead of delete
                    with open(BACKEND_LOG_FILE, "w"):
                        pass
                    print("backend.log truncated (older than 24h)")
        except Exception as e:
            print(f"Backend log cleanup error: {e}")

        time.sleep(LOG_CHECK_INTERVAL)



@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        data = request.form
        if auth.check_credentials(data['username'], data['password']):
            session['logged_in'] = True
            return redirect('/')
        return render_template('login.html', error="Invalid credentials")
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect('/login')

@app.route('/')
@login_required
def index():
    return render_template('base.html')

@app.route('/live')
@login_required
def live():
    return render_template('live.html')

@app.route('/camera')
@login_required
def camera_page():
    return render_template('camera.html')

@app.route('/network')
@login_required
def network_page():
    return render_template('network.html')

@app.route('/stream')
@login_required
def stream_page():
    return render_template('stream.html')

@app.route('/system')
@login_required
def system_page():
    return render_template('system.html')

# Camera API endpoints
@app.route('/api/camera/settings', methods=['GET'])
def get_camera_settings():
    return jsonify(camera.get_settings())

@app.route('/api/camera/settings', methods=['POST'])
def update_camera_settings():
    data = request.json
    result = camera.update_settings(data)
    return jsonify(result)

@app.route('/api/camera/reset', methods=['POST'])
def reset_camera_settings():
    result = camera.reset_to_default()
    return jsonify(result)


@app.route("/api/camera/preview")
def camera_preview():
    """MJPEG stream from camera module"""
    try:
        return Response(
            camera.mjpeg_stream(),
            mimetype="multipart/x-mixed-replace; boundary=frame"
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500




@app.route('/api/camera/snapshot')
def camera_snapshot():
    try:
        result = subprocess.run(
            [
                'rpicam-still',
                '--timeout', '1',
                '--width', '1280',
                '--height', '720',
                '--nopreview',
                '--encoding', 'jpg',
                '--quality', '85',
                '-o', '-'
            ],
            capture_output=True,
            timeout=5
        )

        if result.returncode == 0:
            return Response(result.stdout, mimetype='image/jpeg')
        return jsonify({"error": "Camera not available"}), 500

    except Exception as e:
        return jsonify({"error": str(e)}), 500





@app.route('/api/stream/hls')
def hls_playlist():
    cfg = load_config()
    server_ip = cfg['stream']['server_ip']
    stream_name = cfg['stream']['stream_name']

    # ✅ NO index.m3u8 (as per your rule)
    hls_url = f"http://{server_ip}:{HLS_FIXED_PORT}/{stream_name}"

    r = requests.get(
        hls_url,
        auth=(cfg['auth']['username'], cfg['auth']['password']),
        timeout=5
    )

    if r.status_code != 200:
        return jsonify({"error": "HLS not available"}), 404

    playlist = r.text

    # 🔴 REQUIRED: rewrite relative paths
    rewritten = []
    for line in playlist.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            rewritten.append(line)
        else:
            # rewrite ALL media references
            rewritten.append(f"/api/stream/hls/{line}")

    return Response(
        "\n".join(rewritten),
        content_type="application/vnd.apple.mpegurl",
        headers={
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-cache"
        }
    )



@app.route('/api/stream/hls/<path:file>')
def hls_file(file):
    cfg = load_config()
    server_ip = cfg['stream']['server_ip']
    stream_name = cfg['stream']['stream_name']

    url = f"http://{server_ip}:{HLS_FIXED_PORT}/{stream_name}/{file}"

    r = requests.get(
        url,
        auth=(cfg['auth']['username'], cfg['auth']['password']),
        stream=True,
        timeout=5
    )

    content_type = (
        "application/vnd.apple.mpegurl"
        if file.endswith(".m3u8")
        else "video/mp2t"
    )

    return Response(
        stream_with_context(r.iter_content(8192)),
        content_type=content_type,
        headers={
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-cache"
        }
    )


@app.route('/api/stream/hls/check')
def check_hls_status():
    """Check if HLS stream is available"""
    hls_available = os.path.exists(HLS_PLAYLIST)
    
    status = {
        "available": hls_available,
        "playlist_path": HLS_PLAYLIST,
        "directory": HLS_DIR,
        "directory_exists": os.path.exists(HLS_DIR)
    }
    
    if hls_available:
        # Count segments
        try:
            segments = [f for f in os.listdir(HLS_DIR) if f.endswith('.ts')]
            status["segments_count"] = len(segments)
            status["playlist_size"] = os.path.getsize(HLS_PLAYLIST)
        except:
            pass
    
    return jsonify(status)


    
@app.route('/api/stream/mjpeg')
def mjpeg_proxy():
    import requests

    config = stream.load_config()
    s = config.get("stream", {})

    mjpeg_url = f"http://{s['server_ip']}:8888/{s['stream_name']}"

    def generate():
        with requests.get(mjpeg_url, stream=True) as r:
            for chunk in r.iter_content(chunk_size=1024):
                if chunk:
                    yield chunk

    return Response(
        generate(),
        mimetype='multipart/x-mixed-replace; boundary=frame'
    )




# ============================================================================
# Network API endpoints
# ============================================================================

@app.route('/api/network/status', methods=['GET'])
@login_required
def get_network_status():
    return jsonify(network.get_status())


@app.route('/api/network/info', methods=['GET'])
@login_required
def get_network_info():
    return jsonify(network.get_network_info())

@app.route('/api/network/wifi', methods=['POST'])
@login_required
def configure_wifi():
    data = request.get_json(force=True)
    result = network.configure_wifi(data)
    return jsonify(result)

@app.route("/api/network/static", methods=["POST"])
@login_required
def set_static_ip():
    # return network.save_static_ip(request.json)
    data = request.json
    cfg = network.load_config()
    cfg["network"]["current"] = {
        "mode": "static",
        "ip_address": data["ip_address"],
        "gateway": data["gateway"],
        "dns": data.get("dns", "8.8.8.8")
    }
    network.save_config(cfg)
    return jsonify(network.apply_from_config())


@app.route("/api/network/dhcp", methods=["POST"])
@login_required
def set_dhcp():
    return network.set_dhcp()


@app.route("/api/network/reset", methods=["POST"])
@login_required
def reset_network():
    return network.reset_to_default()



@app.route('/api/network/scan', methods=['GET'])
@login_required
def scan_wifi():
    try:
        result = network.scan_wifi()
        return jsonify(result)
    except Exception as e:
        return jsonify({
            "success": False,
            "message": str(e),
            "networks": []
        })

# Stream API endpoints
@app.route('/api/stream/status', methods=['GET'])
def get_stream_status():
    return jsonify(stream.get_status())

@app.route('/api/stream/settings', methods=['GET'])
def get_stream_settings():
    return jsonify(stream.get_settings())

@app.route('/api/stream/settings', methods=['POST'])
def update_stream_settings():
    data = request.json
    result = stream.update_settings(data)
    return jsonify(result)

@app.route('/api/stream/start', methods=['POST'])
def start_stream():
    result = stream.start()
    return jsonify(result)

@app.route('/api/stream/stop', methods=['POST'])
def stop_stream():
    result = stream.stop()
    return jsonify(result)

@app.route('/api/stream/restart', methods=['POST'])
def restart_stream():
    result = stream.restart()
    return jsonify(result)

# System API endpoints
@app.route('/api/system/info', methods=['GET'])
@login_required
def get_system_info():
    return jsonify(system.get_info())

@app.route('/api/system/reboot', methods=['POST'])
@login_required
def reboot_system():
    result = system.reboot()
    return jsonify(result)

@app.route('/api/system/shutdown', methods=['POST'])
@login_required
def shutdown_system():
    result = system.shutdown()
    return jsonify(result)

@app.route('/api/system/logs', methods=['GET'])
@login_required
def get_logs():
    log_type = request.args.get('type', 'stream')
    return jsonify(system.get_logs(log_type))


# ============================================================================
# CORS Support
# ============================================================================

@app.after_request
def after_request(response):
    """Add CORS headers to all responses"""
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    return response


if __name__ == '__main__':
    # Ensure HLS directory exists on startup
    # os.makedirs(HLS_DIR, exist_ok=True)

    # Start backend log cleanup thread
    log_thread = threading.Thread(
        target=backend_log_cleanup,
        daemon=True
    )
    log_thread.start()
    
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
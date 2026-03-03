# import socketio,requests,subprocess,json,threading,os,socket,time

# SERVER="http://192.168.1.6:8080"
# CONFIG="/home/pi/ipcam/backend/config.json"
# TEMP="/tmp/cap.jpg"

# sio=socketio.Client(reconnection=True)

# def cam_info():
#     with open(CONFIG) as f:
#         c=json.load(f)
#     return c["stream"]["stream_name"],c["auth"]["username"],c["auth"]["password"]

# def local_ip():
#     s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
#     s.connect(("8.8.8.8",80))
#     ip=s.getsockname()[0]; s.close()
#     return ip

# def capture(rtsp):
#     return subprocess.run(
#         ["ffmpeg","-y","-loglevel","error","-i",rtsp,"-frames:v","1",TEMP]
#     ).returncode==0

# def job(request_id):
#     cam,user,pwd=cam_info()
#     ip=local_ip()

#     streams=[
#         ("Main",f"rtsp://{user}:{pwd}@{ip}:8554/{cam}/Main"),
#         ("Sub", f"rtsp://{user}:{pwd}@{ip}:8554/{cam}/Sub")
#     ]

#     for name,url in streams:
#         if capture(url):
#             with open(TEMP,"rb") as f:
#                 requests.post(
#                     f"{SERVER}/upload-image/{cam}",
#                     files={"file":f},
#                     data={"request_id":request_id,"stream_used":name},
#                     timeout=10
#                 )
#             os.remove(TEMP)
#             return

#     requests.post(
#         f"{SERVER}/capture-failed",
#         json={
#             "request_id":request_id,
#             "camera_id":cam,
#             "error":"Camera offline or streams unavailable"
#         },
#         timeout=5
#     )

# @sio.event
# def connect():
#     cam,_,_=cam_info()
#     sio.emit("register",{"cam_id":cam})

# @sio.on("capture_now")
# def capture_now(data):
#     threading.Thread(
#         target=job,
#         args=(data["request_id"],),
#         daemon=True
#     ).start()

# def heartbeat():
#     cam,_,_=cam_info()
#     while True:
#         sio.emit("heartbeat",{"cam_id":cam})
#         time.sleep(5)

# if __name__=="__main__":
#     sio.connect(SERVER)
#     threading.Thread(target=heartbeat,daemon=True).start()
#     sio.wait()



import socketio
import requests
import subprocess
import json
import threading
import os
import socket
import time

# ───────── CONFIG ─────────
SERVER = "http://192.168.1.9:8080"
# SERVER = "http://69.62.73.222:8001"
CONFIG = "/home/pi/ipcam/backend/config.json"
TEMP = "/tmp/cap.jpg"

# Robust SocketIO Client
sio = socketio.Client(
    reconnection=True,
    reconnection_attempts=0,      # infinite attempts
    reconnection_delay=2,
    reconnection_delay_max=10
)

# ───────── CAMERA INFO ─────────
def cam_info():
    with open(CONFIG) as f:
        c = json.load(f)
    return c["stream"]["stream_name"], c["auth"]["username"], c["auth"]["password"]

# ───────── GET LOCAL IP ─────────
def local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

# ───────── CAPTURE IMAGE ─────────
def capture(rtsp):
    try:
        result = subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", rtsp, "-frames:v", "1", TEMP],
            timeout=15
        )
        return result.returncode == 0
    except Exception as e:
        print("⚠ ffmpeg error:", e)
        return False

# ───────── CAPTURE JOB ─────────
def job(request_id):
    try:
        cam, user, pwd = cam_info()
        ip = local_ip()

        streams = [
            ("Main", f"rtsp://{user}:{pwd}@{ip}:8554/{cam}/Main"),
            ("Sub",  f"rtsp://{user}:{pwd}@{ip}:8554/{cam}/Sub")
        ]

        for name, url in streams:
            if capture(url):
                try:
                    with open(TEMP, "rb") as f:
                        requests.post(
                            f"{SERVER}/upload-image/{cam}",
                            files={"file": f},
                            data={"request_id": request_id, "stream_used": name},
                            timeout=10
                        )
                    os.remove(TEMP)
                    print("✅ Image uploaded using", name)
                    return
                except Exception as e:
                    print("⚠ Upload failed:", e)

        # If both streams fail
        requests.post(
            f"{SERVER}/capture-failed",
            json={
                "request_id": request_id,
                "camera_id": cam,
                "error": "Camera offline or streams unavailable"
            },
            timeout=5
        )
        print("❌ Capture failed")

    except Exception as e:
        print("⚠ Job error:", e)

# ───────── SOCKET EVENTS ─────────
@sio.event
def connect():
    print("✅ Connected to server")
    try:
        cam, _, _ = cam_info()
        sio.emit("register", {"cam_id": cam})
    except Exception as e:
        print("⚠ Register error:", e)

@sio.event
def disconnect():
    print("❌ Disconnected from server")

@sio.on("capture_now")
def capture_now(data):
    print("📸 Capture requested:", data["request_id"])
    threading.Thread(
        target=job,
        args=(data["request_id"],),
        daemon=True
    ).start()

# ───────── HEARTBEAT ─────────
def heartbeat():
    cam, _, _ = cam_info()
    while True:
        try:
            if sio.connected:
                sio.emit("heartbeat", {"cam_id": cam})
            else:
                print("⚠ Waiting for reconnection...")
        except Exception as e:
            print("⚠ Heartbeat error:", e)
        time.sleep(5)

# ───────── MAIN START ─────────
if __name__ == "__main__":
    while True:
        try:
            print("🔄 Connecting to server...")
            sio.connect(SERVER)
            break
        except Exception:
            print("⚠ Server not available. Retrying in 5 seconds...")
            time.sleep(5)

    threading.Thread(target=heartbeat, daemon=True).start()
    sio.wait()
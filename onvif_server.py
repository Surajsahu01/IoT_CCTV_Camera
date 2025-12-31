# #!/usr/bin/env python3
# from flask import Flask, Response, request
# import socket

# # --------------------------
# # Helper to get Pi IP
# # --------------------------
# def get_pi_ip():
#     s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
#     try:
#         s.connect(("8.8.8.8", 80))
#         ip = s.getsockname()[0]
#     finally:
#         s.close()
#     return ip

# PI_IP = get_pi_ip()
# ONVIF_PORT = 8081
# RTSP_PORT = 8554
# USERNAME = "admin"
# PASSWORD = "password"
# STREAM_NAME = "camera1"

# app = Flask(__name__)

# # --------------------------
# # Device Service POST
# # --------------------------
# @app.route("/onvif/device_service", methods=["POST"])
# def device_service_post():
#     return Response(f"""
#     <Envelope xmlns="http://www.w3.org/2003/05/soap-envelope">
#       <Body>
#         <GetDeviceInformationResponse xmlns="http://www.onvif.org/ver10/device/wsdl">
#           <Manufacturer>RaspberryPi</Manufacturer>
#           <Model>ONVIF-CAM</Model>
#           <FirmwareVersion>1.0</FirmwareVersion>
#           <SerialNumber>RPI-001</SerialNumber>
#           <HardwareId>RPI</HardwareId>
#         </GetDeviceInformationResponse>
#       </Body>
#     </Envelope>
#     """, mimetype="application/soap+xml")

# # --------------------------
# # Device Service GET (browser debug)
# # --------------------------
# @app.route("/onvif/device_service", methods=["GET"])
# def device_service_get():
#     return f"""
#     <h2>ONVIF Device Service Running</h2>
#     <p>Use POST with SOAP to query device info.</p>
#     <p>Pi IP: {PI_IP}</p>
#     <p>RTSP Main: rtsp://{USERNAME}:{PASSWORD}@{PI_IP}:{RTSP_PORT}/{STREAM_NAME}/Main</p>
#     <p>RTSP Sub: rtsp://{USERNAME}:{PASSWORD}@{PI_IP}:{RTSP_PORT}/{STREAM_NAME}/Sub</p>
#     """

# # --------------------------
# # Media Service POST
# # --------------------------
# @app.route("/onvif/media_service", methods=["POST"])
# def media_service():
#     data = request.data.decode()
#     profile = "MainProfile" if "MainProfile" in data else "SubProfile"
#     stream_path = "Main" if profile == "MainProfile" else "Sub"
#     rtsp_url = f"rtsp://{USERNAME}:{PASSWORD}@{PI_IP}:{RTSP_PORT}/{STREAM_NAME}/{stream_path}"

#     return Response(f"""
#     <Envelope xmlns="http://www.w3.org/2003/05/soap-envelope">
#       <Body>
#         <GetStreamUriResponse xmlns="http://www.onvif.org/ver10/media/wsdl">
#           <MediaUri>
#             <Uri>{rtsp_url}</Uri>
#           </MediaUri>
#         </GetStreamUriResponse>
#       </Body>
#     </Envelope>
#     """, mimetype="application/soap+xml")

# # --------------------------
# # Info page for browser debug
# # --------------------------
# @app.route("/")
# def home():
#     return f"""
#     <h1>Raspberry Pi ONVIF Server</h1>
#     <p>ONVIF Device Service: <a href="/onvif/device_service">/onvif/device_service</a></p>
#     <p>ONVIF Media Service: <a href="/onvif/media_service">/onvif/media_service</a></p>
#     <p>RTSP Main: rtsp://{USERNAME}:{PASSWORD}@{PI_IP}:{RTSP_PORT}/{STREAM_NAME}/Main</p>
#     <p>RTSP Sub: rtsp://{USERNAME}:{PASSWORD}@{PI_IP}:{RTSP_PORT}/{STREAM_NAME}/Sub</p>
#     """

# # --------------------------
# # Run Flask
# # --------------------------
# if __name__ == "__main__":
#     print(f"ONVIF server running on {PI_IP}:{ONVIF_PORT}")
#     print(f"RTSP Main: rtsp://{USERNAME}:{PASSWORD}@{PI_IP}:{RTSP_PORT}/{STREAM_NAME}/Main")
#     print(f"RTSP Sub: rtsp://{USERNAME}:{PASSWORD}@{PI_IP}:{RTSP_PORT}/{STREAM_NAME}/Sub")
#     app.run(host="0.0.0.0", port=ONVIF_PORT, debug=False)




#!/usr/bin/env python3
"""
Simple ONVIF Device + Media Server
Compatible with Hikvision / Dahua / CP Plus
"""

from flask import Flask, Response, request
import socket
import json
from datetime import datetime

app = Flask(__name__)

# -------------------------------
# Get Raspberry Pi IP
# -------------------------------
def get_pi_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()

# -------------------------------
# Configuration
# -------------------------------
CONFIG = {
    "ip_address": get_pi_ip(),
    "onvif_port": 8081,
    "rtsp_port": 8554,
    "username": "admin",
    "password": "password",
    "stream_name": "camera1",
    "main_stream": {
        "width": 1280,
        "height": 720,
        "fps": 25,
        "bitrate": 3000
    },
    "sub_stream": {
        "width": 640,
        "height": 360,
        "fps": 15,
        "bitrate": 600
    }
}

# -------------------------------
# Device Information
# -------------------------------
def get_device_information():
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
 xmlns:tds="http://www.onvif.org/ver10/device/wsdl">
 <env:Body>
  <tds:GetDeviceInformationResponse>
   <tds:Manufacturer>Raspberry Pi</tds:Manufacturer>
   <tds:Model>Pi Camera</tds:Model>
   <tds:FirmwareVersion>1.0</tds:FirmwareVersion>
   <tds:SerialNumber>RPI-ONVIF-001</tds:SerialNumber>
   <tds:HardwareId>RaspberryPi</tds:HardwareId>
  </tds:GetDeviceInformationResponse>
 </env:Body>
</env:Envelope>"""

# -------------------------------
# Capabilities
# -------------------------------
def get_capabilities():
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
 xmlns:tds="http://www.onvif.org/ver10/device/wsdl">
 <env:Body>
  <tds:GetCapabilitiesResponse>
   <tds:Capabilities>
    <tds:Media>
     <tds:XAddr>http://{CONFIG['ip_address']}:{CONFIG['onvif_port']}/onvif/media_service</tds:XAddr>
    </tds:Media>
   </tds:Capabilities>
  </tds:GetCapabilitiesResponse>
 </env:Body>
</env:Envelope>"""

# -------------------------------
# Media Profiles
# -------------------------------
def get_profiles():
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
 xmlns:trt="http://www.onvif.org/ver10/media/wsdl">
 <env:Body>
  <trt:GetProfilesResponse>
   <trt:Profiles token="MainProfile">
    <trt:Name>MainStream</trt:Name>
   </trt:Profiles>
   <trt:Profiles token="SubProfile">
    <trt:Name>SubStream</trt:Name>
   </trt:Profiles>
  </trt:GetProfilesResponse>
 </env:Body>
</env:Envelope>"""

# -------------------------------
# Stream URI
# -------------------------------
def get_stream_uri(profile):
    stream = "Main" if profile == "MainProfile" else "Sub"
    uri = f"rtsp://{CONFIG['username']}:{CONFIG['password']}@" \
          f"{CONFIG['ip_address']}:{CONFIG['rtsp_port']}/" \
          f"{CONFIG['stream_name']}/{stream}"

    return f"""<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
 xmlns:trt="http://www.onvif.org/ver10/media/wsdl">
 <env:Body>
  <trt:GetStreamUriResponse>
   <trt:MediaUri>
    <trt:Uri>{uri}</trt:Uri>
   </trt:MediaUri>
  </trt:GetStreamUriResponse>
 </env:Body>
</env:Envelope>"""

# -------------------------------
# ONVIF Endpoints
# -------------------------------
@app.route("/onvif/device_service", methods=["GET", "POST"])
def device_service():
    data = request.data.decode(errors="ignore")
    if "GetCapabilities" in data:
        return Response(get_capabilities(), mimetype="application/soap+xml")
    return Response(get_device_information(), mimetype="application/soap+xml")

@app.route("/onvif/media_service", methods=["POST"])
def media_service():
    data = request.data.decode(errors="ignore")
    if "GetProfiles" in data:
        return Response(get_profiles(), mimetype="application/soap+xml")
    if "GetStreamUri" in data:
        profile = "MainProfile" if "MainProfile" in data else "SubProfile"
        return Response(get_stream_uri(profile), mimetype="application/soap+xml")
    return Response(get_profiles(), mimetype="application/soap+xml")

@app.route("/info")
def info():
    return f"""
    <h1>ONVIF Server Running</h1>
    <pre>{json.dumps(CONFIG, indent=2)}</pre>
    <p>{datetime.now()}</p>
    """

# -------------------------------
# Start Server
# -------------------------------
if __name__ == "__main__":
    print(f"ONVIF Server started on {CONFIG['ip_address']}:{CONFIG['onvif_port']}")
    app.run(host="0.0.0.0", port=CONFIG["onvif_port"], debug=False)

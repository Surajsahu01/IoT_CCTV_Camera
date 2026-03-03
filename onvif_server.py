# #!/usr/bin/env python3
# """
# Simple ONVIF Device + Media Server
# Compatible with Hikvision / Dahua / CP Plus
# """

# from flask import Flask, Response, request
# import socket
# import json
# from datetime import datetime

# app = Flask(__name__)

# # -------------------------------
# # Get Raspberry Pi IP
# # -------------------------------
# def get_pi_ip():
#     s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
#     try:
#         s.connect(("8.8.8.8", 80))
#         return s.getsockname()[0]
#     finally:
#         s.close()

# # -------------------------------
# # Configuration
# # -------------------------------
# CONFIG = {
#     "ip_address": get_pi_ip(),
#     "onvif_port": 8081,
#     "rtsp_port": 8554,
#     "username": "admin",
#     "password": "password",
#     "stream_name": "camera1",
#     "main_stream": {
#         "width": 1280,
#         "height": 720,
#         "fps": 25,
#         "bitrate": 3000
#     },
#     "sub_stream": {
#         "width": 640,
#         "height": 360,
#         "fps": 15,
#         "bitrate": 600
#     }
# }

# # -------------------------------
# # Device Information
# # -------------------------------
# def get_device_information():
#     return f"""<?xml version="1.0" encoding="UTF-8"?>
# <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
#  xmlns:tds="http://www.onvif.org/ver10/device/wsdl">
#  <env:Body>
#   <tds:GetDeviceInformationResponse>
#    <tds:Manufacturer>Raspberry Pi</tds:Manufacturer>
#    <tds:Model>Pi Camera</tds:Model>
#    <tds:FirmwareVersion>1.0</tds:FirmwareVersion>
#    <tds:SerialNumber>RPI-ONVIF-001</tds:SerialNumber>
#    <tds:HardwareId>RaspberryPi</tds:HardwareId>
#   </tds:GetDeviceInformationResponse>
#  </env:Body>
# </env:Envelope>"""

# # -------------------------------
# # Capabilities
# # -------------------------------
# def get_capabilities():
#     return f"""<?xml version="1.0" encoding="UTF-8"?>
# <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
#  xmlns:tds="http://www.onvif.org/ver10/device/wsdl">
#  <env:Body>
#   <tds:GetCapabilitiesResponse>
#    <tds:Capabilities>
#     <tds:Media>
#      <tds:XAddr>http://{CONFIG['ip_address']}:{CONFIG['onvif_port']}/onvif/media_service</tds:XAddr>
#     </tds:Media>
#    </tds:Capabilities>
#   </tds:GetCapabilitiesResponse>
#  </env:Body>
# </env:Envelope>"""

# # -------------------------------
# # Media Profiles
# # -------------------------------
# def get_profiles():
#     return f"""<?xml version="1.0" encoding="UTF-8"?>
# <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
#  xmlns:trt="http://www.onvif.org/ver10/media/wsdl">
#  <env:Body>
#   <trt:GetProfilesResponse>
#    <trt:Profiles token="MainProfile">
#     <trt:Name>MainStream</trt:Name>
#    </trt:Profiles>
#    <trt:Profiles token="SubProfile">
#     <trt:Name>SubStream</trt:Name>
#    </trt:Profiles>
#   </trt:GetProfilesResponse>
#  </env:Body>
# </env:Envelope>"""

# # -------------------------------
# # Stream URI
# # -------------------------------
# def get_stream_uri(profile):
#     stream = "Main" if profile == "MainProfile" else "Sub"
#     uri = f"rtsp://{CONFIG['username']}:{CONFIG['password']}@" \
#           f"{CONFIG['ip_address']}:{CONFIG['rtsp_port']}/" \
#           f"{CONFIG['stream_name']}/{stream}"

#     return f"""<?xml version="1.0" encoding="UTF-8"?>
# <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
#  xmlns:trt="http://www.onvif.org/ver10/media/wsdl">
#  <env:Body>
#   <trt:GetStreamUriResponse>
#    <trt:MediaUri>
#     <trt:Uri>{uri}</trt:Uri>
#    </trt:MediaUri>
#   </trt:GetStreamUriResponse>
#  </env:Body>
# </env:Envelope>"""

# # -------------------------------
# # ONVIF Endpoints
# # -------------------------------
# @app.route("/onvif/device_service", methods=["GET", "POST"])
# def device_service():
#     data = request.data.decode(errors="ignore")
#     if "GetCapabilities" in data:
#         return Response(get_capabilities(), mimetype="application/soap+xml")
#     return Response(get_device_information(), mimetype="application/soap+xml")

# @app.route("/onvif/media_service", methods=["POST"])
# def media_service():
#     data = request.data.decode(errors="ignore")
#     if "GetProfiles" in data:
#         return Response(get_profiles(), mimetype="application/soap+xml")
#     if "GetStreamUri" in data:
#         profile = "MainProfile" if "MainProfile" in data else "SubProfile"
#         return Response(get_stream_uri(profile), mimetype="application/soap+xml")
#     return Response(get_profiles(), mimetype="application/soap+xml")

# @app.route("/info")
# def info():
#     return f"""
#     <h1>ONVIF Server Running</h1>
#     <pre>{json.dumps(CONFIG, indent=2)}</pre>
#     <p>{datetime.now()}</p>
#     """

# # -------------------------------
# # Start Server
# # -------------------------------
# if __name__ == "__main__":
#     print(f"ONVIF Server started on {CONFIG['ip_address']}:{CONFIG['onvif_port']}")
#     app.run(host="0.0.0.0", port=CONFIG["onvif_port"], debug=False)


#!/usr/bin/env python3
"""
Simple ONVIF Device + Media Server
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
CONFIG_PATH = "/home/pi/ipcam/backend/config.json"


def load_config():
    with open(CONFIG_PATH, "r") as f:
        cfg = json.load(f)

    return {
        "ip_address": get_pi_ip(),
        "onvif_port": 8081,
        "rtsp_port": cfg["stream"]["rtsp_port"],

        "USERNAME": cfg["auth"]["username"],
        "PASSWORD": cfg["auth"]["password"],

        "stream_name": cfg["stream"]["stream_name"],

        "main_stream": {
            "width": cfg["camera"]["width"],
            "height": cfg["camera"]["height"],
            "fps": cfg["camera"]["fps"],
            "bitrate": cfg["stream"]["bitrate"]
        },

        # Substream uses SAME resolution & fps as requested
        "sub_stream": {
            "width": cfg["substream"]["width"],
            "height": cfg["substream"]["height"],
            "fps": cfg["substream"]["fps"],
            "bitrate": cfg["substream"]["bitrate"]
        }
    }

CONFIG = load_config()
# -------------------------------
# HOME PAGE (FIXES 404)
# -------------------------------
@app.route("/")
def home():
    return f"""
    <html>
    <head>
        <title>Raspberry Pi ONVIF Camera</title>
    </head>
    <body>
        <h1>📷 Raspberry Pi ONVIF Camera</h1>
        <p>Status: <b>Running</b></p>
        <ul>
            <li><a href="/info">Device Info</a></li>
            <li>ONVIF Device Service: <code>/onvif/device_service</code></li>
            <li>ONVIF Media Service: <code>/onvif/media_service</code></li>
        </ul>
        <hr>
        <small>{datetime.now()}</small>
    </body>
    </html>
    """

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
    uri = (
        f"rtsp://{CONFIG['USERNAME']}:{CONFIG['PASSWORD']}@"
        f"{CONFIG['ip_address']}:{CONFIG['rtsp_port']}/"
        f"{CONFIG['stream_name']}/{stream}"
    )

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

# -------------------------------
# Info Page
# -------------------------------
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

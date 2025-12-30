# from flask import Flask, Response
# import socket, os, uuid

# app = Flask(__name__)
# DEVICE_UUID = str(uuid.uuid4())

# def get_local_ip():
#     s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
#     try:
#         s.connect(("8.8.8.8", 80))
#         ip = s.getsockname()[0]
#     finally:
#         s.close()
#     return ip

# def build_rtsp_url(path):
#     user = os.getenv("RTSP_USER")
#     pwd  = os.getenv("RTSP_PASS")
#     port = os.getenv("ONVIF_RTSP_PORT", "8554")

#     auth = f"{user}:{pwd}@" if user and pwd else ""
#     return f"rtsp://{auth}{get_local_ip()}:{port}/{path}"

# @app.route("/onvif/device_service", methods=["POST"])
# def device_service():
#     return Response(f"""<?xml version="1.0"?>
# <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
#  <soap:Body>
#   <GetDeviceInformationResponse xmlns="http://www.onvif.org/ver10/device/wsdl">
#    <Manufacturer>RaspberryPi</Manufacturer>
#    <Model>Pi Camera</Model>
#    <FirmwareVersion>1.0</FirmwareVersion>
#    <SerialNumber>{DEVICE_UUID}</SerialNumber>
#    <HardwareId>RPI</HardwareId>
#   </GetDeviceInformationResponse>
#  </soap:Body>
# </soap:Envelope>""",
#     mimetype="application/soap+xml")

# @app.route("/onvif/media_service", methods=["POST"])
# def media_service():
#     main_path = os.getenv("ONVIF_RTSP_MAIN_PATH")

#     return Response(f"""<?xml version="1.0"?>
# <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
#  <soap:Body>
#   <GetStreamUriResponse xmlns="http://www.onvif.org/ver10/media/wsdl">
#    <MediaUri>
#     <Uri>{build_rtsp_url(main_path)}</Uri>
#     <InvalidAfterConnect>false</InvalidAfterConnect>
#     <InvalidAfterReboot>false</InvalidAfterReboot>
#     <Timeout>PT60S</Timeout>
#    </MediaUri>
#   </GetStreamUriResponse>
#  </soap:Body>
# </soap:Envelope>""",
#     mimetype="application/soap+xml")

# app.run(host="0.0.0.0", port=8000)



#!/usr/bin/env python3
from flask import Flask, Response
import socket, os, uuid

app = Flask(__name__)
DEVICE_UUID = str(uuid.uuid4())

# -----------------------------
# Helper: Detect local IP
# -----------------------------
def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip

# -----------------------------
# Build RTSP URL dynamically
# -----------------------------
def build_rtsp_url(path):
    user = os.getenv("ONVIF_RTSP_USER")
    pwd  = os.getenv("ONVIF_RTSP_PASS")
    port = os.getenv("ONVIF_RTSP_PORT", "8554")
    auth = f"{user}:{pwd}@" if user and pwd else ""
    return f"rtsp://{auth}{get_local_ip()}:{port}/{path}"

# -----------------------------
# Device service endpoint
# -----------------------------
@app.route("/onvif/device_service", methods=["POST"])
def device_service():
    xml = f"""<?xml version="1.0"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
 <soap:Body>
  <GetDeviceInformationResponse xmlns="http://www.onvif.org/ver10/device/wsdl">
   <Manufacturer>RaspberryPi</Manufacturer>
   <Model>Pi Camera</Model>
   <FirmwareVersion>1.0</FirmwareVersion>
   <SerialNumber>{DEVICE_UUID}</SerialNumber>
   <HardwareId>RPI</HardwareId>
  </GetDeviceInformationResponse>
 </soap:Body>
</soap:Envelope>"""
    return Response(xml, status=200, content_type="application/soap+xml; charset=utf-8")

# -----------------------------
# Media service endpoint
# -----------------------------
@app.route("/onvif/media_service", methods=["POST"])
def media_service():
    main_path = os.getenv("ONVIF_RTSP_MAIN_PATH", "camera/Main")
    sub_path  = os.getenv("ONVIF_RTSP_SUB_PATH", "camera/Sub")
    xml = f"""<?xml version="1.0"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
 <soap:Body>
  <GetStreamUriResponse xmlns="http://www.onvif.org/ver10/media/wsdl">
   <MediaUri>
    <Uri>{build_rtsp_url(main_path)}</Uri>
    <InvalidAfterConnect>false</InvalidAfterConnect>
    <InvalidAfterReboot>false</InvalidAfterReboot>
    <Timeout>PT60S</Timeout>
   </MediaUri>
  </GetStreamUriResponse>
 </soap:Body>
</soap:Envelope>"""
    return Response(xml, status=200, content_type="application/soap+xml; charset=utf-8")

# -----------------------------
# Run Flask app
# -----------------------------
if __name__ == "__main__":
    print(f"ONVIF Server running on {get_local_ip()}:8001")
    app.run(host="0.0.0.0", port=8001)

#!/usr/bin/env python3
"""
Simple ONVIF Server for Raspberry Pi Camera
Makes RTSP streams discoverable by NVRs
"""

from flask import Flask, Response, request
import socket
import json
from datetime import datetime

app = Flask(__name__)

# Configuration - EDIT THESE
CONFIG = {
    "ip_address": socket.gethostbyname(socket.gethostname()),
    # "ip_address": "192.168.1.50",
    "onvif_port": 8080,
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

def get_device_service_response():
    """ONVIF Device Service Response"""
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:tds="http://www.onvif.org/ver10/device/wsdl">
    <env:Header/>
    <env:Body>
        <tds:GetDeviceInformationResponse>
            <tds:Manufacturer>Raspberry Pi</tds:Manufacturer>
            <tds:Model>Pi Camera</tds:Model>
            <tds:FirmwareVersion>1.0</tds:FirmwareVersion>
            <tds:SerialNumber>RPI-CAM-001</tds:SerialNumber>
            <tds:HardwareId>RaspberryPi</tds:HardwareId>
        </tds:GetDeviceInformationResponse>
    </env:Body>
</env:Envelope>'''

def get_profiles_response():
    """ONVIF Media Profiles Response"""
    rtsp_main = f"rtsp://{CONFIG['ip_address']}:{CONFIG['rtsp_port']}/{CONFIG['stream_name']}/Main"
    rtsp_sub = f"rtsp://{CONFIG['ip_address']}:{CONFIG['rtsp_port']}/{CONFIG['stream_name']}/Sub"
    
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:trt="http://www.onvif.org/ver10/media/wsdl">
    <env:Header/>
    <env:Body>
        <trt:GetProfilesResponse>
            <trt:Profiles token="MainProfile">
                <trt:Name>Main Stream</trt:Name>
                <trt:VideoEncoderConfiguration>
                    <trt:Resolution>
                        <trt:Width>{CONFIG['main_stream']['width']}</trt:Width>
                        <trt:Height>{CONFIG['main_stream']['height']}</trt:Height>
                    </trt:Resolution>
                    <trt:RateControl>
                        <trt:FrameRateLimit>{CONFIG['main_stream']['fps']}</trt:FrameRateLimit>
                        <trt:BitrateLimit>{CONFIG['main_stream']['bitrate']}</trt:BitrateLimit>
                    </trt:RateControl>
                </trt:VideoEncoderConfiguration>
            </trt:Profiles>
            <trt:Profiles token="SubProfile">
                <trt:Name>Sub Stream</trt:Name>
                <trt:VideoEncoderConfiguration>
                    <trt:Resolution>
                        <trt:Width>{CONFIG['sub_stream']['width']}</trt:Width>
                        <trt:Height>{CONFIG['sub_stream']['height']}</trt:Height>
                    </trt:Resolution>
                    <trt:RateControl>
                        <trt:FrameRateLimit>{CONFIG['sub_stream']['fps']}</trt:FrameRateLimit>
                        <trt:BitrateLimit>{CONFIG['sub_stream']['bitrate']}</trt:BitrateLimit>
                    </trt:RateControl>
                </trt:VideoEncoderConfiguration>
            </trt:Profiles>
        </trt:GetProfilesResponse>
    </env:Body>
</env:Envelope>'''

def get_stream_uri_response(profile):
    """ONVIF Stream URI Response"""
    stream_path = "Main" if profile == "MainProfile" else "Sub"
    rtsp_url = f"rtsp://{CONFIG['username']}:{CONFIG['password']}@{CONFIG['ip_address']}:{CONFIG['rtsp_port']}/{CONFIG['stream_name']}/{stream_path}"
    
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:trt="http://www.onvif.org/ver10/media/wsdl">
    <env:Header/>
    <env:Body>
        <trt:GetStreamUriResponse>
            <trt:MediaUri>
                <trt:Uri>{rtsp_url}</trt:Uri>
            </trt:MediaUri>
        </trt:GetStreamUriResponse>
    </env:Body>
</env:Envelope>'''

@app.route('/onvif/device_service', methods=['GET', 'POST'])
def device_service():
    """ONVIF Device Service Endpoint"""
    if request.method == 'POST':
        soap_action = request.headers.get('SOAPAction', '')
        
        if 'GetDeviceInformation' in soap_action or 'GetDeviceInformation' in request.data.decode():
            return Response(get_device_service_response(), mimetype='application/soap+xml')
        elif 'GetCapabilities' in soap_action or 'GetCapabilities' in request.data.decode():
            return Response(get_capabilities_response(), mimetype='application/soap+xml')
    
    return Response(get_device_service_response(), mimetype='application/soap+xml')

@app.route('/onvif/media_service', methods=['POST'])
def media_service():
    """ONVIF Media Service Endpoint"""
    soap_action = request.headers.get('SOAPAction', '')
    data = request.data.decode()
    
    if 'GetProfiles' in soap_action or 'GetProfiles' in data:
        return Response(get_profiles_response(), mimetype='application/soap+xml')
    elif 'GetStreamUri' in soap_action or 'GetStreamUri' in data:
        profile = "MainProfile" if "MainProfile" in data else "SubProfile"
        return Response(get_stream_uri_response(profile), mimetype='application/soap+xml')
    
    return Response(get_profiles_response(), mimetype='application/soap+xml')

def get_capabilities_response():
    """ONVIF Capabilities Response"""
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
              xmlns:tds="http://www.onvif.org/ver10/device/wsdl">
    <env:Header/>
    <env:Body>
        <tds:GetCapabilitiesResponse>
            <tds:Capabilities>
                <tds:Media>
                    <tds:XAddr>http://{CONFIG['ip_address']}:{CONFIG['onvif_port']}/onvif/media_service</tds:XAddr>
                </tds:Media>
            </tds:Capabilities>
        </tds:GetCapabilitiesResponse>
    </env:Body>
</env:Envelope>'''

@app.route('/info')
def info():
    """Info page for testing"""
    return f'''
    <h1>Raspberry Pi ONVIF Server</h1>
    <h2>Configuration</h2>
    <pre>{json.dumps(CONFIG, indent=2)}</pre>
    <h2>RTSP URLs</h2>
    <ul>
        <li><strong>Main Stream:</strong> rtsp://{CONFIG['username']}:{CONFIG['password']}@{CONFIG['ip_address']}:{CONFIG['rtsp_port']}/{CONFIG['stream_name']}/Main</li>
        <li><strong>Sub Stream:</strong> rtsp://{CONFIG['username']}:{CONFIG['password']}@{CONFIG['ip_address']}:{CONFIG['rtsp_port']}/{CONFIG['stream_name']}/Sub</li>
    </ul>
    <h2>ONVIF Endpoint</h2>
    <p>http://{CONFIG['ip_address']}:{CONFIG['onvif_port']}/onvif/device_service</p>
    <p><em>Status: Running at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</em></p>
    '''

if __name__ == '__main__':
    print(f"Starting ONVIF Server on {CONFIG['ip_address']}:{CONFIG['onvif_port']}")
    print(f"RTSP Main: rtsp://{CONFIG['ip_address']}:{CONFIG['rtsp_port']}/{CONFIG['stream_name']}/Main")
    print(f"RTSP Sub: rtsp://{CONFIG['ip_address']}:{CONFIG['rtsp_port']}/{CONFIG['stream_name']}/Sub")
    app.run(host='0.0.0.0', port=CONFIG['onvif_port'], debug=False)
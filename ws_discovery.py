# import socket, os

# MCAST_GRP = "239.255.255.250"
# PORT = 3702

# def get_ip():
#     s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
#     s.connect(("8.8.8.8", 80))
#     ip = s.getsockname()[0]
#     s.close()
#     return ip

# sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
# sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
# sock.bind(("", PORT))

# while True:
#     data, addr = sock.recvfrom(4096)
#     if b"Probe" in data:
#         response = f"""<?xml version="1.0"?>
# <ProbeMatches xmlns="http://schemas.xmlsoap.org/ws/2005/04/discovery">
#  <ProbeMatch>
#   <EndpointReference>
#    <Address>urn:uuid:raspberrypi-onvif</Address>
#   </EndpointReference>
#   <Types>dn:NetworkVideoTransmitter</Types>
#   <XAddrs>http://{get_ip()}:8000/onvif/device_service</XAddrs>
#  </ProbeMatch>
# </ProbeMatches>"""
#         sock.sendto(response.encode(), addr)



#!/usr/bin/env python3
import socket

MCAST_GRP = "239.255.255.250"
PORT = 3702

# -----------------------------
# Get local Pi IP
# -----------------------------
def get_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("8.8.8.8", 80))
    ip = s.getsockname()[0]
    s.close()
    return ip

# -----------------------------
# Setup UDP multicast socket
# -----------------------------
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(("", PORT))

print(f"WS-Discovery listening on UDP {PORT}")

# -----------------------------
# Listen for Probe and respond
# -----------------------------
while True:
    data, addr = sock.recvfrom(4096)

    if b"Probe" in data:
        response = f"""<?xml version="1.0" encoding="UTF-8"?>
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
 xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing"
 xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery">
 <e:Body>
  <d:ProbeMatches>
   <d:ProbeMatch>
    <w:EndpointReference>
     <w:Address>urn:uuid:raspberrypi-onvif</w:Address>
    </w:EndpointReference>
    <d:Types>dn:NetworkVideoTransmitter</d:Types>
    <d:XAddrs>http://{get_ip()}:8001/onvif/device_service</d:XAddrs>
    <d:MetadataVersion>1</d:MetadataVersion>
   </d:ProbeMatch>
  </d:ProbeMatches>
 </e:Body>
</e:Envelope>"""
        sock.sendto(response.encode(), addr)

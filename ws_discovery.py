#!/usr/bin/env python3
import socket
import uuid

def get_pi_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()

PI_IP = get_pi_ip()
PORT = 3702
MULTICAST_IP = "239.255.255.250"
DEVICE_UUID = f"urn:uuid:{uuid.uuid4()}"

def build_response(relates_to):
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"
 xmlns:a="http://schemas.xmlsoap.org/ws/2004/08/addressing"
 xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"
 xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
 <s:Header>
  <a:MessageID>uuid:{uuid.uuid4()}</a:MessageID>
  <a:RelatesTo>{relates_to}</a:RelatesTo>
  <a:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</a:To>
  <a:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/ProbeMatches</a:Action>
 </s:Header>
 <s:Body>
  <d:ProbeMatches>
   <d:ProbeMatch>
    <a:EndpointReference>
     <a:Address>{DEVICE_UUID}</a:Address>
    </a:EndpointReference>
    <d:Types>dn:NetworkVideoTransmitter</d:Types>
    <d:Scopes>
      onvif://www.onvif.org/ProfileS
      onvif://www.onvif.org/type/video_encoder
    </d:Scopes>
    <d:XAddrs>http://{PI_IP}:8081/onvif/device_service</d:XAddrs>
    <d:MetadataVersion>1</d:MetadataVersion>
   </d:ProbeMatch>
  </d:ProbeMatches>
 </s:Body>
</s:Envelope>
""".encode()

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(("", PORT))

mreq = socket.inet_aton(MULTICAST_IP) + socket.inet_aton("0.0.0.0")
sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)

print(f"ONVIF WS-Discovery running on {PI_IP}:3702")

while True:
    data, addr = sock.recvfrom(8192)

    if b"Probe" not in data:
        continue

    try:
        relates_to = data.decode(errors="ignore").split("<a:MessageID>")[1].split("</a:MessageID>")[0]
    except:
        relates_to = "uuid:probe"

    response = build_response(relates_to)
    sock.sendto(response, addr)
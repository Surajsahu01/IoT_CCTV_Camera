import subprocess
import re
import os
import ipaddress
import time
import json

class Network:
    def __init__(self):
        self.dhcpcd_conf = '/etc/dhcpcd.conf'
        self.wpa_conf = '/etc/wpa_supplicant/wpa_supplicant.conf'
        self.config_path = "/home/pi/ipcam/backend/config.json"


    def load_config(self):
        with open(self.config_path, "r") as f:
            return json.load(f)

    def save_config(self, cfg):
        with open(self.config_path, "w") as f:
            json.dump(cfg, f, indent=2)



    def apply_from_config(self):
        cfg = self.load_config()
        cur = cfg["network"]["current"]

        if cur["mode"] == "dhcp":
            return self.set_dhcp()
        else:
            return self.set_static(
                cur["ip_address"],
                cur["gateway"],
                cur.get("dns", "8.8.8.8")
            )

    

    def reset_to_default(self):
        cfg = self.load_config()
        cfg["network"]["current"] = cfg["network"]["default"].copy()
        self.save_config(cfg)
        return self.apply_from_config()


    # ---------------- STATIC IP ----------------

    def set_static(self, ip, gateway, dns):
        try:
            ipaddress.ip_address(ip)
            ipaddress.ip_address(gateway)

            static_block = f"""
# ===== FIRMWARE STATIC IP =====
interface eth0
static ip_address={ip}/24
static routers={gateway}
static domain_name_servers={dns}

interface wlan0
static ip_address={ip}/24
static routers={gateway}
static domain_name_servers={dns}
"""

            with open(self.dhcpcd_conf, "r") as f:
                content = f.read()

            # Remove old firmware block
            content = re.sub(
                r"# ===== FIRMWARE STATIC IP =====[\\s\\S]*?$",
                "",
                content,
                flags=re.MULTILINE
            )

            content = content.rstrip() + "\n" + static_block

            with open("/tmp/dhcpcd.conf", "w") as f:
                f.write(content)

            subprocess.run(["sudo", "mv", "/tmp/dhcpcd.conf", self.dhcpcd_conf], check=True)
            subprocess.run(["sudo", "systemctl", "restart", "dhcpcd"], check=True)

            return {
                "success": True,
                "message": f"Static IP set to {ip}. Reopen firmware using new IP.",
                "ip": ip
            }

        except Exception as e:
            return {"success": False, "message": str(e)}

    # ---------------- DHCP ----------------

    def set_dhcp(self):
        try:
            with open(self.dhcpcd_conf, "r") as f:
                content = f.read()

            content = re.sub(
                r"# ===== FIRMWARE STATIC IP =====[\\s\\S]*?$",
                "",
                content,
                flags=re.MULTILINE
            )

            with open("/tmp/dhcpcd.conf", "w") as f:
                f.write(content.rstrip() + "\n")

            subprocess.run(["sudo", "mv", "/tmp/dhcpcd.conf", self.dhcpcd_conf], check=True)
            subprocess.run(["sudo", "systemctl", "restart", "dhcpcd"], check=True)

            return {
                "success": True,
                "message": "Switched to DHCP successfully"
            }

        except Exception as e:
            return {"success": False, "message": str(e)}




    def _get_ip(self, iface):
        try:
            out = subprocess.check_output(
                ["ip", "-4", "addr", "show", iface],
                stderr=subprocess.DEVNULL
            ).decode()
            m = re.search(r"inet (\d+\.\d+\.\d+\.\d+)", out)
            return m.group(1) if m else None
        except:
            return None

    def _get_gateway(self):
        try:
            out = subprocess.check_output(
                ["ip", "route", "show", "default"]
            ).decode()
            m = re.search(r"default via (\d+\.\d+\.\d+\.\d+)", out)
            return m.group(1) if m else None
        except:
            return None

    def _get_mac(self, iface):
        try:
            return open(f"/sys/class/net/{iface}/address").read().strip()
        except:
            return None

    def _get_eth_speed(self):
        try:
            out = subprocess.check_output(
                ["ethtool", "eth0"],
                stderr=subprocess.DEVNULL
            ).decode()
            m = re.search(r"Speed:\s*(\S+)", out)
            return m.group(1) if m else None
        except:
            return None

    def _get_wifi_info(self):
        try:
            out = subprocess.check_output(
                ["iw", "dev", "wlan0", "link"],
                stderr=subprocess.DEVNULL
            ).decode()
            if "Connected" not in out:
                return None, None
            ssid = re.search(r"SSID: (.+)", out).group(1)
            signal = re.search(r"signal: (-?\d+)", out).group(1)
            return ssid, f"{signal} dBm"
        except:
            return None, None

    def get_status(self):
        eth_ip = self._get_ip("eth0")
        wifi_ip = self._get_ip("wlan0")

        if eth_ip:
            active = "eth0"
            ctype = "ethernet"
        elif wifi_ip:
            active = "wlan0"
            ctype = "wifi"
        else:
            active = None
            ctype = "disconnected"

        ssid, signal = self._get_wifi_info()

        return {
            "active_interface": active,
            "connection_type": ctype,
            "ip_address": eth_ip or wifi_ip,
            "gateway": self._get_gateway(),

            "ethernet": {
                "interface": "eth0",
                "connected": bool(eth_ip),
                "ip_address": eth_ip,
                "mac": self._get_mac("eth0"),
                "speed": self._get_eth_speed()
            },

            "wifi": {
                "interface": "wlan0",
                "connected": bool(wifi_ip),
                "ssid": ssid,
                "signal": signal,
                "ip_address": wifi_ip,
                "mac": self._get_mac("wlan0")
            }
        }


    # ---------------- WIFI ----------------

#     def configure_wifi(self, ssid, password):
#         try:
#             wpa = f"""country=IN
# ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
# update_config=1

# network={{
#     ssid="{ssid}"
#     psk="{password}"
# }}
# """
#             with open("/tmp/wpa_supplicant.conf", "w") as f:
#                 f.write(wpa)

#             subprocess.run(["sudo", "mv", "/tmp/wpa_supplicant.conf", self.wpa_conf], check=True)
#             subprocess.run(["sudo", "chmod", "600", self.wpa_conf], check=True)
#             subprocess.run(["sudo", "wpa_cli", "-i", "wlan0", "reconfigure"], check=True)

#             return {"success": True, "message": "WiFi credentials saved"}

#         except Exception as e:
#             return {"success": False, "message": str(e)}


    def configure_wifi(self, data):
        try:
            ssid = data.get("ssid")
            password = data.get("password", "")

            if not ssid:
                return {
                    "success": False,
                    "message": "SSID is required"
                }

            wpa = (
                "country=IN\n"
                "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\n"
                "update_config=1\n\n"
                "network={\n"
                f'    ssid="{ssid}"\n'
            )

            if password:
                wpa += f'    psk="{password}"\n'
            else:
                wpa += "    key_mgmt=NONE\n"

            wpa += "}\n"

            with open("/tmp/wpa_supplicant.conf", "w") as f:
                f.write(wpa)

            subprocess.run(
                ["sudo", "mv", "/tmp/wpa_supplicant.conf", self.wpa_conf],
                check=True
            )
            subprocess.run(
                ["sudo", "chmod", "600", self.wpa_conf],
                check=True
            )
            subprocess.run(
                ["sudo", "wpa_cli", "-i", "wlan0", "reconfigure"],
                check=True
            )

            return {
                "success": True,
                "message": f"Connecting to WiFi: {ssid}"
            }

        except Exception as e:
            return {
                "success": False,
                "message": f"WiFi error: {str(e)}"
            }


    def get_network_info(self):
        """Get detailed network information"""
        try:
            info = {}
            
            # Get current IP
            ip_result = subprocess.run(['hostname', '-I'], 
                                      capture_output=True, text=True)
            info['ip'] = ip_result.stdout.strip().split()[0] if ip_result.stdout else "N/A"
            
            # Get gateway
            route_result = subprocess.run(['ip', 'route', 'show', 'default'],
                                        capture_output=True, text=True)
            if route_result.stdout:
                gateway_match = re.search(r'default via ([\d.]+)', route_result.stdout)
                info['gateway'] = gateway_match.group(1) if gateway_match else "N/A"
            else:
                info['gateway'] = "N/A"
            
            # Get DNS
            try:
                dns_result = subprocess.run(['cat', '/etc/resolv.conf'],
                                           capture_output=True, text=True)
                dns_servers = []
                for line in dns_result.stdout.splitlines():
                    if line.strip().startswith('nameserver'):
                        dns_servers.append(line.split()[1])
                info['dns'] = ', '.join(dns_servers) if dns_servers else "N/A"
            except:
                info['dns'] = "N/A"
            
            # Check if static or DHCP by reading dhcpcd.conf
            with open(self.dhcpcd_conf, 'r') as f:
                content = f.read()
                info['is_static'] = 'interface wlan0' in content and 'static ip_address' in content
            
            return {
                "success": True,
                "info": info
            }
        except Exception as e:
            return {"success": False, "message": str(e)}


    def _signal_to_int(self, signal_str):
        try:
            # if not signal_str:
            #     return -100
            return int(float(str(signal_str).split()[0]))
        except:
            return -100

    def scan_wifi(self):
        """Scan for available WiFi networks using iw"""
        try:
            # Ensure wlan0 is up
            subprocess.run(['sudo', 'ip', 'link', 'set', 'wlan0', 'up'], 
                        check=False, timeout=5, 
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            time.sleep(1)
            
            # Scan networks
            scan = subprocess.run(
                ['sudo', 'iw', 'dev', 'wlan0', 'scan'],
                capture_output=True,
                text=True,
                timeout=15
            )

            if scan.returncode != 0:
                return {
                    "success": False,
                    "message": "Scan failed. Make sure WiFi is enabled.",
                    "networks": []
                }

            networks = {}
            current_network = {}

            for line in scan.stdout.splitlines():
                line = line.strip()


                if line.startswith("BSS"):
                    if current_network.get("ssid"):
                        ssid = current_network["ssid"]

                        if (
                            ssid not in networks or
                            self._signal_to_int(current_network.get("signal")) >
                            self._signal_to_int(networks[ssid].get("signal"))
                        ):
                            networks[ssid] = current_network

                    current_network = {}


                # SSID name
                elif line.startswith("SSID:"):
                    ssid = line.replace("SSID:", "").strip()
                    if ssid:  # Skip hidden/empty SSIDs
                        current_network["ssid"] = ssid

                # Signal strength
                elif "signal:" in line.lower():
                    try:
                        signal_match = re.search(r'(-?\d+\.\d+)', line)
                        if signal_match:
                            signal = signal_match.group(1)
                            current_network["signal"] = f"{signal} dBm"
                    except:
                        pass

                # Security detection
                elif "RSN:" in line:
                    current_network["security"] = "WPA2"
                elif "WPA:" in line and current_network.get("security") != "WPA2":
                    current_network["security"] = "WPA"
                elif "Privacy" in line and "capability" in line.lower():
                    if "security" not in current_network:
                        current_network["security"] = "WEP"

            

            # Add the last network
            if current_network.get("ssid"):
                ssid = current_network["ssid"]

                if (
                    ssid not in networks or
                    self._signal_to_int(current_network.get("signal")) >
                    self._signal_to_int(networks[ssid].get("signal"))
                ):
                    networks[ssid] = current_network



            # Convert to list and add defaults
            result = []
            for network in networks.values():
                if "security" not in network:
                    network["security"] = "Open"
                if "signal" not in network:
                    network["signal"] = "N/A"
                result.append(network)


            result.sort(
                key=lambda x: self._signal_to_int(x.get("signal")),
                reverse=True
            )


            return {
                "success": True,
                "networks": result
            }

        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "message": "Scan timeout - WiFi might be busy",
                "networks": []
            }
        except Exception as e:
            return {
                "success": False,
                "message": f"Scan error: {str(e)}",
                "networks": []
            }
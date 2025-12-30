import subprocess
import os
import psutil
from datetime import datetime

class System:
    def __init__(self):
        self.log_dir = '/home/pi/ipcam/logs'
    
    def get_info(self):
        """Get system information"""
        try:
            # CPU usage
            cpu_percent = psutil.cpu_percent(interval=1)
            
            # Memory info
            memory = psutil.virtual_memory()
            memory_percent = memory.percent
            memory_used = round(memory.used / (1024**3), 2)
            memory_total = round(memory.total / (1024**3), 2)
            
            # Disk info
            disk = psutil.disk_usage('/')
            disk_percent = disk.percent
            disk_used = round(disk.used / (1024**3), 2)
            disk_total = round(disk.total / (1024**3), 2)
            
            # CPU temperature
            try:
                temp_result = subprocess.run(
                    ['vcgencmd', 'measure_temp'],
                    capture_output=True, text=True
                )
                temp = temp_result.stdout.strip().replace("temp=", "").replace("'C", "")
                cpu_temp = float(temp)
            except:
                cpu_temp = 0
            
            # Uptime
            boot_time = datetime.fromtimestamp(psutil.boot_time())
            uptime = str(datetime.now() - boot_time).split('.')[0]
            
            # Hostname
            hostname = subprocess.run(['hostname'], 
                                     capture_output=True, text=True).stdout.strip()
            
            # OS version
            try:
                with open('/etc/os-release', 'r') as f:
                    os_info = {}
                    for line in f:
                        if '=' in line:
                            key, val = line.strip().split('=', 1)
                            os_info[key] = val.strip('"')
                os_version = os_info.get('PRETTY_NAME', 'Unknown')
            except:
                os_version = 'Unknown'
            
            return {
                "success": True,
                "hostname": hostname,
                "os_version": os_version,
                "uptime": uptime,
                "cpu_usage": cpu_percent,
                "cpu_temp": cpu_temp,
                "memory": {
                    "used": memory_used,
                    "total": memory_total,
                    "percent": memory_percent
                },
                "disk": {
                    "used": disk_used,
                    "total": disk_total,
                    "percent": disk_percent
                }
            }
        except Exception as e:
            return {"success": False, "message": str(e)}
    
    def get_logs(self, log_type='stream'):
        """Get system logs"""
        try:
            if log_type == 'stream':
                log_file = '/home/pi/ipcam/stream/logs/stream.log'
            elif log_type == 'backend':
                log_file = '/home/pi/ipcam/logs/backend.log'
            else:
                log_file = '/home/pi/ipcam/logs/system.log'
            
            if not os.path.exists(log_file):
                return {
                    "success": True,
                    "logs": "No logs available"
                }
            
            # Get last 100 lines
            with open(log_file, 'r') as f:
                lines = f.readlines()
                last_lines = lines[-100:] if len(lines) > 100 else lines
                logs = ''.join(last_lines)
            
            return {
                "success": True,
                "logs": logs
            }
        except Exception as e:
            return {"success": False, "message": str(e)}
    
    def reboot(self):
        """Reboot system"""
        try:
            subprocess.Popen(['sudo', 'reboot'])
            return {
                "success": True,
                "message": "System is rebooting..."
            }
        except Exception as e:
            return {"success": False, "message": str(e)}
    
    def shutdown(self):
        """Shutdown system"""
        try:
            subprocess.Popen(['sudo', 'shutdown', '-h', 'now'])
            return {
                "success": True,
                "message": "System is shutting down..."
            }
        except Exception as e:
            return {"success": False, "message": str(e)}

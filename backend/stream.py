# import json
# import subprocess
# import os
# import signal

# class Stream:
#     def __init__(self, config_path):
#         self.config_path = config_path
#         self.stream_script = '/home/pi/ipcam/stream/start_stream.sh'
#         self.pid_file = '/tmp/ipcam_stream.pid'
    
#     def load_config(self):
#         try:
#             with open(self.config_path, 'r') as f:
#                 return json.load(f)
#         except:
#             return self.get_default_config()
    
#     def get_default_config(self):
#         return {
#             "stream": {
#                 "server_ip": "10.251.246.200",
#                 "rtsp_port": 8554,
#                 "stream_name": "camera",
#                 "width": 1920,
#                 "height": 1080,
#                 "fps": 30,
#                 "bitrate": 4000000,
#                 "lens_position": 0.0
#             }
#         }
    
#     def save_config(self, config):
#         try:
#             with open(self.config_path, 'w') as f:
#                 json.dump(config, f, indent=2)
#             return True
#         except Exception as e:
#             print(f"Error saving config: {e}")
#             return False
    
#     def get_settings(self):
#         config = self.load_config()
#         return {
#             "success": True,
#             "settings": config.get("stream", {})
#         }
    
#     def update_settings(self, new_settings):
#         try:
#             config = self.load_config()
#             if "stream" not in config:
#                 config["stream"] = {}
            
#             config["stream"].update(new_settings)
            
#             if self.save_config(config):
#                 # Update stream config for script
#                 stream_config = {
#                     "server_ip": config["stream"].get("server_ip"),
#                     "rtsp_port": config["stream"].get("rtsp_port"),
#                     "stream_name": config["stream"].get("stream_name"),
#                     "width": config["stream"].get("width"),
#                     "height": config["stream"].get("height"),
#                     "fps": config["stream"].get("fps"),
#                     "lens_position": config["stream"].get("lens_position", 0.0)
#                 }
                
#                 with open('/home/pi/ipcam/stream/config.json', 'w') as f:
#                     json.dump(stream_config, f, indent=2)
                
#                 return {"success": True, "message": "Stream settings updated"}
#             else:
#                 return {"success": False, "message": "Failed to save settings"}
#         except Exception as e:
#             return {"success": False, "message": str(e)}
    
#     def is_running(self):
#         """Check if stream is running"""
#         if os.path.exists(self.pid_file):
#             try:
#                 with open(self.pid_file, 'r') as f:
#                     pid = int(f.read().strip())
                
#                 # Check if process exists
#                 os.kill(pid, 0)
#                 return True
#             except (OSError, ValueError):
#                 # Process doesn't exist, clean up pid file
#                 try:
#                     os.remove(self.pid_file)
#                 except:
#                     pass
#                 return False
#         return False
    
#     def get_status(self):
#         """Get stream status"""
#         running = self.is_running()
#         config = self.load_config()
#         stream_config = config.get("stream", {})
        
#         rtsp_url = f"rtsp://{stream_config.get('server_ip')}:{stream_config.get('rtsp_port')}/{stream_config.get('stream_name')}"
        
#         return {
#             "success": True,
#             "running": running,
#             "rtsp_url": rtsp_url,
#             "status": "Streaming" if running else "Stopped"
#         }
    
#     def start(self):
#         """Start RTSP stream"""
#         try:
#             if self.is_running():
#                 return {
#                     "success": False, 
#                     "message": "Stream is already running"
#                 }
            
#             # Start stream script in background
#             process = subprocess.Popen(
#                 ['bash', self.stream_script],
#                 stdout=subprocess.DEVNULL,
#                 stderr=subprocess.DEVNULL,
#                 start_new_session=True
#             )
            
#             # Save PID
#             with open(self.pid_file, 'w') as f:
#                 f.write(str(process.pid))
            
#             return {
#                 "success": True,
#                 "message": "Stream started successfully"
#             }
#         except Exception as e:
#             return {"success": False, "message": str(e)}
    
#     def stop(self):
#         """Stop RTSP stream"""
#         try:
#             if not self.is_running():
#                 return {
#                     "success": False,
#                     "message": "Stream is not running"
#                 }
            
#             with open(self.pid_file, 'r') as f:
#                 pid = int(f.read().strip())
            
#             # Kill process group
#             try:
#                 os.killpg(os.getpgid(pid), signal.SIGTERM)
#             except ProcessLookupError:
#                 pass
            
#             # Clean up PID file
#             try:
#                 os.remove(self.pid_file)
#             except:
#                 pass
            
#             return {
#                 "success": True,
#                 "message": "Stream stopped successfully"
#             }
#         except Exception as e:
#             return {"success": False, "message": str(e)}
    
#     def restart(self):
#         """Restart RTSP stream"""
#         stop_result = self.stop()
#         if not stop_result["success"] and "not running" not in stop_result["message"]:
#             return stop_result
        
#         import time
#         time.sleep(2)
        
#         return self.start()



import json
import subprocess
import os
import time

class Stream:
    def __init__(self, config_path):
        self.config_path = config_path
        self.stream_script = '/home/pi/ipcam/stream/start_stream.sh'
        self.service_name = 'ipcam-stream.service'
        self.log_file = '/home/pi/ipcam/stream/logs/stream.log'
    
    def load_config(self):
        try:
            with open(self.config_path, 'r') as f:
                return json.load(f)
        except:
            return self.get_default_config()
    
    def get_default_config(self):
        return {
            "stream": {
                "server_ip": "10.251.246.200",
                "rtsp_port": 8554,
                "stream_name": "camera",
                "width": 1080,
                "height": 720,
                "fps": 25,
                "bitrate": 2000000,
                "lens_position": 0.0
            }
        }
    
    def save_config(self, config):
        try:
            with open(self.config_path, 'w') as f:
                json.dump(config, f, indent=2)
            return True
        except Exception as e:
            print(f"Error saving config: {e}")
            return False
    
    def get_settings(self):
        config = self.load_config()
        return {
            "success": True,
            "settings": config.get("stream", {})
        }
    
    def update_settings(self, new_settings):
        try:
            config = self.load_config()
            if "stream" not in config:
                config["stream"] = {}
            
            config["stream"].update(new_settings)
            
            if self.save_config(config):
                # Update stream config for script
                stream_config = {
                    "server_ip": config["stream"].get("server_ip"),
                    "rtsp_port": config["stream"].get("rtsp_port"),
                    "stream_name": config["stream"].get("stream_name"),
                    "width": config["stream"].get("width"),
                    "height": config["stream"].get("height"),
                    "fps": config["stream"].get("fps"),
                    "lens_position": config["stream"].get("lens_position", 0.0),
                    "bitrate": config["stream"].get("bitrate", 4000000)
                }
                
                # Ensure directory exists
                os.makedirs('/home/pi/ipcam/stream', exist_ok=True)
                
                with open('/home/pi/ipcam/stream/config.json', 'w') as f:
                    json.dump(stream_config, f, indent=2)
                
                # Restart service if it's running to apply new settings
                if self.is_running():
                    self.restart()
                
                return {"success": True, "message": "Stream settings updated"}
            else:
                return {"success": False, "message": "Failed to save settings"}
        except Exception as e:
            return {"success": False, "message": str(e)}
    
    def is_running(self):
        """Check if stream service is running"""
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', self.service_name],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.stdout.strip() == 'active'
        except:
            # Fallback: check if process is running
            try:
                result = subprocess.run(
                    ['pgrep', '-f', 'start_stream.sh'],
                    capture_output=True,
                    text=True
                )
                return result.returncode == 0 and result.stdout.strip() != ''
            except:
                return False
    
    # def get_status(self):
    #     """Get stream status"""
    #     running = self.is_running()
    #     config = self.load_config()
    #     stream_config = config.get("stream", {})
        
    #     rtsp_url = f"rtsp://{stream_config.get('server_ip')}:{stream_config.get('rtsp_port')}/{stream_config.get('stream_name')}"
        
    #     # Check if service exists
    #     try:
    #         result = subprocess.run(
    #             ['systemctl', 'list-unit-files', self.service_name],
    #             capture_output=True,
    #             text=True,
    #             timeout=5
    #         )
    #         service_exists = self.service_name in result.stdout
    #     except:
    #         service_exists = False
        
    #     return {
    #         "success": True,
    #         "running": running,
    #         "rtsp_url": rtsp_url,
    #         "status": "Streaming" if running else "Stopped",
    #         "auto_start": service_exists
    #     }

    def get_status(self):
        """Get stream status"""
        running = self.is_running()
        config = self.load_config()
        stream_config = config.get("stream", {})

        server_ip = stream_config.get("server_ip")
        stream_name = stream_config.get("stream_name")
        rtsp_port = stream_config.get("rtsp_port")

        rtsp_url = f"rtsp://{server_ip}:{rtsp_port}/{stream_name}"
        mjpeg_url = f"http://{server_ip}:8888/{stream_name}"

        # Check if service exists
        try:
            result = subprocess.run(
                ['systemctl', 'list-unit-files', self.service_name],
                capture_output=True,
                text=True,
                timeout=5
            )
            service_exists = self.service_name in result.stdout
        except Exception:
            service_exists = False

        return {
            "success": True,
            "running": running,
            "status": "Streaming" if running else "Stopped",
            "auto_start": service_exists,

            # RTSP (existing)
            "rtsp_url": rtsp_url,

            # MJPEG preview (NEW)
            "server_ip": server_ip,
            "stream_name": stream_name,
            "mjpeg_url": mjpeg_url
        }

    
    def start(self):
        """Start RTSP stream via systemd service"""
        try:
            if self.is_running():
                return {
                    "success": False, 
                    "message": "Stream is already running"
                }
            
            # Try to start via systemd service first
            try:
                result = subprocess.run(
                    ['sudo', 'systemctl', 'start', self.service_name],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                # Wait and check if it started
                time.sleep(2)
                
                if self.is_running():
                    return {
                        "success": True,
                        "message": "Stream started successfully"
                    }
                else:
                    raise Exception("Service started but not running")
            
            except Exception as e:
                # Fallback to manual start
                print(f"Systemd start failed: {e}, trying manual start")
                
                # Make sure script is executable
                os.chmod(self.stream_script, 0o755)
                
                # Create log directory
                os.makedirs(os.path.dirname(self.log_file), exist_ok=True)
                
                # Start stream script in background
                process = subprocess.Popen(
                    ['nohup', 'bash', self.stream_script],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                    cwd='/home/pi/ipcam/stream',
                    preexec_fn=os.setpgrp
                )
                
                time.sleep(2)
                
                if self.is_running():
                    return {
                        "success": True,
                        "message": "Stream started successfully (manual mode)"
                    }
                else:
                    return {
                        "success": False,
                        "message": "Stream failed to start. Check logs."
                    }
        
        except Exception as e:
            return {"success": False, "message": f"Failed to start stream: {str(e)}"}
    
    def stop(self):
        """Stop RTSP stream"""
        try:
            if not self.is_running():
                return {
                    "success": False,
                    "message": "Stream is not running"
                }
            
            # Try to stop via systemd first
            try:
                subprocess.run(
                    ['sudo', 'systemctl', 'stop', self.service_name],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
            except:
                pass
            
            # Also kill processes manually to be sure
            subprocess.run(['pkill', '-f', 'start_stream.sh'], check=False)
            subprocess.run(['pkill', '-f', 'rpicam-vid'], check=False)
            subprocess.run(['pkill', '-f', 'ffmpeg.*rtsp'], check=False)
            
            # Give processes time to terminate
            time.sleep(2)
            
            return {
                "success": True,
                "message": "Stream stopped successfully"
            }
        except Exception as e:
            return {"success": False, "message": str(e)}
    
    def restart(self):
        """Restart RTSP stream"""
        # Stop first
        self.stop()
        
        # Wait a bit
        time.sleep(3)
        
        # Start again
        return self.start()
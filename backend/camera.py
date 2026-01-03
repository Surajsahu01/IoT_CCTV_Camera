import json
import subprocess
import io
from flask import Response
from picamera2 import Picamera2
from picamera2.encoders import JpegEncoder
from picamera2.outputs import FileOutput
import threading
import time
import cv2
import os

class Camera:
    def __init__(self, config_path):
        self.config_path = config_path
        self.picam2 = None
        self.streaming = False
        self.output = None

    def mjpeg_stream(self):
        while True:
            frame = self.get_frame()   # numpy frame
            ret, jpeg = cv2.imencode('.jpg', frame)
            yield (b'--frame\r\n'
                b'Content-Type: image/jpeg\r\n\r\n' +
                jpeg.tobytes() + b'\r\n')
    
        
    def load_config(self):
        try:
            with open(self.config_path, 'r') as f:
                return json.load(f)
        except:
            return self.get_default_config()
    
    def get_default_config(self):
        return {
            "camera": {
                "width": 1280,
                "height": 720,
                "fps": 25,
                "brightness": 0,
                "contrast": 1,
                "saturation": 1,
                "sharpness": 1,
                "lens_position": 0,
                "autofocus_mode": "continuous",
                "exposure_mode": "auto",
                "awb_mode": "auto",
                "gop": 50,
                "profile": "main",
                "rc_mode": "vbr",
                "hdr": false
            },
            "stream": {
                "server_ip": "10.49.37.200",
                "rtsp_port": 554,
                "stream_name": "camera1",
                "bitrate": 2500000
            },
            "substream": {
                "width": 640,
                "height": 360,
                "fps": 15,
                "bitrate": 600000
            },
            "auth": {
                "username": "admin",
                "password": "password"
            },
            "night": {
                "enabled": true,
                "threshold": 0.18,
                "hysteresis": 0.05
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
    
    # def get_settings(self):
    #     config = self.load_config()
    #     return {
    #         "success": True,
    #         "settings": config.get("camera", {})
    #     }


    def get_settings(self):
        config = self.load_config()

        camera_settings = config.get("camera", {})
        night_enabled = config.get("night", {}).get("enabled", False)

        return {
            "success": True,
            "settings": {
                **camera_settings,
                "night_enabled": night_enabled
            }
        }

    
    # def update_settings(self, new_settings):
    #     try:
    #         config = self.load_config()
    #         if "camera" not in config:
    #             config["camera"] = {}
            
    #         config["camera"].update(new_settings)
            
    #         if self.save_config(config):
    #             return {"success": True, "message": "Camera settings updated"}
    #         else:
    #             return {"success": False, "message": "Failed to save settings"}
    #     except Exception as e:
    #         return {"success": False, "message": str(e)}


    def update_settings(self, new_settings):
        try:
            config = self.load_config()

            # Ensure sections exist
            config.setdefault("camera", {})
            config.setdefault("night", {})

            # Handle night mode separately
            if "night_enabled" in new_settings:
                config["night"]["enabled"] = bool(new_settings.pop("night_enabled"))

            # Update camera settings only
            config["camera"].update(new_settings)

            if self.save_config(config):
                return {
                    "success": True,
                    "message": "Camera settings updated"
                }

            return {
                "success": False,
                "message": "Failed to save settings"
            }

        except Exception as e:
            return {
                "success": False,
                "message": str(e)
            }

    
    def get_preview(self):
        """Generate JPEG preview from camera"""
        try:
            if not self.picam2:
                self.picam2 = Picamera2()
                config = self.picam2.create_preview_configuration(
                    main={"size": (640, 480)}
                )
                self.picam2.configure(config)
                self.picam2.start()
                time.sleep(2)
            
            # Capture frame
            frame = self.picam2.capture_array()
            
            # Convert to JPEG
            import cv2
            _, buffer = cv2.imencode('.jpg', frame)
            
            return Response(buffer.tobytes(),
                          mimetype='image/jpeg',
                          headers={'Cache-Control': 'no-cache'})
        except Exception as e:
            print(f"Preview error: {e}")
            return Response(status=500)


    

    def reset_to_default(self):
        try:
            default_config = self.get_default_config()
            if self.save_config(default_config):
                return {
                    "success": True,
                    "message": "Camera settings reset to default"
                }
            return {
                "success": False,
                "message": "Failed to reset camera settings"
            }
        except Exception as e:
            return {
                "success": False,
                "message": str(e)
            }


    
    def cleanup(self):
        if self.picam2:
            try:
                self.picam2.stop()
                self.picam2.close()
            except:
                pass
            self.picam2 = None


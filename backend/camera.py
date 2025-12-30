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
                "contrast": 1.0,
                "saturation": 1.0,
                "sharpness": 1.0,
                "lens_position": 0.0,
                "autofocus_mode": "auto",
                "exposure_mode": "auto",
                "awb_mode": "auto"
            },
            "stream": {
                "server_ip": "10.251.246.200",
                "rtsp_port": 8554,
                "stream_name": "camera",
                "width": 1280,
                "height": 720,
                "fps": 25,
                "bitrate": 3000000,
                "lens_position": 0
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
            "settings": config.get("camera", {})
        }
    
    def update_settings(self, new_settings):
        try:
            config = self.load_config()
            if "camera" not in config:
                config["camera"] = {}
            
            config["camera"].update(new_settings)
            
            if self.save_config(config):
                return {"success": True, "message": "Camera settings updated"}
            else:
                return {"success": False, "message": "Failed to save settings"}
        except Exception as e:
            return {"success": False, "message": str(e)}
    
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




# import json
# import subprocess
# import io
# from flask import Response
# from picamera2 import Picamera2
# from picamera2.encoders import JpegEncoder
# from picamera2.outputs import FileOutput
# import threading
# import time
# import cv2
# import os
# import numpy as np

# class Camera:
#     def __init__(self, config_path):
#         self.config_path = config_path
#         self.picam2 = None
#         self.streaming = False
#         self.output = None
#         self.current_frame = None
#         self.frame_lock = threading.Lock()
#         self.capture_thread = None
#         self.capture_active = False

#     def start_capture(self):
#         """Start continuous frame capture in background thread"""
#         if self.capture_active:
#             return
        
#         self.capture_active = True
#         self.capture_thread = threading.Thread(target=self._capture_loop, daemon=True)
#         self.capture_thread.start()

#     def _capture_loop(self):
#         """Background thread to continuously capture frames"""
#         try:
#             if not self.picam2:
#                 self.picam2 = Picamera2()
#                 config = self.load_config()
#                 cam_config = config.get("camera", {})
                
#                 # Use preview settings for lower resource usage
#                 preview_config = self.picam2.create_preview_configuration(
#                     main={"size": (640, 480), "format": "RGB888"}
#                 )
#                 self.picam2.configure(preview_config)
#                 self.picam2.start()
#                 time.sleep(1)  # Camera warmup
            
#             while self.capture_active:
#                 try:
#                     frame = self.picam2.capture_array()
#                     with self.frame_lock:
#                         self.current_frame = frame.copy()
#                     time.sleep(0.033)  # ~30fps
#                 except Exception as e:
#                     print(f"Frame capture error: {e}")
#                     time.sleep(0.1)
                    
#         except Exception as e:
#             print(f"Capture loop error: {e}")
#         finally:
#             self.cleanup()

#     def stop_capture(self):
#         """Stop the capture thread"""
#         self.capture_active = False
#         if self.capture_thread:
#             self.capture_thread.join(timeout=2)

#     def get_frame(self):
#         """Get the current frame (numpy array)"""
#         # Start capture if not already running
#         if not self.capture_active:
#             self.start_capture()
#             time.sleep(0.5)  # Wait for first frame
        
#         with self.frame_lock:
#             if self.current_frame is not None:
#                 return self.current_frame.copy()
#             else:
#                 # Return black frame if no frame available
#                 return np.zeros((480, 640, 3), dtype=np.uint8)

#     def mjpeg_stream(self):
#         """Generate MJPEG stream from camera frames"""
#         while True:
#             try:
#                 frame = self.get_frame()
                
#                 # Encode as JPEG with quality 85
#                 ret, jpeg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
                
#                 if not ret:
#                     time.sleep(0.1)
#                     continue
                
#                 yield (b'--frame\r\n'
#                        b'Content-Type: image/jpeg\r\n\r\n' +
#                        jpeg.tobytes() + b'\r\n')
                
#                 time.sleep(0.033)  # ~30fps
                
#             except Exception as e:
#                 print(f"MJPEG stream error: {e}")
#                 time.sleep(0.1)

#     def get_rtsp_stream(self):
#         """Generate MJPEG stream from local RTSP preview (if available)"""
#         rtsp_url = "rtsp://127.0.0.1:8555/preview"
#         cap = None
        
#         try:
#             cap = cv2.VideoCapture(rtsp_url)
#             cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # Minimize buffering
            
#             # Wait for connection
#             retry_count = 0
#             while retry_count < 5:
#                 if cap.isOpened():
#                     break
#                 time.sleep(0.5)
#                 retry_count += 1
            
#             if not cap.isOpened():
#                 raise Exception("Failed to connect to RTSP stream")
            
#             while True:
#                 ret, frame = cap.read()
                
#                 if not ret:
#                     print("RTSP stream ended or error")
#                     break
                
#                 # Encode as JPEG
#                 ret, jpeg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
                
#                 if not ret:
#                     continue
                
#                 yield (b'--frame\r\n'
#                        b'Content-Type: image/jpeg\r\n\r\n' +
#                        jpeg.tobytes() + b'\r\n')
                
#         except Exception as e:
#             print(f"RTSP stream error: {e}")
#             # Fall back to direct camera stream
#             for frame_data in self.mjpeg_stream():
#                 yield frame_data
#         finally:
#             if cap:
#                 cap.release()

#     def load_config(self):
#         try:
#             with open(self.config_path, 'r') as f:
#                 return json.load(f)
#         except:
#             return self.get_default_config()
    
#     def get_default_config(self):
#         return {
#             "camera": {
#                 "width": 1280,
#                 "height": 720,
#                 "fps": 25,
#                 "brightness": 0,
#                 "contrast": 1.0,
#                 "saturation": 1.0,
#                 "sharpness": 1.0,
#                 "lens_position": 0.0,
#                 "autofocus_mode": "auto",
#                 "exposure_mode": "auto",
#                 "awb_mode": "auto"
#             },
#             "stream": {
#                 "server_ip": "10.251.246.200",
#                 "rtsp_port": 8554,
#                 "stream_name": "camera",
#                 "width": 1280,
#                 "height": 720,
#                 "fps": 25,
#                 "bitrate": 3000000,
#                 "lens_position": 0
#             },
#             "preview": {
#                 "width": 640,
#                 "height": 360,
#                 "fps": 15,
#                 "bitrate": 500000
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
#             "settings": config.get("camera", {})
#         }
    
#     def update_settings(self, new_settings):
#         try:
#             config = self.load_config()
#             if "camera" not in config:
#                 config["camera"] = {}
            
#             config["camera"].update(new_settings)
            
#             if self.save_config(config):
#                 return {"success": True, "message": "Camera settings updated"}
#             else:
#                 return {"success": False, "message": "Failed to save settings"}
#         except Exception as e:
#             return {"success": False, "message": str(e)}
    
#     def get_preview(self):
#         """Generate single JPEG preview from camera"""
#         try:
#             frame = self.get_frame()
            
#             # Convert to JPEG
#             _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 90])
            
#             return Response(buffer.tobytes(),
#                           mimetype='image/jpeg',
#                           headers={'Cache-Control': 'no-cache'})
#         except Exception as e:
#             print(f"Preview error: {e}")
#             return Response(status=500)

#     def check_rtsp_available(self):
#         """Check if local RTSP preview stream is available"""
#         import socket
#         try:
#             sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
#             sock.settimeout(1)
#             result = sock.connect_ex(('127.0.0.1', 8555))
#             sock.close()
#             return result == 0
#         except:
#             return False

#     def get_snapshot(self):
#         """Capture a single high-quality snapshot"""
#         try:
#             # Use temporary camera instance for snapshot
#             temp_cam = Picamera2()
#             config = self.load_config()
#             cam_config = config.get("camera", {})
            
#             width = cam_config.get("width", 1280)
#             height = cam_config.get("height", 720)
            
#             # High quality snapshot configuration
#             snapshot_config = temp_cam.create_still_configuration(
#                 main={"size": (width, height)}
#             )
#             temp_cam.configure(snapshot_config)
#             temp_cam.start()
#             time.sleep(2)  # Camera warmup
            
#             # Capture
#             frame = temp_cam.capture_array()
            
#             # Cleanup
#             temp_cam.stop()
#             temp_cam.close()
            
#             # Convert to JPEG
#             _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 95])
            
#             return buffer.tobytes()
            
#         except Exception as e:
#             print(f"Snapshot error: {e}")
#             return None

#     def reset_to_default(self):
#         try:
#             default_config = self.get_default_config()
#             if self.save_config(default_config):
#                 return {
#                     "success": True,
#                     "message": "Camera settings reset to default"
#                 }
#             return {
#                 "success": False,
#                 "message": "Failed to reset camera settings"
#             }
#         except Exception as e:
#             return {
#                 "success": False,
#                 "message": str(e)
#             }

#     def cleanup(self):
#         """Cleanup camera resources"""
#         self.stop_capture()
        
#         if self.picam2:
#             try:
#                 self.picam2.stop()
#                 self.picam2.close()
#             except:
#                 pass
#             self.picam2 = None
        
#         self.current_frame = None

#     def __del__(self):
#         """Destructor to ensure cleanup"""
#         self.cleanup()
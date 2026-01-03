# #!/bin/bash

# # Simple stream to server only - NO local preview
# # Use this if you only want to stream to your server

# CONFIG="/home/pi/ipcam/backend/config.json"
# LOG_DIR="/home/pi/ipcam/stream/logs"
# LOG="$LOG_DIR/stream.log"
# CONFIG_CHECKSUM_FILE="/tmp/stream_config_checksum"

# # Log limits
# MAX_LOG_SIZE=$((5 * 1024 * 1024))   # 5 MB
# MAX_LOG_FILES=5 

# mkdir -p "$LOG_DIR"

# # =========================================================
# # Log rotation
# # =========================================================
# rotate_logs() {
#     if [ -f "$LOG" ]; then
#         local size
#         size=$(stat -c%s "$LOG")

#         if [ "$size" -ge "$MAX_LOG_SIZE" ]; then
#             for ((i=MAX_LOG_FILES; i>=1; i--)); do
#                 if [ -f "$LOG.$i" ]; then
#                     if [ "$i" -eq "$MAX_LOG_FILES" ]; then
#                         rm -f "$LOG.$i"
#                     else
#                         mv "$LOG.$i" "$LOG.$((i+1))"
#                     fi
#                 fi
#             done
#             mv "$LOG" "$LOG.1"
#             touch "$LOG"
#         fi
#     fi
# }

# log() {
#     rotate_logs
#     echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$LOG"
# }

# # Function to calculate config checksum
# get_config_checksum() {
#     md5sum "$CONFIG" 2>/dev/null | cut -d' ' -f1
# }

# # Function to check if config has changed
# config_changed() {
#     local current_checksum=$(get_config_checksum)
#     local old_checksum=""
    
#     if [ -f "$CONFIG_CHECKSUM_FILE" ]; then
#         old_checksum=$(cat "$CONFIG_CHECKSUM_FILE")
#     fi
    
#     if [ "$current_checksum" != "$old_checksum" ]; then
#         echo "$current_checksum" > "$CONFIG_CHECKSUM_FILE"
#         return 0
#     fi
#     return 1
# }

# # Function to load config
# load_config() {
#     RTSP_USER=$(jq -r '.auth.username' "$CONFIG")
#     RTSP_PASS=$(jq -r '.auth.password' "$CONFIG")
#     SERVER_IP=$(jq -r '.stream.server_ip' "$CONFIG")
#     RTSP_PORT=$(jq -r '.stream.rtsp_port // 8554' "$CONFIG")
#     STREAM_NAME=$(jq -r '.stream.stream_name // "camera"' "$CONFIG")
#     BITRATE=$(jq -r '.stream.bitrate // 4000000' "$CONFIG")
#     # RTSP_URL="rtsp://${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}"
#     RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}"

#     WIDTH=$(jq -r '.camera.width // 1280' "$CONFIG")
#     HEIGHT=$(jq -r '.camera.height // 720' "$CONFIG")
#     FPS=$(jq -r '.camera.fps // 25' "$CONFIG")
#     BRIGHTNESS=$(jq -r '.camera.brightness // 0' "$CONFIG")
#     CONTRAST=$(jq -r '.camera.contrast // 1.0' "$CONFIG")
#     SATURATION=$(jq -r '.camera.saturation // 1.0' "$CONFIG")
#     SHARPNESS=$(jq -r '.camera.sharpness // 1.0' "$CONFIG")
#     AF_MODE=$(jq -r '.camera.autofocus_mode // "auto"' "$CONFIG")
#     LENS=$(jq -r '.camera.lens_position // 0.0' "$CONFIG")
# }

# # Check config file
# if [ ! -f "$CONFIG" ]; then
#     log "❌ Config file not found: $CONFIG"
#     exit 1
# fi

# load_config
# STREAM_PID=""

# log "================================================"
# log "📡 Simple Server Stream Starting"
# log "RTSP URL: $RTSP_URL"
# log "Resolution: ${WIDTH}x${HEIGHT} @ ${FPS}fps"
# log "Bitrate: $BITRATE"
# log "================================================"

# while true; do
    
#     # Check if config changed
#     if config_changed; then
#         log "🔄 Config changed, reloading..."
#         load_config
        
#         if [ -n "$STREAM_PID" ]; then
#             log "⏹️ Stopping stream (PID: $STREAM_PID)"
#             kill $STREAM_PID 2>/dev/null
#             wait $STREAM_PID 2>/dev/null
#             STREAM_PID=""
#         fi
#     fi

#     # Start stream if not running
#     if [ -z "$STREAM_PID" ] || ! kill -0 $STREAM_PID 2>/dev/null; then
        
#         # Check server
#         if ! nc -z -w3 "$SERVER_IP" "$RTSP_PORT"; then
#             log "⚠️ RTSP server not reachable ($SERVER_IP:$RTSP_PORT)"
#             sleep 5
#             continue
#         fi
        
#         log "✅ Starting stream to server..."

#         # Build camera command
#         CMD=(
#             rpicam-vid
#             --timeout 0
#             --nopreview
#             --inline
#             --codec h264
#             --width "$WIDTH"
#             --height "$HEIGHT"
#             --framerate "$FPS"
#             --bitrate "$BITRATE"
#             --brightness "$BRIGHTNESS"
#             --contrast "$CONTRAST"
#             --saturation "$SATURATION"
#             --sharpness "$SHARPNESS"
#             --autofocus-mode "$AF_MODE"
#             --profile main
#             --level 4.2
#             -o -
#         )

#         if [ "$AF_MODE" = "manual" ]; then
#             CMD+=( --lens-position "$LENS" )
#         fi

#         # Start stream
#         (
#             "${CMD[@]}" 2>>"$LOG" | \
#             ffmpeg \
#                 -use_wallclock_as_timestamps 1 \
#                 -fflags +genpts \
#                 -f h264 \
#                 -i pipe:0 \
#                 -c:v copy \
#                 -bsf:v h264_metadata=aud=insert \
#                 -f rtsp \
#                 -rtsp_transport tcp \
#                 "$RTSP_URL" \
#                 >>"$LOG" 2>&1
#         ) &
        
#         STREAM_PID=$!
#         log "▶️ Stream started (PID: $STREAM_PID)"
#     fi

#     sleep 5
# done




# #!/bin/bash

# # =========================================================
# # Raspberry Pi Camera → Local MediaMTX + Server MediaMTX
# # Auto-restart | Dynamic config | Production Ready
# # =========================================================

# CONFIG="/home/pi/ipcam/backend/config.json"
# LOG_DIR="/home/pi/ipcam/stream/logs"
# LOG="$LOG_DIR/stream.log"
# CONFIG_CHECKSUM_FILE="/tmp/stream_config_checksum"

# MAX_LOG_SIZE=$((5 * 1024 * 1024))
# MAX_LOG_FILES=5

# mkdir -p "$LOG_DIR"

# # =========================================================
# # Logging with rotation
# # =========================================================
# rotate_logs() {
#     [ -f "$LOG" ] || return
#     size=$(stat -c%s "$LOG")
#     if [ "$size" -ge "$MAX_LOG_SIZE" ]; then
#         for ((i=MAX_LOG_FILES; i>=1; i--)); do
#             [ -f "$LOG.$i" ] && mv "$LOG.$i" "$LOG.$((i+1))"
#         done
#         mv "$LOG" "$LOG.1"
#         touch "$LOG"
#     fi
# }

# log() {
#     rotate_logs
#     echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$LOG"
# }

# # =========================================================
# # Config helpers
# # =========================================================
# get_config_checksum() {
#     md5sum "$CONFIG" | cut -d' ' -f1
# }

# config_changed() {
#     current=$(get_config_checksum)
#     old=$(cat "$CONFIG_CHECKSUM_FILE" 2>/dev/null)
#     if [ "$current" != "$old" ]; then
#         echo "$current" > "$CONFIG_CHECKSUM_FILE"
#         return 0
#     fi
#     return 1
# }

# # =========================================================
# # Load config.json
# # =========================================================
# load_config() {

#     # Local IP (dynamic)
#     LOCAL_IP=$(hostname -I | awk '{print $1}')

#     # Auth
#     RTSP_USER=$(jq -r '.auth.username' "$CONFIG")
#     RTSP_PASS=$(jq -r '.auth.password' "$CONFIG")

#     # Stream config
#     SERVER_IP=$(jq -r '.stream.server_ip' "$CONFIG")
#     RTSP_PORT=$(jq -r '.stream.rtsp_port // 8554' "$CONFIG")
#     STREAM_NAME=$(jq -r '.stream.stream_name // "camera"' "$CONFIG")
#     BITRATE=$(jq -r '.stream.bitrate // 3000000' "$CONFIG")
#     FPS=$(jq -r '.stream.fps // 25' "$CONFIG")

#     # Camera config
#     WIDTH=$(jq -r '.camera.width // 1280' "$CONFIG")
#     HEIGHT=$(jq -r '.camera.height // 720' "$CONFIG")
#     BRIGHTNESS=$(jq -r '.camera.brightness // 0' "$CONFIG")
#     CONTRAST=$(jq -r '.camera.contrast // 1.0' "$CONFIG")
#     SATURATION=$(jq -r '.camera.saturation // 1.0' "$CONFIG")
#     SHARPNESS=$(jq -r '.camera.sharpness // 1.0' "$CONFIG")
#     AF_MODE=$(jq -r '.camera.autofocus_mode // "auto"' "$CONFIG")
#     LENS=$(jq -r '.camera.lens_position // 0.0' "$CONFIG")

#     # RTSP URLs
#     LOCAL_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:8554/${STREAM_NAME}"
#     SERVER_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}"
# }

# # =========================================================
# # Startup checks
# # =========================================================
# if [ ! -f "$CONFIG" ]; then
#     echo "Config not found: $CONFIG"
#     exit 1
# fi

# load_config
# STREAM_PID=""

# log "================================================"
# log "🎥 Raspberry Pi Camera Streaming Started"
# log "📡 Local RTSP  : $LOCAL_RTSP_URL"
# log "🌐 Server RTSP : $SERVER_RTSP_URL"
# log "🎞 ${WIDTH}x${HEIGHT} @ ${FPS}fps | ${BITRATE}bps"
# log "================================================"

# # =========================================================
# # Main loop
# # =========================================================
# while true; do

#     if config_changed; then
#         log "🔄 Config changed – restarting stream"
#         [ -n "$STREAM_PID" ] && kill "$STREAM_PID" 2>/dev/null
#         STREAM_PID=""
#         load_config
#     fi

#     if [ -z "$STREAM_PID" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then

#         # Wait for local MediaMTX
#         until nc -z "$LOCAL_IP" "$RTSP_PORT"; do
#             log "⏳ Waiting for local MediaMTX..."
#             sleep 1
#         done

#         # Wait for server MediaMTX
#         until nc -z "$SERVER_IP" "$RTSP_PORT"; do
#             log "⏳ Waiting for server MediaMTX..."
#             sleep 1
#         done

#         log "▶️ Starting camera stream..."

#         CMD=(
#             rpicam-vid
#             --timeout 0
#             --nopreview
#             --inline
#             --codec h264
#             --width "$WIDTH"
#             --height "$HEIGHT"
#             --framerate "$FPS"
#             --bitrate "$BITRATE"
#             --brightness "$BRIGHTNESS"
#             --contrast "$CONTRAST"
#             --saturation "$SATURATION"
#             --sharpness "$SHARPNESS"
#             --autofocus-mode "$AF_MODE"
#             --profile main
#             --level 4.2
#             -o -
#         )

#         [ "$AF_MODE" = "manual" ] && CMD+=(--lens-position "$LENS")

#         (
#             "${CMD[@]}" 2>>"$LOG" | \
#             ffmpeg \
#                 -fflags +genpts \
#                 -use_wallclock_as_timestamps 1 \
#                 -f h264 -i pipe:0 \
#                 -map 0:v:0 \
#                 -c:v copy \
#                 -bsf:v h264_metadata=aud=insert \
#                 -f tee \
#                 "[select=v:f=rtsp:rtsp_transport=tcp]$LOCAL_RTSP_URL|\
# [select=v:f=rtsp:rtsp_transport=tcp]$SERVER_RTSP_URL" \
#                 >>"$LOG" 2>&1
#         ) &

#         STREAM_PID=$!
#         log "✅ Stream running (PID: $STREAM_PID)"
#     fi

#     sleep 5
# done





# #!/bin/bash

# # =========================================================
# # Raspberry Pi Camera → Local + Server MediaMTX
# # Main / Sub RTSP Streaming (PRODUCTION READY)
# # =========================================================

# CONFIG="/home/pi/ipcam/backend/config.json"
# LOG_DIR="/home/pi/ipcam/stream/logs"
# LOG="$LOG_DIR/stream.log"
# CONFIG_CHECKSUM_FILE="/tmp/stream_config_checksum"

# MAX_LOG_SIZE=$((5 * 1024 * 1024))
# MAX_LOG_FILES=5

# mkdir -p "$LOG_DIR"

# # =========================================================
# # Logging with rotation
# # =========================================================
# rotate_logs() {
#     [ -f "$LOG" ] || return
#     size=$(stat -c%s "$LOG")
#     if [ "$size" -ge "$MAX_LOG_SIZE" ]; then
#         for ((i=MAX_LOG_FILES; i>=1; i--)); do
#             [ -f "$LOG.$i" ] && mv "$LOG.$i" "$LOG.$((i+1))"
#         done
#         mv "$LOG" "$LOG.1"
#         touch "$LOG"
#     fi
# }

# log() {
#     rotate_logs
#     echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$LOG"
# }

# # =========================================================
# # Config helpers
# # =========================================================
# get_config_checksum() {
#     md5sum "$CONFIG" | cut -d' ' -f1
# }

# config_changed() {
#     current=$(get_config_checksum)
#     old=$(cat "$CONFIG_CHECKSUM_FILE" 2>/dev/null)
#     if [ "$current" != "$old" ]; then
#         echo "$current" > "$CONFIG_CHECKSUM_FILE"
#         return 0
#     fi
#     return 1
# }

# # =========================================================
# # Load config.json
# # =========================================================
# load_config() {

#     LOCAL_IP=$(hostname -I | awk '{print $1}')

#     RTSP_USER=$(jq -r '.auth.username' "$CONFIG")
#     RTSP_PASS=$(jq -r '.auth.password' "$CONFIG")

#     SERVER_IP=$(jq -r '.stream.server_ip' "$CONFIG")
#     RTSP_PORT=$(jq -r '.stream.rtsp_port // 8554' "$CONFIG")
#     STREAM_NAME=$(jq -r '.stream.stream_name // "camera"' "$CONFIG")

#     # Main stream
#     WIDTH=$(jq -r '.camera.width' "$CONFIG")
#     HEIGHT=$(jq -r '.camera.height' "$CONFIG")
#     FPS=$(jq -r '.camera.fps' "$CONFIG")
#     BITRATE=$(jq -r '.stream.bitrate' "$CONFIG")

#     # Sub stream
#     SUB_WIDTH=$(jq -r '.substream.width' "$CONFIG")
#     SUB_HEIGHT=$(jq -r '.substream.height' "$CONFIG")
#     SUB_FPS=$(jq -r '.substream.fps' "$CONFIG")
#     SUB_BITRATE=$(jq -r '.substream.bitrate' "$CONFIG")

#     BRIGHTNESS=$(jq -r '.camera.brightness' "$CONFIG")
#     CONTRAST=$(jq -r '.camera.contrast' "$CONFIG")
#     SATURATION=$(jq -r '.camera.saturation' "$CONFIG")
#     SHARPNESS=$(jq -r '.camera.sharpness' "$CONFIG")
#     AF_MODE=$(jq -r '.camera.autofocus_mode' "$CONFIG")
#     LENS=$(jq -r '.camera.lens_position' "$CONFIG")

#     # RTSP URLs
#     LOCAL_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:8554/${STREAM_NAME}/Main"
#     LOCAL_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:8554/${STREAM_NAME}/Sub"

#     SERVER_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Main"
#     SERVER_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Sub"
# }

# # =========================================================
# # Startup checks
# # =========================================================
# if [ ! -f "$CONFIG" ]; then
#     echo "Config not found: $CONFIG"
#     exit 1
# fi

# load_config
# STREAM_PID=""

# log "================================================"
# log "🎥 Raspberry Pi Main + Sub Streaming Started"
# log "📡 Local  Main : $LOCAL_MAIN_RTSP_URL"
# log "📡 Local  Sub  : $LOCAL_SUB_RTSP_URL"
# log "🌐 Server Main: $SERVER_MAIN_RTSP_URL"
# log "🌐 Server Sub : $SERVER_SUB_RTSP_URL"
# log "================================================"

# # =========================================================
# # Main loop
# # =========================================================
# while true; do

#     if config_changed; then
#         log "🔄 Config changed – restarting stream"
#         [ -n "$STREAM_PID" ] && kill "$STREAM_PID" 2>/dev/null
#         STREAM_PID=""
#         load_config
#     fi

#     if [ -z "$STREAM_PID" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then

#         until nc -z "$LOCAL_IP" 8554; do
#             log "⏳ Waiting for local MediaMTX..."
#             sleep 1
#         done

#         until nc -z "$SERVER_IP" "$RTSP_PORT"; do
#             log "⏳ Waiting for server MediaMTX..."
#             sleep 1
#         done

#         log "▶️ Starting Main + Sub streams..."

#         CMD=(
#             rpicam-vid
#             --timeout 0
#             --nopreview
#             --inline
#             --codec h264
#             --width "$WIDTH"
#             --height "$HEIGHT"
#             --framerate "$FPS"
#             --bitrate "$BITRATE"
#             --brightness "$BRIGHTNESS"
#             --contrast "$CONTRAST"
#             --saturation "$SATURATION"
#             --sharpness "$SHARPNESS"
#             --autofocus-mode "$AF_MODE"
#             --profile main
#             --level 4.2
#             -o -
#         )

#         [ "$AF_MODE" = "manual" ] && CMD+=(--lens-position "$LENS")

#         (
#         "${CMD[@]}" 2>>"$LOG" | \
#         ffmpeg -fflags +genpts -use_wallclock_as_timestamps 1 \
#             -f h264 -i pipe:0 \
#             -filter_complex \
#             "[0:v]split=2[vmain][vsub]; \
#             [vsub]scale=${SUB_WIDTH}:${SUB_HEIGHT}[vsubout]" \
#             \
#             -map "[vmain]" \
#             -c:v libx264 -preset veryfast -tune zerolatency \
#             -b:v ${BITRATE} -r ${FPS} \
#             -f tee \
#             "[f=rtsp:rtsp_transport=tcp]${LOCAL_MAIN_RTSP_URL}|\
#         [f=rtsp:rtsp_transport=tcp]${SERVER_MAIN_RTSP_URL}" \
#             \
#             -map "[vsubout]" \
#             -c:v libx264 -preset veryfast -tune zerolatency \
#             -b:v ${SUB_BITRATE} -r ${SUB_FPS} \
#             -f tee \
#             "[f=rtsp:rtsp_transport=tcp]${LOCAL_SUB_RTSP_URL}|\
#         [f=rtsp:rtsp_transport=tcp]${SERVER_SUB_RTSP_URL}" \
#             >>"$LOG" 2>&1
#         ) &


#         STREAM_PID=$!
#         log "✅ Streaming running (PID: $STREAM_PID)"
#     fi

#     sleep 5
# done





#!/bin/bash

# =========================================================
# Raspberry Pi Camera → Local + Server MediaMTX
# Main / Sub RTSP Streaming (CPU OPTIMIZED)
# =========================================================

CONFIG="/home/pi/ipcam/backend/config.json"
LOG_DIR="/home/pi/ipcam/stream/logs"
LOG="$LOG_DIR/stream.log"
CONFIG_CHECKSUM_FILE="/tmp/stream_config_checksum"

MAX_LOG_SIZE=$((5 * 1024 * 1024))
MAX_LOG_FILES=5

mkdir -p "$LOG_DIR"

# =========================================================
# Logging with rotation
# =========================================================
rotate_logs() {
    [ -f "$LOG" ] || return
    size=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
    if [ "$size" -ge "$MAX_LOG_SIZE" ]; then
        for ((i=MAX_LOG_FILES; i>=1; i--)); do
            [ -f "$LOG.$i" ] && mv "$LOG.$i" "$LOG.$((i+1))"
        done
        mv "$LOG" "$LOG.1"
        touch "$LOG"
    fi
}

log() {
    rotate_logs
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$LOG"
}

# =========================================================
# Config helpers
# =========================================================
get_config_checksum() {
    md5sum "$CONFIG" | cut -d' ' -f1
}

config_changed() {
    current=$(get_config_checksum)
    old=$(cat "$CONFIG_CHECKSUM_FILE" 2>/dev/null)
    if [ "$current" != "$old" ]; then
        echo "$current" > "$CONFIG_CHECKSUM_FILE"
        return 0
    fi
    return 1
}

# =========================================================
# Load config.json
# =========================================================
load_config() {

    LOCAL_IP=$(hostname -I | awk '{print $1}')

    RTSP_USER=$(jq -r '.auth.username' "$CONFIG")
    RTSP_PASS=$(jq -r '.auth.password' "$CONFIG")

    SERVER_IP=$(jq -r '.stream.server_ip' "$CONFIG")
    RTSP_PORT=$(jq -r '.stream.rtsp_port // 8554' "$CONFIG")
    STREAM_NAME=$(jq -r '.stream.stream_name // "camera"' "$CONFIG")

    # Main stream
    WIDTH=$(jq -r '.camera.width' "$CONFIG")
    HEIGHT=$(jq -r '.camera.height' "$CONFIG")
    FPS=$(jq -r '.camera.fps' "$CONFIG")
    BITRATE=$(jq -r '.stream.bitrate' "$CONFIG")

    # Sub stream
    SUB_WIDTH=$(jq -r '.substream.width' "$CONFIG")
    SUB_HEIGHT=$(jq -r '.substream.height' "$CONFIG")
    SUB_FPS=$(jq -r '.substream.fps' "$CONFIG")
    SUB_BITRATE=$(jq -r '.substream.bitrate' "$CONFIG")

    BRIGHTNESS=$(jq -r '.camera.brightness' "$CONFIG")
    CONTRAST=$(jq -r '.camera.contrast' "$CONFIG")
    SATURATION=$(jq -r '.camera.saturation' "$CONFIG")
    SHARPNESS=$(jq -r '.camera.sharpness' "$CONFIG")
    AF_MODE=$(jq -r '.camera.autofocus_mode' "$CONFIG")
    LENS=$(jq -r '.camera.lens_position' "$CONFIG")

    GOP=$(jq -r '.camera.gop // 50' "$CONFIG")
    PROFILE=$(jq -r '.camera.profile // "main"' "$CONFIG")
    RC_MODE=$(jq -r '.camera.rc_mode // "vbr"' "$CONFIG")
    HDR=$(jq -r '.camera.hdr // false' "$CONFIG")

    # Night mode config
    NIGHT_ENABLED=$(jq -r '.night.enabled // false' "$CONFIG")
    NIGHT_THRESHOLD=$(jq -r '.night.threshold // 0.18' "$CONFIG")
    NIGHT_HYSTERESIS=$(jq -r '.night.hysteresis // 0.05' "$CONFIG")


    # RTSP URLs
    LOCAL_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:8554/${STREAM_NAME}/Main"
    LOCAL_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:8554/${STREAM_NAME}/Sub"

    SERVER_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Main"
    SERVER_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Sub"

    # Export RTSP info for ONVIF
    export ONVIF_RTSP_PORT="8554"
    export ONVIF_STREAM_NAME="${STREAM_NAME}"
    export ONVIF_RTSP_MAIN_PATH="${STREAM_NAME}/Main"
    export ONVIF_RTSP_SUB_PATH="${STREAM_NAME}/Sub"
    export ONVIF_RTSP_USER="${RTSP_USER}"
    export ONVIF_RTSP_PASS="${RTSP_PASS}"
}

# =========================================================
# Check if server is reachable (with timeout)
# =========================================================
server_available() {
    timeout 2 nc -z "$SERVER_IP" "$RTSP_PORT" 2>/dev/null
    return $?
}



# =========================================================
# Night detection helpers
# =========================================================
NIGHT_MODE=false

get_luma() {
    # Capture 1 frame, calculate average brightness (0–1)
    rpicam-still -n -t 50 --width 320 --height 240 -o - 2>/dev/null | \
    ffmpeg -hide_banner -loglevel fatal -i pipe:0 \
        -vf "signalstats" -frames:v 1 -f null - 2>&1 | \
    awk -F'YAVG:' '{print $2}' | awk '{print $1/255}'
}

# apply_day_settings() {
#     log "☀️ Switching to DAY exposure"
#     rpicam-ctl set exposure auto
#     rpicam-ctl set analoggain 1
#     rpicam-ctl set shutter 0
# }

# apply_night_settings() {
#     log "🌙 Switching to NIGHT exposure"
#     rpicam-ctl set exposure long
#     rpicam-ctl set analoggain 8
#     rpicam-ctl set shutter 100000
# }


# =========================================================
# Camera tuning (NoIR Wide)
# =========================================================
apply_day_settings() {
    log "☀️ DAY MODE (forced)"
    rpicam-ctl set exposure normal
    rpicam-ctl set analoggain 1
    rpicam-ctl set shutter 0
    rpicam-ctl set awb auto
}

apply_night_settings() {
    log "🌙 NIGHT MODE (auto)"
    rpicam-ctl set exposure long
    rpicam-ctl set analoggain 6
    rpicam-ctl set shutter 100000
    rpicam-ctl set awb greyworld
}


# =========================================================
# Cleanup function
# =========================================================
cleanup_streams() {
    if [ -n "$STREAM_PID" ]; then
        log "🛑 Stopping stream processes (PID: $STREAM_PID)"
        # Kill entire process group
        kill -TERM -$STREAM_PID 2>/dev/null || kill -TERM $STREAM_PID 2>/dev/null
        sleep 1
        # Force kill if still running
        kill -9 -$STREAM_PID 2>/dev/null || kill -9 $STREAM_PID 2>/dev/null
        wait $STREAM_PID 2>/dev/null
    fi
    # Kill any orphaned ffmpeg/rpicam-vid processes
    pkill -f "ffmpeg.*${STREAM_NAME}" 2>/dev/null
    pkill -f "rpicam-vid" 2>/dev/null
}

# =========================================================
# Startup checks
# =========================================================
if [ ! -f "$CONFIG" ]; then
    echo "Config not found: $CONFIG"
    exit 1
fi

# Set up signal handlers
trap cleanup_streams EXIT INT TERM

load_config
# if [ "$NIGHT_ENABLED" = "true" ]; then
#     apply_day_settings
# fi

# Apply correct mode at startup
if [ "$NIGHT_ENABLED" = "true" ]; then
    apply_day_settings
else
    NIGHT_MODE=false
    apply_day_settings
fi

STREAM_PID=""
SERVER_CHECK_COUNTER=0
SERVER_CHECK_INTERVAL=30  # Check server availability every 30 loops (150 seconds)

log "================================================"
log "🎥 Raspberry Pi Main + Sub Streaming Started"
log "📡 Local  Main : $LOCAL_MAIN_RTSP_URL"
log "📡 Local  Sub  : $LOCAL_SUB_RTSP_URL"
log "🌐 Server Main: $SERVER_MAIN_RTSP_URL"
log "🌐 Server Sub : $SERVER_SUB_RTSP_URL"
log "================================================"

# =========================================================
# Main loop
# =========================================================
while true; do

    if config_changed; then
        log "🔄 Config changed – restarting stream"
        cleanup_streams
        STREAM_PID=""
        load_config
    fi


    # # Automatic Night Mode
    # LUMA=$(get_luma)

    # if [ -n "$LUMA" ]; then
    #     if [ "$NIGHT_MODE" = false ] && \
    #     awk "BEGIN {exit !($LUMA < ($NIGHT_THRESHOLD - $NIGHT_HYSTERESIS))}"; then
    #         NIGHT_MODE=true
    #         apply_night_settings
    #         log "🌙 Night mode automatically enabled (Luma=$LUMA)"
    #     fi

    #     if [ "$NIGHT_MODE" = true ] && \
    #     awk "BEGIN {exit !($LUMA > ($NIGHT_THRESHOLD + $NIGHT_HYSTERESIS))}"; then
    #         NIGHT_MODE=false
    #         apply_day_settings
    #         log "☀️ Night mode automatically disabled (Luma=$LUMA)"
    #     fi
    # fi


    # -----------------------------------------------------
    # Manual Day / Auto Night logic
    # -----------------------------------------------------
    if [ "$NIGHT_ENABLED" = "true" ]; then
        # AUTO MODE
        LUMA=$(get_luma)

        if [ -n "$LUMA" ]; then
            if [ "$NIGHT_MODE" = false ] && \
               awk "BEGIN{exit !($LUMA < ($NIGHT_THRESHOLD - $NIGHT_HYSTERESIS))}"; then
                NIGHT_MODE=true
                apply_night_settings
                log "🌙 Auto Night enabled (Luma=$LUMA)"
            fi

            if [ "$NIGHT_MODE" = true ] && \
               awk "BEGIN{exit !($LUMA > ($NIGHT_THRESHOLD + $NIGHT_HYSTERESIS))}"; then
                NIGHT_MODE=false
                apply_day_settings
                log "☀️ Auto Day enabled (Luma=$LUMA)"
            fi
        fi
    else
        # MANUAL DAY
        if [ "$NIGHT_MODE" = true ]; then
            NIGHT_MODE=false
            apply_day_settings
            log "☀️ Manual DAY selected by user"
        fi
    fi



    # Periodic server availability check
    ((SERVER_CHECK_COUNTER++))
    if [ $SERVER_CHECK_COUNTER -ge $SERVER_CHECK_INTERVAL ]; then
        SERVER_CHECK_COUNTER=0
        CURRENT_SERVER_STATUS=$SERVER_ENABLED
        if server_available; then
            NEW_SERVER_STATUS=true
        else
            NEW_SERVER_STATUS=false
        fi
        
        # If server status changed, restart stream
        if [ "$CURRENT_SERVER_STATUS" != "$NEW_SERVER_STATUS" ]; then
            if [ "$NEW_SERVER_STATUS" = true ]; then
                log "🔄 Server became available – switching to dual-stream mode"
            else
                log "🔄 Server became unavailable – switching to local-only mode"
            fi
            cleanup_streams
            STREAM_PID=""
        fi
    fi

    if [ -z "$STREAM_PID" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then

        if [ -n "$STREAM_PID" ]; then
            log "⚠️  Stream process died, restarting..."
            cleanup_streams
        fi

        # Only wait for LOCAL MediaMTX (required)
        until nc -z "$LOCAL_IP" 8554 2>/dev/null; do
            log "⏳ Waiting for local MediaMTX on ${LOCAL_IP}:8554..."
            sleep 1
        done
        log "✓ Local MediaMTX connected"

        # Check server availability (non-blocking)
        if server_available; then
            log "✓ Server MediaMTX available at ${SERVER_IP}:${RTSP_PORT}"
            SERVER_ENABLED=true
        else
            log "⚠️  Server MediaMTX unreachable - streaming LOCAL ONLY"
            SERVER_ENABLED=false
        fi

        log "▶️  Starting camera capture and streaming pipeline..."

        # CMD=(
        #     rpicam-vid
        #     --timeout 0
        #     --nopreview
        #     --inline
        #     --flush
        #     --codec h264
        #     --width "$WIDTH"
        #     --height "$HEIGHT"
        #     --framerate "$FPS"
        #     --bitrate "$BITRATE"
        #     --brightness "$BRIGHTNESS"
        #     --contrast "$CONTRAST"
        #     --saturation "$SATURATION"
        #     --sharpness "$SHARPNESS"
        #     --autofocus-mode "$AF_MODE"
        #     --profile main
        #     --level 4.2
        #     -o -
        # )


        CMD=(
            rpicam-vid
            --timeout 0
            --nopreview
            --inline
            --flush
            --codec h264
            --width "$WIDTH"
            --height "$HEIGHT"
            --framerate "$FPS"
            --bitrate "$BITRATE"
            --intra "$GOP"
            --profile "$PROFILE"
            --level 4.2
            --brightness "$BRIGHTNESS"
            --contrast "$CONTRAST"
            --saturation "$SATURATION"
            --sharpness "$SHARPNESS"
            --autofocus-mode "$AF_MODE"
            --denoise cdn_fast
            -o -
        )


        [ "$AF_MODE" = "manual" ] && CMD+=(--lens-position "$LENS")

        if [ "$HDR" = "true" ]; then
            CMD+=(--hdr)
            log "🌈 HDR enabled"
        else
            log "🌈 HDR disabled (recommended for streaming)"
        fi


        # Build streaming pipeline based on server availability
        if [ "$SERVER_ENABLED" = true ]; then
            # CPU-OPTIMIZED: Share encoded sub-stream between local and server
            (
            set -m  # Enable job control to create process group
            
            # Split main stream to local + server (zero CPU - just copy)
            "${CMD[@]}" 2>/dev/null | tee \
                >( ffmpeg -hide_banner -loglevel fatal \
                    -fflags +genpts+discardcorrupt \
                    -flags low_delay \
                    -f h264 -i pipe:0 \
                    -c:v copy \
                    -flags:v +global_header \
                    -bsf:v dump_extra \
                    -f rtsp -rtsp_transport tcp \
                    -max_delay 500000 \
                    "${LOCAL_MAIN_RTSP_URL}" 2>&1 | grep -v "frame duplication" >>"$LOG" & ) \
                >( ffmpeg -hide_banner -loglevel fatal \
                    -fflags +genpts+discardcorrupt \
                    -flags low_delay \
                    -f h264 -i pipe:0 \
                    -c:v copy \
                    -flags:v +global_header \
                    -bsf:v dump_extra \
                    -f rtsp -rtsp_transport tcp \
                    -max_delay 500000 \
                    "${SERVER_MAIN_RTSP_URL}" 2>&1 | grep -v "frame duplication\|Broken pipe" >>"$LOG" & ) | \
            ffmpeg -hide_banner -loglevel fatal \
                -fflags +genpts+discardcorrupt \
                -flags low_delay \
                -f h264 -i pipe:0 \
                -vf "scale=${SUB_WIDTH}:${SUB_HEIGHT}:flags=fast_bilinear" \
                -c:v libx264 -preset ultrafast -tune zerolatency \
                -b:v ${SUB_BITRATE} -maxrate ${SUB_BITRATE} -bufsize $((SUB_BITRATE)) \
                -r ${SUB_FPS} -g ${SUB_FPS} -pix_fmt yuv420p \
                -flags:v +global_header \
                -bsf:v dump_extra \
                -threads 2 \
                -f tee -map 0:v \
                "[f=rtsp:rtsp_transport=tcp]${LOCAL_SUB_RTSP_URL}|[f=rtsp:rtsp_transport=tcp:onfail=ignore]${SERVER_SUB_RTSP_URL}" \
                2>&1 | grep -v "frame duplication\|Broken pipe" >>"$LOG"
            ) &
            log "✅ Streaming to LOCAL + SERVER (CPU optimized - single sub-stream encoder)"
        else
            # Stream to LOCAL ONLY
            (
            set -m  # Enable job control to create process group
            "${CMD[@]}" 2>/dev/null | \
            tee >( \
                ffmpeg -hide_banner -loglevel fatal \
                    -fflags +genpts+discardcorrupt \
                    -flags low_delay \
                    -f h264 -i pipe:0 \
                    -c:v copy \
                    -flags:v +global_header \
                    -bsf:v dump_extra \
                    -f rtsp -rtsp_transport tcp \
                    -max_delay 500000 \
                    "${LOCAL_MAIN_RTSP_URL}" 2>&1 | grep -v "frame duplication" >>"$LOG" \
            ) | \
            ffmpeg -hide_banner -loglevel fatal \
                -fflags +genpts+discardcorrupt \
                -flags low_delay \
                -f h264 -i pipe:0 \
                -vf "scale=${SUB_WIDTH}:${SUB_HEIGHT}:flags=fast_bilinear" \
                -c:v libx264 -preset ultrafast -tune zerolatency \
                -b:v ${SUB_BITRATE} -maxrate ${SUB_BITRATE} -bufsize $((SUB_BITRATE)) \
                -r ${SUB_FPS} -g ${SUB_FPS} \
                -pix_fmt yuv420p \
                -flags:v +global_header \
                -bsf:v dump_extra \
                -threads 2 \
                -f rtsp -rtsp_transport tcp \
                -max_delay 500000 \
                "${LOCAL_SUB_RTSP_URL}" 2>&1 | grep -v "frame duplication" >>"$LOG"
            ) &
            log "✅ Streaming to LOCAL ONLY (server unavailable)"
        fi

        STREAM_PID=$!
        log "✅ Streaming running (PID: $STREAM_PID)"
        log "   📹 Main: Hardware H.264 → RTSP copy (zero CPU)"
        log "   📹 Sub: Single encoder → split to local + server"
        log "   ⚙️  Main bitrate: ${BITRATE}, FPS: ${FPS}"
        log "   ⚙️  Sub bitrate: ${SUB_BITRATE}, FPS: ${SUB_FPS}"
        log "   ⚡ CPU optimized: 2 copy streams + 1 encode stream"
    fi

    sleep 5
done
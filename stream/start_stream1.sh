# #!/bin/bash

# # =========================================================
# # Raspberry Pi Camera → Local + Server MediaMTX
# # Main / Sub RTSP Streaming (CPU OPTIMIZED)
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
#     size=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
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

#     GOP=$(jq -r '.camera.gop // 50' "$CONFIG")
#     PROFILE=$(jq -r '.camera.profile // "main"' "$CONFIG")
#     RC_MODE=$(jq -r '.camera.rc_mode // "vbr"' "$CONFIG")
#     HDR=$(jq -r '.camera.hdr // false' "$CONFIG")

#     # Night mode config
#     NIGHT_ENABLED=$(jq -r '.night.enabled // false' "$CONFIG")
#     NIGHT_THRESHOLD=$(jq -r '.night.threshold // 0.18' "$CONFIG")
#     NIGHT_HYSTERESIS=$(jq -r '.night.hysteresis // 0.05' "$CONFIG")


#     # RTSP URLs
#     LOCAL_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:8554/${STREAM_NAME}/Main"
#     LOCAL_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:8554/${STREAM_NAME}/Sub"

#     SERVER_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Main"
#     SERVER_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Sub"

#     # Export RTSP info for ONVIF
#     export ONVIF_RTSP_PORT="8554"
#     export ONVIF_STREAM_NAME="${STREAM_NAME}"
#     export ONVIF_RTSP_MAIN_PATH="${STREAM_NAME}/Main"
#     export ONVIF_RTSP_SUB_PATH="${STREAM_NAME}/Sub"
#     export ONVIF_RTSP_USER="${RTSP_USER}"
#     export ONVIF_RTSP_PASS="${RTSP_PASS}"
# }

# # =========================================================
# # Check if server is reachable (with timeout)
# # =========================================================
# server_available() {
#     timeout 2 nc -z "$SERVER_IP" "$RTSP_PORT" 2>/dev/null
#     return $?
# }



# # =========================================================
# # Night detection helpers
# # =========================================================
# NIGHT_MODE=false

# get_luma() {
#     # Capture 1 frame, calculate average brightness (0–1)
#     rpicam-still -n -t 50 --width 320 --height 240 -o - 2>/dev/null | \
#     ffmpeg -hide_banner -loglevel fatal -i pipe:0 \
#         -vf "signalstats" -frames:v 1 -f null - 2>&1 | \
#     awk -F'YAVG:' '{print $2}' | awk '{print $1/255}'
# }

# # apply_day_settings() {
# #     log "☀️ Switching to DAY exposure"
# #     rpicam-ctl set exposure auto
# #     rpicam-ctl set analoggain 1
# #     rpicam-ctl set shutter 0
# # }

# # apply_night_settings() {
# #     log "🌙 Switching to NIGHT exposure"
# #     rpicam-ctl set exposure long
# #     rpicam-ctl set analoggain 8
# #     rpicam-ctl set shutter 100000
# # }


# # =========================================================
# # Camera tuning (NoIR Wide)
# # =========================================================
# apply_day_settings() {
#     log "☀️ DAY MODE (forced)"
#     rpicam-ctl set exposure normal
#     rpicam-ctl set analoggain 1
#     rpicam-ctl set shutter 0
#     rpicam-ctl set awb auto
# }

# apply_night_settings() {
#     log "🌙 NIGHT MODE (auto)"
#     rpicam-ctl set exposure long
#     rpicam-ctl set analoggain 6
#     rpicam-ctl set shutter 100000
#     rpicam-ctl set awb greyworld
# }


# # =========================================================
# # Cleanup function
# # =========================================================
# cleanup_streams() {
#     if [ -n "$STREAM_PID" ]; then
#         log "🛑 Stopping stream processes (PID: $STREAM_PID)"
#         # Kill entire process group
#         kill -TERM -$STREAM_PID 2>/dev/null || kill -TERM $STREAM_PID 2>/dev/null
#         sleep 1
#         # Force kill if still running
#         kill -9 -$STREAM_PID 2>/dev/null || kill -9 $STREAM_PID 2>/dev/null
#         wait $STREAM_PID 2>/dev/null
#     fi
#     # Kill any orphaned ffmpeg/rpicam-vid processes
#     pkill -f "ffmpeg.*${STREAM_NAME}" 2>/dev/null
#     pkill -f "rpicam-vid" 2>/dev/null
# }

# # =========================================================
# # Startup checks
# # =========================================================
# if [ ! -f "$CONFIG" ]; then
#     echo "Config not found: $CONFIG"
#     exit 1
# fi

# # Set up signal handlers
# trap cleanup_streams EXIT INT TERM

# load_config
# # if [ "$NIGHT_ENABLED" = "true" ]; then
# #     apply_day_settings
# # fi

# # Apply correct mode at startup
# if [ "$NIGHT_ENABLED" = "true" ]; then
#     apply_day_settings
# else
#     NIGHT_MODE=false
#     apply_day_settings
# fi

# STREAM_PID=""
# SERVER_CHECK_COUNTER=0
# SERVER_CHECK_INTERVAL=1  # Check server availability every 30 loops (150 seconds)

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
#         cleanup_streams
#         STREAM_PID=""
#         load_config
#     fi


#     # # Automatic Night Mode
#     # LUMA=$(get_luma)

#     # if [ -n "$LUMA" ]; then
#     #     if [ "$NIGHT_MODE" = false ] && \
#     #     awk "BEGIN {exit !($LUMA < ($NIGHT_THRESHOLD - $NIGHT_HYSTERESIS))}"; then
#     #         NIGHT_MODE=true
#     #         apply_night_settings
#     #         log "🌙 Night mode automatically enabled (Luma=$LUMA)"
#     #     fi

#     #     if [ "$NIGHT_MODE" = true ] && \
#     #     awk "BEGIN {exit !($LUMA > ($NIGHT_THRESHOLD + $NIGHT_HYSTERESIS))}"; then
#     #         NIGHT_MODE=false
#     #         apply_day_settings
#     #         log "☀️ Night mode automatically disabled (Luma=$LUMA)"
#     #     fi
#     # fi


#     # -----------------------------------------------------
#     # Manual Day / Auto Night logic
#     # -----------------------------------------------------
#     if [ "$NIGHT_ENABLED" = "true" ]; then
#         # AUTO MODE
#         LUMA=$(get_luma)

#         if [ -n "$LUMA" ]; then
#             if [ "$NIGHT_MODE" = false ] && \
#                awk "BEGIN{exit !($LUMA < ($NIGHT_THRESHOLD - $NIGHT_HYSTERESIS))}"; then
#                 NIGHT_MODE=true
#                 apply_night_settings
#                 log "🌙 Auto Night enabled (Luma=$LUMA)"
#             fi

#             if [ "$NIGHT_MODE" = true ] && \
#                awk "BEGIN{exit !($LUMA > ($NIGHT_THRESHOLD + $NIGHT_HYSTERESIS))}"; then
#                 NIGHT_MODE=false
#                 apply_day_settings
#                 log "☀️ Auto Day enabled (Luma=$LUMA)"
#             fi
#         fi
#     else
#         # MANUAL DAY
#         if [ "$NIGHT_MODE" = true ]; then
#             NIGHT_MODE=false
#             apply_day_settings
#             log "☀️ Manual DAY selected by user"
#         fi
#     fi



#     # Periodic server availability check
#     ((SERVER_CHECK_COUNTER++))
#     if [ $SERVER_CHECK_COUNTER -ge $SERVER_CHECK_INTERVAL ]; then
#         SERVER_CHECK_COUNTER=0
#         CURRENT_SERVER_STATUS=$SERVER_ENABLED
#         if server_available; then
#             NEW_SERVER_STATUS=true
#         else
#             NEW_SERVER_STATUS=false
#         fi
        
#         # If server status changed, restart stream
#         if [ "$CURRENT_SERVER_STATUS" != "$NEW_SERVER_STATUS" ]; then
#             SERVER_ENABLED=$NEW_SERVER_STATUS   # ← CRITICAL FIX
#             if [ "$NEW_SERVER_STATUS" = true ]; then
#                 log "🔄 Server became available – switching to dual-stream mode"
#             else
#                 log "🔄 Server became unavailable – switching to local-only mode"
#             fi
#             cleanup_streams
#             STREAM_PID=""
#         fi
#     fi

#     if [ -z "$STREAM_PID" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then

#         if [ -n "$STREAM_PID" ]; then
#             log "⚠️  Stream process died, restarting..."
#             cleanup_streams
#         fi

#         # Only wait for LOCAL MediaMTX (required)
#         until nc -z "$LOCAL_IP" 8554 2>/dev/null; do
#             log "⏳ Waiting for local MediaMTX on ${LOCAL_IP}:8554..."
#             sleep 1
#         done
#         log "✓ Local MediaMTX connected"

#         # Check server availability (non-blocking)
#         if server_available; then
#             log "✓ Server MediaMTX available at ${SERVER_IP}:${RTSP_PORT}"
#             SERVER_ENABLED=true
#         else
#             log "⚠️  Server MediaMTX unreachable - streaming LOCAL ONLY"
#             SERVER_ENABLED=false
#         fi

#         log "▶️  Starting camera capture and streaming pipeline..."

#         # CMD=(
#         #     rpicam-vid
#         #     --timeout 0
#         #     --nopreview
#         #     --inline
#         #     --flush
#         #     --codec h264
#         #     --width "$WIDTH"
#         #     --height "$HEIGHT"
#         #     --framerate "$FPS"
#         #     --bitrate "$BITRATE"
#         #     --brightness "$BRIGHTNESS"
#         #     --contrast "$CONTRAST"
#         #     --saturation "$SATURATION"
#         #     --sharpness "$SHARPNESS"
#         #     --autofocus-mode "$AF_MODE"
#         #     --profile main
#         #     --level 4.2
#         #     -o -
#         # )


#         CMD=(
#             rpicam-vid
#             --timeout 0
#             --nopreview
#             --inline
#             --flush
#             --codec h264
#             --width "$WIDTH"
#             --height "$HEIGHT"
#             --framerate "$FPS"
#             --bitrate "$BITRATE"
#             --intra "$GOP"
#             --profile "$PROFILE"
#             --level 4.2
#             --brightness "$BRIGHTNESS"
#             --contrast "$CONTRAST"
#             --saturation "$SATURATION"
#             --sharpness "$SHARPNESS"
#             --autofocus-mode "$AF_MODE"
#             --denoise cdn_fast
#             -o -
#         )


#         [ "$AF_MODE" = "manual" ] && CMD+=(--lens-position "$LENS")

#         if [ "$HDR" = "true" ]; then
#             CMD+=(--hdr)
#             log "🌈 HDR enabled"
#         else
#             log "🌈 HDR disabled (recommended for streaming)"
#         fi


#         # Build streaming pipeline based on server availability
#         if [ "$SERVER_ENABLED" = true ]; then
#             # CPU-OPTIMIZED: Share encoded sub-stream between local and server
#             (
#             set -m  # Enable job control to create process group
            
#             # Split main stream to local + server (zero CPU - just copy)
#             "${CMD[@]}" 2>/dev/null | tee \
#                 >( ffmpeg -hide_banner -loglevel fatal \
#                     -fflags +genpts+discardcorrupt \
#                     -flags low_delay \
#                     -f h264 -i pipe:0 \
#                     -c:v copy \
#                     -flags:v +global_header \
#                     -bsf:v dump_extra \
#                     -f rtsp -rtsp_transport tcp \
#                     -max_delay 500000 \
#                     "${LOCAL_MAIN_RTSP_URL}" 2>&1 | grep -v "frame duplication" >>"$LOG" & ) \
#                 >( ffmpeg -hide_banner -loglevel fatal \
#                     -fflags +genpts+discardcorrupt \
#                     -flags low_delay \
#                     -f h264 -i pipe:0 \
#                     -c:v copy \
#                     -flags:v +global_header \
#                     -bsf:v dump_extra \
#                     -f rtsp -rtsp_transport tcp \
#                     -max_delay 500000 \
#                     "${SERVER_MAIN_RTSP_URL}" 2>&1 | grep -v "frame duplication\|Broken pipe" >>"$LOG" & ) | \
#             ffmpeg -hide_banner -loglevel fatal \
#                 -fflags +genpts+discardcorrupt \
#                 -flags low_delay \
#                 -f h264 -i pipe:0 \
#                 -vf "scale=${SUB_WIDTH}:${SUB_HEIGHT}:flags=fast_bilinear" \
#                 -c:v libx264 -preset ultrafast -tune zerolatency \
#                 -b:v ${SUB_BITRATE} -maxrate ${SUB_BITRATE} -bufsize $((SUB_BITRATE)) \
#                 -r ${SUB_FPS} -g ${SUB_FPS} -pix_fmt yuv420p \
#                 -flags:v +global_header \
#                 -bsf:v dump_extra \
#                 -threads 2 \
#                 -f tee -map 0:v \
#                 "[f=rtsp:rtsp_transport=tcp]${LOCAL_SUB_RTSP_URL}|[f=rtsp:rtsp_transport=tcp:onfail=ignore]${SERVER_SUB_RTSP_URL}" \
#                 2>&1 | grep -v "frame duplication\|Broken pipe" >>"$LOG"
#             ) &
#             log "✅ Streaming to LOCAL + SERVER (CPU optimized - single sub-stream encoder)"
#         else
#             # Stream to LOCAL ONLY
#             (
#             set -m  # Enable job control to create process group
#             "${CMD[@]}" 2>/dev/null | \
#             tee >( \
#                 ffmpeg -hide_banner -loglevel fatal \
#                     -fflags +genpts+discardcorrupt \
#                     -flags low_delay \
#                     -f h264 -i pipe:0 \
#                     -c:v copy \
#                     -flags:v +global_header \
#                     -bsf:v dump_extra \
#                     -f rtsp -rtsp_transport tcp \
#                     -max_delay 500000 \
#                     "${LOCAL_MAIN_RTSP_URL}" 2>&1 | grep -v "frame duplication" >>"$LOG" \
#             ) | \
#             ffmpeg -hide_banner -loglevel fatal \
#                 -fflags +genpts+discardcorrupt \
#                 -flags low_delay \
#                 -f h264 -i pipe:0 \
#                 -vf "scale=${SUB_WIDTH}:${SUB_HEIGHT}:flags=fast_bilinear" \
#                 -c:v libx264 -preset ultrafast -tune zerolatency \
#                 -b:v ${SUB_BITRATE} -maxrate ${SUB_BITRATE} -bufsize $((SUB_BITRATE)) \
#                 -r ${SUB_FPS} -g ${SUB_FPS} \
#                 -pix_fmt yuv420p \
#                 -flags:v +global_header \
#                 -bsf:v dump_extra \
#                 -threads 2 \
#                 -f rtsp -rtsp_transport tcp \
#                 -max_delay 500000 \
#                 "${LOCAL_SUB_RTSP_URL}" 2>&1 | grep -v "frame duplication" >>"$LOG"
#             ) &
#             log "✅ Streaming to LOCAL ONLY (server unavailable)"
#         fi

#         STREAM_PID=$!
#         log "✅ Streaming running (PID: $STREAM_PID)"
#         log "   📹 Main: Hardware H.264 → RTSP copy (zero CPU)"
#         log "   📹 Sub: Single encoder → split to local + server"
#         log "   ⚙️  Main bitrate: ${BITRATE}, FPS: ${FPS}"
#         log "   ⚙️  Sub bitrate: ${SUB_BITRATE}, FPS: ${SUB_FPS}"
#         log "   ⚡ CPU optimized: 2 copy streams + 1 encode stream"
#     fi

#     sleep 5
# done




# #!/bin/bash

# # =========================================================
# # Raspberry Pi Camera → Local + Server MediaMTX
# # Main / Sub RTSP Streaming (CPU OPTIMIZED)
# # With Server Heartbeat Feature
# # =========================================================

# CONFIG="/home/pi/ipcam/backend/config.json"
# LOG_DIR="/home/pi/ipcam/stream/logs"
# LOG="$LOG_DIR/stream.log"
# CONFIG_CHECKSUM_FILE="/tmp/stream_config_checksum"

# MAX_LOG_SIZE=$((5 * 1024 * 1024))
# MAX_LOG_FILES=5

# # Heartbeat configuration
# HEARTBEAT_INTERVAL_CONNECTED=1800  # 30 minutes when server is online
# HEARTBEAT_INTERVAL_DISCONNECTED=5   # 5 seconds when server is offline
# LAST_HEARTBEAT_TIME=0

# mkdir -p "$LOG_DIR"

# # =========================================================
# # Logging with rotation
# # =========================================================
# rotate_logs() {
#     [ -f "$LOG" ] || return
#     size=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
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

#     GOP=$(jq -r '.camera.gop // 50' "$CONFIG")
#     PROFILE=$(jq -r '.camera.profile // "main"' "$CONFIG")
#     RC_MODE=$(jq -r '.camera.rc_mode // "vbr"' "$CONFIG")
#     HDR=$(jq -r '.camera.hdr // false' "$CONFIG")

#     # Night mode config
#     NIGHT_ENABLED=$(jq -r '.night.enabled // false' "$CONFIG")
#     NIGHT_THRESHOLD=$(jq -r '.night.threshold // 0.18' "$CONFIG")
#     NIGHT_HYSTERESIS=$(jq -r '.night.hysteresis // 0.05' "$CONFIG")


#     # RTSP URLs
#     LOCAL_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:8554/${STREAM_NAME}/Main"
#     LOCAL_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:8554/${STREAM_NAME}/Sub"

#     SERVER_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Main"
#     SERVER_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Sub"

#     # Export RTSP info for ONVIF
#     export ONVIF_RTSP_PORT="8554"
#     export ONVIF_STREAM_NAME="${STREAM_NAME}"
#     export ONVIF_RTSP_MAIN_PATH="${STREAM_NAME}/Main"
#     export ONVIF_RTSP_SUB_PATH="${STREAM_NAME}/Sub"
#     export ONVIF_RTSP_USER="${RTSP_USER}"
#     export ONVIF_RTSP_PASS="${RTSP_PASS}"
# }

# # =========================================================
# # Check if server is reachable (with timeout)
# # =========================================================
# server_available() {
#     timeout 2 nc -z "$SERVER_IP" "$RTSP_PORT" 2>/dev/null
#     return $?
# }

# # =========================================================
# # Heartbeat function
# # =========================================================
# send_heartbeat() {
#     local current_time=$(date +%s)
#     local time_since_last_heartbeat=$((current_time - LAST_HEARTBEAT_TIME))
    
#     # Determine required interval based on server status
#     local required_interval
#     if [ "$SERVER_ENABLED" = true ]; then
#         required_interval=$HEARTBEAT_INTERVAL_CONNECTED
#     else
#         required_interval=$HEARTBEAT_INTERVAL_DISCONNECTED
#     fi
    
#     # Check if it's time to send heartbeat
#     if [ $time_since_last_heartbeat -ge $required_interval ]; then
#         if [ "$SERVER_ENABLED" = true ]; then
#             # Server is online - send TCP ping heartbeat
#             if timeout 2 nc -z "$SERVER_IP" "$RTSP_PORT" 2>/dev/null; then
#                 log "Heartbeat sent to server (connected mode - 30min interval)"
#             else
#                 log "Heartbeat failed - server may be disconnecting"
#             fi
#         else
#             # Server is offline - send TCP ping heartbeat
#             if timeout 2 nc -z "$SERVER_IP" "$RTSP_PORT" 2>/dev/null; then
#                 log "Heartbeat detected server is back online (5sec interval)"
#             else
#                 log "Heartbeat attempt (server offline - 5sec interval)"
#             fi
#         fi
        
#         LAST_HEARTBEAT_TIME=$current_time
#     fi
# }

# # =========================================================
# # Night detection helpers
# # =========================================================
# NIGHT_MODE=false

# get_luma() {
#     # Capture 1 frame, calculate average brightness (0–1)
#     rpicam-still -n -t 50 --width 320 --height 240 -o - 2>/dev/null | \
#     ffmpeg -hide_banner -loglevel fatal -i pipe:0 \
#         -vf "signalstats" -frames:v 1 -f null - 2>&1 | \
#     awk -F'YAVG:' '{print $2}' | awk '{print $1/255}'
# }

# # =========================================================
# # Camera tuning (NoIR Wide)
# # =========================================================
# apply_day_settings() {
#     log "☀️ DAY MODE (forced)"
#     rpicam-ctl set exposure normal
#     rpicam-ctl set analoggain 1
#     rpicam-ctl set shutter 0
#     rpicam-ctl set awb auto
# }

# apply_night_settings() {
#     log "🌙 NIGHT MODE (auto)"
#     rpicam-ctl set exposure long
#     rpicam-ctl set analoggain 6
#     rpicam-ctl set shutter 100000
#     rpicam-ctl set awb greyworld
# }

# # =========================================================
# # Cleanup function
# # =========================================================
# cleanup_streams() {
#     if [ -n "$STREAM_PID" ]; then
#         log "🛑 Stopping stream processes (PID: $STREAM_PID)"
#         # Kill entire process group
#         kill -TERM -$STREAM_PID 2>/dev/null || kill -TERM $STREAM_PID 2>/dev/null
#         sleep 1
#         # Force kill if still running
#         kill -9 -$STREAM_PID 2>/dev/null || kill -9 $STREAM_PID 2>/dev/null
#         wait $STREAM_PID 2>/dev/null
#     fi
#     # Kill any orphaned ffmpeg/rpicam-vid processes
#     pkill -f "ffmpeg.*${STREAM_NAME}" 2>/dev/null
#     pkill -f "rpicam-vid" 2>/dev/null
# }

# # =========================================================
# # Startup checks
# # =========================================================
# if [ ! -f "$CONFIG" ]; then
#     echo "Config not found: $CONFIG"
#     exit 1
# fi

# # Set up signal handlers
# trap cleanup_streams EXIT INT TERM

# load_config

# # Apply correct mode at startup
# if [ "$NIGHT_ENABLED" = "true" ]; then
#     apply_day_settings
# else
#     NIGHT_MODE=false
#     apply_day_settings
# fi

# STREAM_PID=""
# SERVER_CHECK_COUNTER=0
# SERVER_CHECK_INTERVAL=1  # Check server availability every loop iteration

# log "================================================"
# log "🎥 Raspberry Pi Main + Sub Streaming Started"
# log "📡 Local  Main : $LOCAL_MAIN_RTSP_URL"
# log "📡 Local  Sub  : $LOCAL_SUB_RTSP_URL"
# log "🌐 Server Main: $SERVER_MAIN_RTSP_URL"
# log "🌐 Server Sub : $SERVER_SUB_RTSP_URL"
# log "Heartbeat: 30min (connected) / 5sec (disconnected)"
# log "================================================"

# # =========================================================
# # Main loop
# # =========================================================
# while true; do

#     if config_changed; then
#         log "🔄 Config changed – restarting stream"
#         cleanup_streams
#         STREAM_PID=""
#         load_config
#     fi

#     # -----------------------------------------------------
#     # Manual Day / Auto Night logic
#     # -----------------------------------------------------
#     if [ "$NIGHT_ENABLED" = "true" ]; then
#         # AUTO MODE
#         LUMA=$(get_luma)

#         if [ -n "$LUMA" ]; then
#             if [ "$NIGHT_MODE" = false ] && \
#                awk "BEGIN{exit !($LUMA < ($NIGHT_THRESHOLD - $NIGHT_HYSTERESIS))}"; then
#                 NIGHT_MODE=true
#                 apply_night_settings
#                 log "🌙 Auto Night enabled (Luma=$LUMA)"
#             fi

#             if [ "$NIGHT_MODE" = true ] && \
#                awk "BEGIN{exit !($LUMA > ($NIGHT_THRESHOLD + $NIGHT_HYSTERESIS))}"; then
#                 NIGHT_MODE=false
#                 apply_day_settings
#                 log "☀️ Auto Day enabled (Luma=$LUMA)"
#             fi
#         fi
#     else
#         # MANUAL DAY
#         if [ "$NIGHT_MODE" = true ]; then
#             NIGHT_MODE=false
#             apply_day_settings
#             log "☀️ Manual DAY selected by user"
#         fi
#     fi

#     # Periodic server availability check
#     ((SERVER_CHECK_COUNTER++))
#     if [ $SERVER_CHECK_COUNTER -ge $SERVER_CHECK_INTERVAL ]; then
#         SERVER_CHECK_COUNTER=0
#         CURRENT_SERVER_STATUS=$SERVER_ENABLED
#         if server_available; then
#             NEW_SERVER_STATUS=true
#         else
#             NEW_SERVER_STATUS=false
#         fi
        
#         # If server status changed, restart stream and reset heartbeat
#         if [ "$CURRENT_SERVER_STATUS" != "$NEW_SERVER_STATUS" ]; then
#             SERVER_ENABLED=$NEW_SERVER_STATUS
#             # Reset heartbeat timer on status change
#             LAST_HEARTBEAT_TIME=$(date +%s)
            
#             if [ "$NEW_SERVER_STATUS" = true ]; then
#                 log "🔄 Server became available – switching to dual-stream mode"
#             else
#                 log "🔄 Server became unavailable – switching to local-only mode"
#             fi
#             cleanup_streams
#             STREAM_PID=""
#         fi
#     fi

#     # Send heartbeat based on current server status
#     send_heartbeat

#     if [ -z "$STREAM_PID" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then

#         if [ -n "$STREAM_PID" ]; then
#             log "⚠️  Stream process died, restarting..."
#             cleanup_streams
#         fi

#         # Only wait for LOCAL MediaMTX (required)
#         until nc -z "$LOCAL_IP" 8554 2>/dev/null; do
#             log "⏳ Waiting for local MediaMTX on ${LOCAL_IP}:8554..."
#             sleep 1
#         done
#         log "✓ Local MediaMTX connected"

#         # Check server availability (non-blocking)
#         if server_available; then
#             log "✓ Server MediaMTX available at ${SERVER_IP}:${RTSP_PORT}"
#             SERVER_ENABLED=true
#         else
#             log "⚠️  Server MediaMTX unreachable - streaming LOCAL ONLY"
#             SERVER_ENABLED=false
#         fi

#         # Initialize heartbeat timer when starting stream
#         LAST_HEARTBEAT_TIME=$(date +%s)

#         log "▶️  Starting camera capture and streaming pipeline..."

#         CMD=(
#             rpicam-vid
#             --timeout 0
#             --nopreview
#             --inline
#             --flush
#             --codec h264
#             --width "$WIDTH"
#             --height "$HEIGHT"
#             --framerate "$FPS"
#             --bitrate "$BITRATE"
#             --intra "$GOP"
#             --profile "$PROFILE"
#             --level 4.2
#             --brightness "$BRIGHTNESS"
#             --contrast "$CONTRAST"
#             --saturation "$SATURATION"
#             --sharpness "$SHARPNESS"
#             --autofocus-mode "$AF_MODE"
#             --denoise cdn_fast
#             -o -
#         )

#         [ "$AF_MODE" = "manual" ] && CMD+=(--lens-position "$LENS")

#         if [ "$HDR" = "true" ]; then
#             CMD+=(--hdr)
#             log "🌈 HDR enabled"
#         else
#             log "🌈 HDR disabled (recommended for streaming)"
#         fi

#         # Build streaming pipeline based on server availability
#         if [ "$SERVER_ENABLED" = true ]; then
#             # CPU-OPTIMIZED: Share encoded sub-stream between local and server
#             (
#             set -m  # Enable job control to create process group
            
#             # Split main stream to local + server (zero CPU - just copy)
#             "${CMD[@]}" 2>/dev/null | tee \
#                 >( ffmpeg -hide_banner -loglevel fatal \
#                     -fflags +genpts+discardcorrupt \
#                     -flags low_delay \
#                     -f h264 -i pipe:0 \
#                     -c:v copy \
#                     -flags:v +global_header \
#                     -bsf:v dump_extra \
#                     -f rtsp -rtsp_transport tcp \
#                     -max_delay 500000 \
#                     "${LOCAL_MAIN_RTSP_URL}" 2>&1 | grep -v "frame duplication" >>"$LOG" & ) \
#                 >( ffmpeg -hide_banner -loglevel fatal \
#                     -fflags +genpts+discardcorrupt \
#                     -flags low_delay \
#                     -f h264 -i pipe:0 \
#                     -c:v copy \
#                     -flags:v +global_header \
#                     -bsf:v dump_extra \
#                     -f rtsp -rtsp_transport tcp \
#                     -max_delay 500000 \
#                     "${SERVER_MAIN_RTSP_URL}" 2>&1 | grep -v "frame duplication\|Broken pipe" >>"$LOG" & ) | \
#             ffmpeg -hide_banner -loglevel fatal \
#                 -fflags +genpts+discardcorrupt \
#                 -flags low_delay \
#                 -f h264 -i pipe:0 \
#                 -vf "scale=${SUB_WIDTH}:${SUB_HEIGHT}:flags=fast_bilinear" \
#                 -c:v libx264 -preset ultrafast -tune zerolatency \
#                 -b:v ${SUB_BITRATE} -maxrate ${SUB_BITRATE} -bufsize $((SUB_BITRATE)) \
#                 -r ${SUB_FPS} -g ${SUB_FPS} -pix_fmt yuv420p \
#                 -flags:v +global_header \
#                 -bsf:v dump_extra \
#                 -threads 2 \
#                 -f tee -map 0:v \
#                 "[f=rtsp:rtsp_transport=tcp]${LOCAL_SUB_RTSP_URL}|[f=rtsp:rtsp_transport=tcp:onfail=ignore]${SERVER_SUB_RTSP_URL}" \
#                 2>&1 | grep -v "frame duplication\|Broken pipe" >>"$LOG"
#             ) &
#             log "✅ Streaming to LOCAL + SERVER (CPU optimized - single sub-stream encoder)"
#         else
#             # Stream to LOCAL ONLY
#             (
#             set -m  # Enable job control to create process group
#             "${CMD[@]}" 2>/dev/null | \
#             tee >( \
#                 ffmpeg -hide_banner -loglevel fatal \
#                     -fflags +genpts+discardcorrupt \
#                     -flags low_delay \
#                     -f h264 -i pipe:0 \
#                     -c:v copy \
#                     -flags:v +global_header \
#                     -bsf:v dump_extra \
#                     -f rtsp -rtsp_transport tcp \
#                     -max_delay 500000 \
#                     "${LOCAL_MAIN_RTSP_URL}" 2>&1 | grep -v "frame duplication" >>"$LOG" \
#             ) | \
#             ffmpeg -hide_banner -loglevel fatal \
#                 -fflags +genpts+discardcorrupt \
#                 -flags low_delay \
#                 -f h264 -i pipe:0 \
#                 -vf "scale=${SUB_WIDTH}:${SUB_HEIGHT}:flags=fast_bilinear" \
#                 -c:v libx264 -preset ultrafast -tune zerolatency \
#                 -b:v ${SUB_BITRATE} -maxrate ${SUB_BITRATE} -bufsize $((SUB_BITRATE)) \
#                 -r ${SUB_FPS} -g ${SUB_FPS} \
#                 -pix_fmt yuv420p \
#                 -flags:v +global_header \
#                 -bsf:v dump_extra \
#                 -threads 2 \
#                 -f rtsp -rtsp_transport tcp \
#                 -max_delay 500000 \
#                 "${LOCAL_SUB_RTSP_URL}" 2>&1 | grep -v "frame duplication" >>"$LOG"
#             ) &
#             log "✅ Streaming to LOCAL ONLY (server unavailable)"
#         fi

#         STREAM_PID=$!
#         log "✅ Streaming running (PID: $STREAM_PID)"
#         log "   📹 Main: Hardware H.264 → RTSP copy (zero CPU)"
#         log "   📹 Sub: Single encoder → split to local + server"
#         log "   ⚙️  Main bitrate: ${BITRATE}, FPS: ${FPS}"
#         log "   ⚙️  Sub bitrate: ${SUB_BITRATE}, FPS: ${SUB_FPS}"
#         log "   ⚡ CPU optimized: 2 copy streams + 1 encode stream"
#     fi

#     sleep 5
# done








# #!/bin/bash

# # =========================================================
# # Raspberry Pi Camera → Local + Server MediaMTX
# # Main / Sub RTSP Streaming (CPU OPTIMIZED)
# # Enhanced with automatic reconnection and error recovery
# # =========================================================

# CONFIG="/home/pi/ipcam/backend/config.json"
# LOG_DIR="/home/pi/ipcam/stream/logs"
# LOG="$LOG_DIR/stream.log"
# CONFIG_CHECKSUM_FILE="/tmp/stream_config_checksum"

# # Constants
# MAX_LOG_SIZE=$((5 * 1024 * 1024))
# MAX_LOG_FILES=5
# LOCAL_RTSP_PORT=8554
# SERVER_CHECK_TIMEOUT=2
# MAX_RTSP_DELAY=500000
# CONFIG_CHECK_INTERVAL=12  # Check config every 60 seconds (12 * 5s loop)
# SERVER_CHECK_INTERVAL=6   # Check server every 30 seconds (6 * 5s loop)
# STREAM_HEALTH_CHECK_INTERVAL=4 # Check stream health every 20 seconds
# MAX_CONSECUTIVE_FAILURES=3  # Restart after 3 failed health checks

# # State variables
# STREAM_PID=""
# SERVER_ENABLED=false
# NIGHT_MODE=false
# CONFIG_CHECK_COUNTER=0
# SERVER_CHECK_COUNTER=0
# STREAM_HEALTH_COUNTER=0
# CONSECUTIVE_FAILURES=0

# mkdir -p "$LOG_DIR"

# # =========================================================
# # Logging with rotation
# # =========================================================
# rotate_logs() {
#     [ -f "$LOG" ] || return
#     size=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
#     if [ "$size" -ge "$MAX_LOG_SIZE" ]; then
#         for ((i=MAX_LOG_FILES; i>=1; i--)); do
#             [ -f "$LOG.$i" ] && mv "$LOG.$i" "$LOG.$((i+1))" 2>/dev/null
#         done
#         mv "$LOG" "$LOG.1" 2>/dev/null
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
#     md5sum "$CONFIG" 2>/dev/null | cut -d' ' -f1
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
# # Config validation
# # =========================================================
# validate_config() {
#     local errors=0
    
#     # Validate numeric fields
#     [[ "$WIDTH" =~ ^[0-9]+$ ]] && [ "$WIDTH" -gt 0 ] || { log "❌ Invalid WIDTH: $WIDTH"; ((errors++)); }
#     [[ "$HEIGHT" =~ ^[0-9]+$ ]] && [ "$HEIGHT" -gt 0 ] || { log "❌ Invalid HEIGHT: $HEIGHT"; ((errors++)); }
#     [[ "$FPS" =~ ^[0-9]+$ ]] && [ "$FPS" -gt 0 ] || { log "❌ Invalid FPS: $FPS"; ((errors++)); }
#     [[ "$BITRATE" =~ ^[0-9]+$ ]] && [ "$BITRATE" -gt 0 ] || { log "❌ Invalid BITRATE: $BITRATE"; ((errors++)); }
#     [[ "$SUB_WIDTH" =~ ^[0-9]+$ ]] && [ "$SUB_WIDTH" -gt 0 ] || { log "❌ Invalid SUB_WIDTH: $SUB_WIDTH"; ((errors++)); }
#     [[ "$SUB_HEIGHT" =~ ^[0-9]+$ ]] && [ "$SUB_HEIGHT" -gt 0 ] || { log "❌ Invalid SUB_HEIGHT: $SUB_HEIGHT"; ((errors++)); }
#     [[ "$SUB_FPS" =~ ^[0-9]+$ ]] && [ "$SUB_FPS" -gt 0 ] || { log "❌ Invalid SUB_FPS: $SUB_FPS"; ((errors++)); }
#     [[ "$SUB_BITRATE" =~ ^[0-9]+$ ]] && [ "$SUB_BITRATE" -gt 0 ] || { log "❌ Invalid SUB_BITRATE: $SUB_BITRATE"; ((errors++)); }
#     [[ "$GOP" =~ ^[0-9]+$ ]] && [ "$GOP" -gt 0 ] || { log "❌ Invalid GOP: $GOP"; ((errors++)); }
    
#     # Validate string fields
#     [[ -n "$STREAM_NAME" ]] && [[ "$STREAM_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] || { log "❌ Invalid STREAM_NAME: $STREAM_NAME"; ((errors++)); }
#     [[ -n "$RTSP_USER" ]] || { log "❌ Empty RTSP_USER"; ((errors++)); }
#     [[ -n "$RTSP_PASS" ]] || { log "❌ Empty RTSP_PASS"; ((errors++)); }
#     [[ -n "$SERVER_IP" ]] || { log "❌ Empty SERVER_IP"; ((errors++)); }
    
#     # Validate profile
#     [[ "$PROFILE" =~ ^(baseline|main|high)$ ]] || { log "❌ Invalid PROFILE: $PROFILE (must be baseline/main/high)"; ((errors++)); }
    
#     # Validate autofocus mode
#     [[ "$AF_MODE" =~ ^(auto|manual|continuous)$ ]] || { log "❌ Invalid AF_MODE: $AF_MODE"; ((errors++)); }
    
#     if [ $errors -gt 0 ]; then
#         log "❌ Config validation failed with $errors errors"
#         return 1
#     fi
    
#     log "✅ Config validation passed"
#     return 0
# }

# # =========================================================
# # Load config.json
# # =========================================================
# load_config() {
#     LOCAL_IP=$(hostname -I | awk '{print $1}')
    
#     if [ -z "$LOCAL_IP" ]; then
#         log "❌ Cannot determine local IP address"
#         return 1
#     fi

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

#     BRIGHTNESS=$(jq -r '.camera.brightness // 0' "$CONFIG")
#     CONTRAST=$(jq -r '.camera.contrast // 1.0' "$CONFIG")
#     SATURATION=$(jq -r '.camera.saturation // 1.0' "$CONFIG")
#     SHARPNESS=$(jq -r '.camera.sharpness // 1.0' "$CONFIG")
#     AF_MODE=$(jq -r '.camera.autofocus_mode // "continuous"' "$CONFIG")
#     LENS=$(jq -r '.camera.lens_position // 0.0' "$CONFIG")

#     GOP=$(jq -r '.camera.gop // 50' "$CONFIG")
#     PROFILE=$(jq -r '.camera.profile // "main"' "$CONFIG")
#     RC_MODE=$(jq -r '.camera.rc_mode // "vbr"' "$CONFIG")
#     HDR=$(jq -r '.camera.hdr // false' "$CONFIG")

#     # Night mode config
#     NIGHT_ENABLED=$(jq -r '.night.enabled // false' "$CONFIG")
#     NIGHT_THRESHOLD=$(jq -r '.night.threshold // 0.18' "$CONFIG")
#     NIGHT_HYSTERESIS=$(jq -r '.night.hysteresis // 0.05' "$CONFIG")

#     # Validate configuration
#     validate_config || return 1

#     # RTSP URLs (redacted for logging)
#     LOCAL_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Main"
#     LOCAL_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Sub"

#     SERVER_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Main"
#     SERVER_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Sub"

#     # Export RTSP info for ONVIF
#     export ONVIF_RTSP_PORT="${LOCAL_RTSP_PORT}"
#     export ONVIF_STREAM_NAME="${STREAM_NAME}"
#     export ONVIF_RTSP_MAIN_PATH="${STREAM_NAME}/Main"
#     export ONVIF_RTSP_SUB_PATH="${STREAM_NAME}/Sub"
#     export ONVIF_RTSP_USER="${RTSP_USER}"
#     export ONVIF_RTSP_PASS="${RTSP_PASS}"
    
#     return 0
# }

# # =========================================================
# # Check if server is reachable (with timeout)
# # =========================================================
# server_available() {
#     timeout "$SERVER_CHECK_TIMEOUT" nc -z "$SERVER_IP" "$RTSP_PORT" 2>/dev/null
#     return $?
# }

# # =========================================================
# # Night detection helpers
# # =========================================================
# get_luma() {
#     local luma
#     luma=$(rpicam-still -n -t 50 --width 320 --height 240 -o - 2>/dev/null | \
#            ffmpeg -hide_banner -loglevel fatal -i pipe:0 \
#            -vf "signalstats" -frames:v 1 -f null - 2>&1 | \
#            awk -F'YAVG:' '{print $2}' | awk '{print $1/255}')
    
#     if [[ -z "$luma" ]]; then
#         return 1
#     fi
#     echo "$luma"
#     return 0
# }

# apply_day_settings() {
#     log "☀️ DAY MODE (forced)"
#     rpicam-ctl set exposure normal 2>/dev/null 
#     rpicam-ctl set analoggain 1 2>/dev/null 
#     rpicam-ctl set shutter 0 2>/dev/null 
#     rpicam-ctl set awb auto 2>/dev/null 
# }

# apply_night_settings() {
#     log "🌙 NIGHT MODE (auto)"
#     rpicam-ctl set exposure long 2>/dev/null 
#     rpicam-ctl set analoggain 6 2>/dev/null 
#     rpicam-ctl set shutter 100000 2>/dev/null 
#     rpicam-ctl set awb greyworld 2>/dev/null 
# }

# # =========================================================
# # Stream health check
# # =========================================================
# check_stream_health() {
#     # Check if process is running
#     if [ -z "$STREAM_PID" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then
#         return 1
#     fi
    
#     # Check if rpicam-vid is actually running
#     if ! pgrep -f "rpicam-vid" > /dev/null; then
#         log "⚠️ rpicam-vid process not found"
#         return 1
#     fi
    
#     # Check if ffmpeg processes are running
#     local ffmpeg_count=$(pgrep -f "ffmpeg.*${STREAM_NAME}" | wc -l)
#     if [ "$ffmpeg_count" -eq 0 ]; then
#         log "⚠️ No ffmpeg processes found for stream"
#         return 1
#     fi
    
#     return 0
# }

# # =========================================================
# # Cleanup function
# # =========================================================
# cleanup_streams() {
#     if [ -n "$STREAM_PID" ]; then
#         log "🛑 Stopping stream processes (PID: $STREAM_PID)"
#         # Kill entire process group
#         kill -TERM -$STREAM_PID 2>/dev/null || kill -TERM $STREAM_PID 2>/dev/null
#         sleep 2
#         # Force kill if still running
#         kill -9 -$STREAM_PID 2>/dev/null || kill -9 $STREAM_PID 2>/dev/null
#         wait $STREAM_PID 2>/dev/null
#     fi
    
#     # Kill any orphaned processes
#     if pgrep -f "ffmpeg.*${STREAM_NAME}" > /dev/null; then
#         log "🧹 Cleaning up orphaned ffmpeg processes"
#         pkill -9 -f "ffmpeg.*${STREAM_NAME}" 2>/dev/null
#         sleep 1
#     fi
    
#     if pgrep -f "rpicam-vid" > /dev/null; then
#         log "🧹 Cleaning up orphaned rpicam-vid processes"
#         pkill -9 -f "rpicam-vid" 2>/dev/null
#         sleep 1
#     fi
    
#     STREAM_PID=""
#     CONSECUTIVE_FAILURES=0
# }

# # =========================================================
# # Wait for local MediaMTX
# # =========================================================
# wait_for_local_mediamtx() {
#     local retries=0
#     local max_retries=30
    
#     while ! nc -z "$LOCAL_IP" "$LOCAL_RTSP_PORT" 2>/dev/null; do
#         if [ $retries -ge $max_retries ]; then
#             log "❌ Local MediaMTX not available after ${max_retries} attempts"
#             return 1
#         fi
#         log "⏳ Waiting for local MediaMTX on ${LOCAL_IP}:${LOCAL_RTSP_PORT}... (attempt $((retries+1))/${max_retries})"
#         sleep 2
#         ((retries++))
#     done
    
#     log "✅ Local MediaMTX is ready"
#     return 0
# }

# # =========================================================
# # Check camera availability
# # =========================================================
# check_camera() {
#     if rpicam-hello -t 100 --nopreview &>/dev/null; then
#         return 0
#     else
#         log "❌ Camera not available or in use"
#         return 1
#     fi
# }

# # =========================================================
# # Start streaming pipeline
# # =========================================================
# start_streaming() {
#     log "▶️ Starting camera capture and streaming pipeline..."
    
#     # Build rpicam-vid command
#     CMD=(
#         rpicam-vid
#         --timeout 0
#         --nopreview
#         --inline
#         --flush
#         --codec h264
#         --width "$WIDTH"
#         --height "$HEIGHT"
#         --framerate "$FPS"
#         --bitrate "$BITRATE"
#         --intra "$GOP"
#         --profile "$PROFILE"
#         --level 4.2
#         --brightness "$BRIGHTNESS"
#         --contrast "$CONTRAST"
#         --saturation "$SATURATION"
#         --sharpness "$SHARPNESS"
#         --autofocus-mode "$AF_MODE"
#         --denoise cdn_fast
#         -o -
#     )

#     [ "$AF_MODE" = "manual" ] && CMD+=(--lens-position "$LENS")

#     if [ "$HDR" = "true" ]; then
#         CMD+=(--hdr)
#         log "🌈 HDR enabled"
#     fi

#     # Build streaming pipeline based on server availability
#     if [ "$SERVER_ENABLED" = true ]; then
#         # Dual stream: local + server
#         (
#         set -m  # Enable job control to create process group
        
#         "${CMD[@]}" 2>/dev/null | tee \
#             >( ffmpeg -hide_banner -loglevel error \
#                 -fflags +genpts+discardcorrupt \
#                 -flags low_delay \
#                 -f h264 -i pipe:0 \
#                 -c:v copy \
#                 -flags:v +global_header \
#                 -bsf:v dump_extra \
#                 -f rtsp -rtsp_transport tcp \
#                 -max_delay "$MAX_RTSP_DELAY" \
#                 "${LOCAL_MAIN_RTSP_URL}" 2>&1 | \
#                 grep -v "frame duplication" | \
#                 while IFS= read -r line; do log "FFmpeg(local-main): $line"; done & ) \
#             >( ffmpeg -hide_banner -loglevel error \
#                 -fflags +genpts+discardcorrupt \
#                 -flags low_delay \
#                 -f h264 -i pipe:0 \
#                 -c:v copy \
#                 -flags:v +global_header \
#                 -bsf:v dump_extra \
#                 -f rtsp -rtsp_transport tcp \
#                 -max_delay "$MAX_RTSP_DELAY" \
#                 "${SERVER_MAIN_RTSP_URL}" 2>&1 | \
#                 grep -v "frame duplication\|Broken pipe\|Connection refused" | \
#                 while IFS= read -r line; do log "FFmpeg(server-main): $line"; done & ) | \
#         ffmpeg -hide_banner -loglevel error \
#             -fflags +genpts+discardcorrupt \
#             -flags low_delay \
#             -f h264 -i pipe:0 \
#             -vf "scale=${SUB_WIDTH}:${SUB_HEIGHT}:flags=fast_bilinear" \
#             -c:v libx264 -preset ultrafast -tune zerolatency \
#             -b:v ${SUB_BITRATE} -maxrate ${SUB_BITRATE} -bufsize $((SUB_BITRATE)) \
#             -r ${SUB_FPS} -g ${SUB_FPS} -pix_fmt yuv420p \
#             -flags:v +global_header \
#             -bsf:v dump_extra \
#             -threads 2 \
#             -f tee -map 0:v \
#             "[f=rtsp:rtsp_transport=tcp]${LOCAL_SUB_RTSP_URL}|[f=rtsp:rtsp_transport=tcp:onfail=ignore]${SERVER_SUB_RTSP_URL}" \
#             2>&1 | \
#             grep -v "frame duplication\|Broken pipe\|Connection refused" | \
#             while IFS= read -r line; do log "FFmpeg(sub): $line"; done
#         ) &
#         log "✅ Streaming to LOCAL + SERVER (CPU optimized)"
#     else
#         # Local only stream
#         (
#         set -m  # Enable job control to create process group
        
#         "${CMD[@]}" 2>/dev/null | \
#         tee >( \
#             ffmpeg -hide_banner -loglevel error \
#                 -fflags +genpts+discardcorrupt \
#                 -flags low_delay \
#                 -f h264 -i pipe:0 \
#                 -c:v copy \
#                 -flags:v +global_header \
#                 -bsf:v dump_extra \
#                 -f rtsp -rtsp_transport tcp \
#                 -max_delay "$MAX_RTSP_DELAY" \
#                 "${LOCAL_MAIN_RTSP_URL}" 2>&1 | \
#                 grep -v "frame duplication" | \
#                 while IFS= read -r line; do log "FFmpeg(local-main): $line"; done \
#         ) | \
#         ffmpeg -hide_banner -loglevel error \
#             -fflags +genpts+discardcorrupt \
#             -flags low_delay \
#             -f h264 -i pipe:0 \
#             -vf "scale=${SUB_WIDTH}:${SUB_HEIGHT}:flags=fast_bilinear" \
#             -c:v libx264 -preset ultrafast -tune zerolatency \
#             -b:v ${SUB_BITRATE} -maxrate ${SUB_BITRATE} -bufsize $((SUB_BITRATE)) \
#             -r ${SUB_FPS} -g ${SUB_FPS} \
#             -pix_fmt yuv420p \
#             -flags:v +global_header \
#             -bsf:v dump_extra \
#             -threads 2 \
#             -f rtsp -rtsp_transport tcp \
#             -max_delay "$MAX_RTSP_DELAY" \
#             "${LOCAL_SUB_RTSP_URL}" 2>&1 | \
#             grep -v "frame duplication" | \
#             while IFS= read -r line; do log "FFmpeg(local-sub): $line"; done
#         ) &
#         log "✅ Streaming to LOCAL ONLY (server unavailable)"
#     fi

#     STREAM_PID=$!
#     log "✅ Streaming started (PID: $STREAM_PID)"
#     log "   📹 Main: Hardware H.264 → RTSP copy (zero CPU)"
#     log "   📹 Sub: Single encoder → split to local + server"
#     log "   ⚙️  Main: ${WIDTH}x${HEIGHT} @ ${FPS}fps, ${BITRATE}bps"
#     log "   ⚙️  Sub: ${SUB_WIDTH}x${SUB_HEIGHT} @ ${SUB_FPS}fps, ${SUB_BITRATE}bps"
#     log "   ⚡ Server mode: $SERVER_ENABLED"
# }

# # =========================================================
# # Startup checks
# # =========================================================
# if [ ! -f "$CONFIG" ]; then
#     echo "❌ Config not found: $CONFIG"
#     exit 1
# fi

# # Set up signal handlers
# trap cleanup_streams EXIT INT TERM

# # Initial config load
# if ! load_config; then
#     log "❌ Failed to load configuration"
#     exit 1
# fi

# # Check camera availability
# if ! check_camera; then
#     log "❌ Camera check failed at startup"
#     exit 1
# fi

# # Apply initial day settings
# if [ "$NIGHT_ENABLED" = "true" ]; then
#     apply_day_settings
# else
#     NIGHT_MODE=false
#     apply_day_settings
# fi

# # Wait for local MediaMTX
# if ! wait_for_local_mediamtx; then
#     log "❌ Local MediaMTX unavailable"
#     exit 1
# fi

# # Check initial server availability
# if server_available; then
#     log "✅ Server MediaMTX available at ${SERVER_IP}:${RTSP_PORT}"
#     SERVER_ENABLED=true
# else
#     log "⚠️ Server MediaMTX unreachable - will stream LOCAL ONLY"
#     SERVER_ENABLED=false
# fi

# log "================================================"
# log "🎥 Raspberry Pi Main + Sub Streaming Started"
# log "📡 Local  Main : rtsp://${RTSP_USER}:****@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Main"
# log "📡 Local  Sub  : rtsp://${RTSP_USER}:****@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Sub"
# log "🌐 Server Main: rtsp://${RTSP_USER}:****@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Main"
# log "🌐 Server Sub : rtsp://${RTSP_USER}:****@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Sub"
# log "================================================"

# # =========================================================
# # Main loop
# # =========================================================
# while true; do

#     # -------------------------------------------------------------------------
#     # Config change detection (every 60 seconds)
#     # -------------------------------------------------------------------------
#     if [ $((CONFIG_CHECK_COUNTER % CONFIG_CHECK_INTERVAL)) -eq 0 ]; then
#         if config_changed; then
#             log "🔄 Config changed – reloading and restarting stream"
#             cleanup_streams
#             if load_config; then
#                 # Recheck server after config change
#                 if server_available; then
#                     SERVER_ENABLED=true
#                 else
#                     SERVER_ENABLED=false
#                 fi
#             else
#                 log "❌ Failed to reload config, keeping previous settings"
#             fi
#         fi
#     fi
#     ((CONFIG_CHECK_COUNTER++))

#     # -------------------------------------------------------------------------
#     # Night mode detection (if enabled)
#     # -------------------------------------------------------------------------
#     if [ "$NIGHT_ENABLED" = "true" ]; then
#         LUMA=$(get_luma)
        
#         if [ $? -eq 0 ] && [ -n "$LUMA" ]; then
#             if [ "$NIGHT_MODE" = false ] && \
#                awk "BEGIN{exit !($LUMA < ($NIGHT_THRESHOLD - $NIGHT_HYSTERESIS))}"; then
#                 NIGHT_MODE=true
#                 apply_night_settings
#                 log "🌙 Auto Night enabled (Luma=$LUMA)"
#             fi

#             if [ "$NIGHT_MODE" = true ] && \
#                awk "BEGIN{exit !($LUMA > ($NIGHT_THRESHOLD + $NIGHT_HYSTERESIS))}"; then
#                 NIGHT_MODE=false
#                 apply_day_settings
#                 log "☀️ Auto Day enabled (Luma=$LUMA)"
#             fi
#         fi
#     else
#         # Manual day mode
#         if [ "$NIGHT_MODE" = true ]; then
#             NIGHT_MODE=false
#             apply_day_settings
#             log "☀️ Manual DAY selected by user"
#         fi
#     fi

#     # -------------------------------------------------------------------------
#     # Server availability check (every 30 seconds)
#     # -------------------------------------------------------------------------
#     if [ $((SERVER_CHECK_COUNTER % SERVER_CHECK_INTERVAL)) -eq 0 ]; then
#         CURRENT_SERVER_STATUS=$SERVER_ENABLED
        
#         if server_available; then
#             NEW_SERVER_STATUS=true
#         else
#             NEW_SERVER_STATUS=false
#         fi
        
#         # If server status changed, restart stream
#         if [ "$CURRENT_SERVER_STATUS" != "$NEW_SERVER_STATUS" ]; then
#             SERVER_ENABLED=$NEW_SERVER_STATUS
#             if [ "$NEW_SERVER_STATUS" = true ]; then
#                 log "🔄 Server became available – switching to dual-stream mode"
#             else
#                 log "🔄 Server became unavailable – switching to local-only mode"
#             fi
#             cleanup_streams
#         fi
#     fi
#     ((SERVER_CHECK_COUNTER++))

#     # -------------------------------------------------------------------------
#     # Stream health check (every 20 seconds)
#     # -------------------------------------------------------------------------
#     if [ -n "$STREAM_PID" ] && [ $((STREAM_HEALTH_COUNTER % STREAM_HEALTH_CHECK_INTERVAL)) -eq 0 ]; then
#         if ! check_stream_health; then
#             ((CONSECUTIVE_FAILURES++))
#             log "⚠️ Stream health check failed ($CONSECUTIVE_FAILURES/$MAX_CONSECUTIVE_FAILURES)"
            
#             if [ $CONSECUTIVE_FAILURES -ge $MAX_CONSECUTIVE_FAILURES ]; then
#                 log "❌ Stream unhealthy after $MAX_CONSECUTIVE_FAILURES checks – forcing restart"
#                 cleanup_streams
#                 CONSECUTIVE_FAILURES=0
#             fi
#         else
#             if [ $CONSECUTIVE_FAILURES -gt 0 ]; then
#                 log "✅ Stream health recovered"
#             fi
#             CONSECUTIVE_FAILURES=0
#         fi
#     fi
#     ((STREAM_HEALTH_COUNTER++))

#     # -------------------------------------------------------------------------
#     # Start/restart stream if needed
#     # -------------------------------------------------------------------------
#     if [ -z "$STREAM_PID" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then

#         if [ -n "$STREAM_PID" ]; then
#             log "⚠️ Stream process died, restarting..."
#             cleanup_streams
#         fi

#         # Ensure local MediaMTX is available
#         if ! wait_for_local_mediamtx; then
#             log "❌ Cannot start stream - local MediaMTX unavailable"
#             sleep 5
#             continue
#         fi

#         # Recheck camera
#         if ! check_camera; then
#             log "❌ Camera unavailable - waiting before retry"
#             sleep 5
#             continue
#         fi

#         # Recheck server availability before starting
#         if server_available; then
#             if [ "$SERVER_ENABLED" = false ]; then
#                 log "✅ Server MediaMTX became available"
#                 SERVER_ENABLED=true
#             fi
#         else
#             if [ "$SERVER_ENABLED" = true ]; then
#                 log "⚠️ Server MediaMTX became unavailable"
#                 SERVER_ENABLED=false
#             fi
#         fi

#         # Start the streaming pipeline
#         start_streaming
        
#         # Give the stream time to initialize
#         sleep 3
        
#         # Verify stream started successfully
#         if ! check_stream_health; then
#             log "❌ Stream failed to start properly - will retry"
#             cleanup_streams
#         fi
#     fi

#     sleep 5
# done




#!/bin/bash

# =========================================================
# Raspberry Pi Camera → Local + Server MediaMTX
# Main / Sub RTSP Streaming (CPU OPTIMIZED)
# Enhanced with automatic reconnection and error recovery
# Time-based day/night mode switching (7 AM - 7 PM)
# =========================================================

CONFIG="/home/pi/ipcam/backend/config.json"
LOG_DIR="/home/pi/ipcam/stream/logs"
LOG="$LOG_DIR/stream.log"
CONFIG_CHECKSUM_FILE="/tmp/stream_config_checksum"

# Constants
MAX_LOG_SIZE=$((5 * 1024 * 1024))
MAX_LOG_FILES=5
LOCAL_RTSP_PORT=8554
SERVER_CHECK_TIMEOUT=2
MAX_RTSP_DELAY=500000
RTSP_TIMEOUT=5000000  # 5 seconds timeout for RTSP connections (in microseconds)
CONFIG_CHECK_INTERVAL=12  # Check config every 60 seconds (12 * 5s loop)
SERVER_CHECK_INTERVAL=6   # Check server every 30 seconds (6 * 5s loop)
STREAM_HEALTH_CHECK_INTERVAL=4  # Check stream health every 20 seconds
MAX_CONSECUTIVE_FAILURES=3  # Restart after 3 failed health checks
TIME_CHECK_INTERVAL=12  # Check time every 60 seconds for day/night switching

# State variables
STREAM_PID=""
SERVER_ENABLED=false
NIGHT_MODE=false
CONFIG_CHECK_COUNTER=0
SERVER_CHECK_COUNTER=0
STREAM_HEALTH_COUNTER=0
CONSECUTIVE_FAILURES=0
TIME_CHECK_COUNTER=0

mkdir -p "$LOG_DIR"

# =========================================================
# Logging with rotation
# =========================================================
rotate_logs() {
    [ -f "$LOG" ] || return
    size=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
    if [ "$size" -ge "$MAX_LOG_SIZE" ]; then
        for ((i=MAX_LOG_FILES; i>=1; i--)); do
            [ -f "$LOG.$i" ] && mv "$LOG.$i" "$LOG.$((i+1))" 2>/dev/null
        done
        mv "$LOG" "$LOG.1" 2>/dev/null
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
    md5sum "$CONFIG" 2>/dev/null | cut -d' ' -f1
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
# Config validation
# =========================================================
validate_config() {
    local errors=0
    
    # Validate numeric fields
    [[ "$WIDTH" =~ ^[0-9]+$ ]] && [ "$WIDTH" -gt 0 ] || { log "❌ Invalid WIDTH: $WIDTH"; ((errors++)); }
    [[ "$HEIGHT" =~ ^[0-9]+$ ]] && [ "$HEIGHT" -gt 0 ] || { log "❌ Invalid HEIGHT: $HEIGHT"; ((errors++)); }
    [[ "$FPS" =~ ^[0-9]+$ ]] && [ "$FPS" -gt 0 ] || { log "❌ Invalid FPS: $FPS"; ((errors++)); }
    [[ "$BITRATE" =~ ^[0-9]+$ ]] && [ "$BITRATE" -gt 0 ] || { log "❌ Invalid BITRATE: $BITRATE"; ((errors++)); }
    [[ "$SUB_WIDTH" =~ ^[0-9]+$ ]] && [ "$SUB_WIDTH" -gt 0 ] || { log "❌ Invalid SUB_WIDTH: $SUB_WIDTH"; ((errors++)); }
    [[ "$SUB_HEIGHT" =~ ^[0-9]+$ ]] && [ "$SUB_HEIGHT" -gt 0 ] || { log "❌ Invalid SUB_HEIGHT: $SUB_HEIGHT"; ((errors++)); }
    [[ "$SUB_FPS" =~ ^[0-9]+$ ]] && [ "$SUB_FPS" -gt 0 ] || { log "❌ Invalid SUB_FPS: $SUB_FPS"; ((errors++)); }
    [[ "$SUB_BITRATE" =~ ^[0-9]+$ ]] && [ "$SUB_BITRATE" -gt 0 ] || { log "❌ Invalid SUB_BITRATE: $SUB_BITRATE"; ((errors++)); }
    [[ "$GOP" =~ ^[0-9]+$ ]] && [ "$GOP" -gt 0 ] || { log "❌ Invalid GOP: $GOP"; ((errors++)); }
    
    # Validate string fields
    [[ -n "$STREAM_NAME" ]] && [[ "$STREAM_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] || { log "❌ Invalid STREAM_NAME: $STREAM_NAME"; ((errors++)); }
    [[ -n "$RTSP_USER" ]] || { log "❌ Empty RTSP_USER"; ((errors++)); }
    [[ -n "$RTSP_PASS" ]] || { log "❌ Empty RTSP_PASS"; ((errors++)); }
    [[ -n "$SERVER_IP" ]] || { log "❌ Empty SERVER_IP"; ((errors++)); }
    
    # Validate profile
    [[ "$PROFILE" =~ ^(baseline|main|high)$ ]] || { log "❌ Invalid PROFILE: $PROFILE (must be baseline/main/high)"; ((errors++)); }
    
    # Validate autofocus mode
    [[ "$AF_MODE" =~ ^(auto|manual|continuous)$ ]] || { log "❌ Invalid AF_MODE: $AF_MODE"; ((errors++)); }
    
    if [ $errors -gt 0 ]; then
        log "❌ Config validation failed with $errors errors"
        return 1
    fi
    
    log "✅ Config validation passed"
    return 0
}

# =========================================================
# Load config.json
# =========================================================
load_config() {
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    if [ -z "$LOCAL_IP" ]; then
        log "❌ Cannot determine local IP address"
        return 1
    fi

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

    BRIGHTNESS=$(jq -r '.camera.brightness // 0' "$CONFIG")
    CONTRAST=$(jq -r '.camera.contrast // 1.0' "$CONFIG")
    SATURATION=$(jq -r '.camera.saturation // 1.0' "$CONFIG")
    SHARPNESS=$(jq -r '.camera.sharpness // 1.0' "$CONFIG")
    AF_MODE=$(jq -r '.camera.autofocus_mode // "continuous"' "$CONFIG")
    LENS=$(jq -r '.camera.lens_position // 0.0' "$CONFIG")

    GOP=$(jq -r '.camera.gop // 50' "$CONFIG")
    PROFILE=$(jq -r '.camera.profile // "main"' "$CONFIG")
    RC_MODE=$(jq -r '.camera.rc_mode // "vbr"' "$CONFIG")
    HDR=$(jq -r '.camera.hdr // false' "$CONFIG")

    # Night mode config (time-based)
    NIGHT_ENABLED=$(jq -r '.night.enabled // false' "$CONFIG")

    # Validate configuration
    validate_config || return 1

    # RTSP URLs (redacted for logging)
    LOCAL_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Main"
    LOCAL_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Sub"

    SERVER_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Main"
    SERVER_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Sub"

    # Export RTSP info for ONVIF
    export ONVIF_RTSP_PORT="${LOCAL_RTSP_PORT}"
    export ONVIF_STREAM_NAME="${STREAM_NAME}"
    export ONVIF_RTSP_MAIN_PATH="${STREAM_NAME}/Main"
    export ONVIF_RTSP_SUB_PATH="${STREAM_NAME}/Sub"
    export ONVIF_RTSP_USER="${RTSP_USER}"
    export ONVIF_RTSP_PASS="${RTSP_PASS}"
    
    return 0
}

# =========================================================
# Check if server is reachable (with timeout)
# =========================================================
server_available() {
    timeout "$SERVER_CHECK_TIMEOUT" nc -z "$SERVER_IP" "$RTSP_PORT" 2>/dev/null
    return $?
}

# =========================================================
# Time-based day/night detection
# =========================================================
is_daytime() {
    local current_hour=$(date +%H)
    # Daytime is from 7 AM (07) to 7 PM (19) - hour 19 means 7:00 PM to 7:59 PM
    if [ "$current_hour" -ge 7 ] && [ "$current_hour" -lt 19 ]; then
        return 0  # It's daytime
    else
        return 1  # It's nighttime
    fi
}

# Set day/night mode flags (will be applied at camera start)
set_day_mode() {
    log "☀️ Switching to DAY MODE (7 AM - 7 PM)"
    CURRENT_EXPOSURE_MODE="normal"
    CURRENT_GAIN="1.0"
    CURRENT_SHUTTER="0"  # Auto shutter
    CURRENT_AWB="auto"
}

set_night_mode() {
    log "🌙 Switching to NIGHT MODE (7 PM - 7 AM)"
    CURRENT_EXPOSURE_MODE="long"
    CURRENT_GAIN="6.0"
    CURRENT_SHUTTER="100000"  # 100ms exposure
    CURRENT_AWB="tungsten"
}

# =========================================================
# Stream health check
# =========================================================
check_stream_health() {
    # Check if process is running
    if [ -z "$STREAM_PID" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then
        return 1
    fi
    
    # Check if rpicam-vid is actually running
    if ! pgrep -f "rpicam-vid" > /dev/null; then
        log "⚠️ rpicam-vid process not found"
        return 1
    fi
    
    # Check if ffmpeg processes are running
    local ffmpeg_count=$(pgrep -f "ffmpeg.*${STREAM_NAME}" | wc -l)
    if [ "$ffmpeg_count" -eq 0 ]; then
        log "⚠️ No ffmpeg processes found for stream"
        return 1
    fi
    
    return 0
}

# =========================================================
# Cleanup function
# =========================================================
cleanup_streams() {
    if [ -n "$STREAM_PID" ]; then
        log "🛑 Stopping stream processes (PID: $STREAM_PID)"
        # Kill entire process group
        kill -TERM -$STREAM_PID 2>/dev/null || kill -TERM $STREAM_PID 2>/dev/null
        sleep 2
        # Force kill if still running
        kill -9 -$STREAM_PID 2>/dev/null || kill -9 $STREAM_PID 2>/dev/null
        wait $STREAM_PID 2>/dev/null
    fi
    
    # Kill any orphaned processes
    if pgrep -f "ffmpeg.*${STREAM_NAME}" > /dev/null; then
        log "🧹 Cleaning up orphaned ffmpeg processes"
        pkill -9 -f "ffmpeg.*${STREAM_NAME}" 2>/dev/null
        sleep 1
    fi
    
    if pgrep -f "rpicam-vid" > /dev/null; then
        log "🧹 Cleaning up orphaned rpicam-vid processes"
        pkill -9 -f "rpicam-vid" 2>/dev/null
        sleep 1
    fi
    
    STREAM_PID=""
    CONSECUTIVE_FAILURES=0
}

# =========================================================
# Wait for local MediaMTX
# =========================================================
wait_for_local_mediamtx() {
    local retries=0
    local max_retries=30
    
    while ! nc -z "$LOCAL_IP" "$LOCAL_RTSP_PORT" 2>/dev/null; do
        if [ $retries -ge $max_retries ]; then
            log "❌ Local MediaMTX not available after ${max_retries} attempts"
            return 1
        fi
        log "⏳ Waiting for local MediaMTX on ${LOCAL_IP}:${LOCAL_RTSP_PORT}... (attempt $((retries+1))/${max_retries})"
        sleep 2
        ((retries++))
    done
    
    log "✅ Local MediaMTX is ready"
    return 0
}

# =========================================================
# Check camera availability
# =========================================================
check_camera() {
    if rpicam-hello -t 100 --nopreview &>/dev/null; then
        return 0
    else
        log "❌ Camera not available or in use"
        return 1
    fi
}

# =========================================================
# Start streaming pipeline
# =========================================================
start_streaming() {
    log "▶️ Starting camera capture and streaming pipeline..."
    
    # Build rpicam-vid command
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
        --awb "$CURRENT_AWB"
        --gain "$CURRENT_GAIN"
        -o -
    )

    # Add shutter speed if not auto (0 = auto)
    if [ "$CURRENT_SHUTTER" != "0" ]; then
        CMD+=(--shutter "$CURRENT_SHUTTER")
    fi

    [ "$AF_MODE" = "manual" ] && CMD+=(--lens-position "$LENS")

    if [ "$HDR" = "true" ]; then
        CMD+=(--hdr)
        log "🌈 HDR enabled"
    fi

    # Build streaming pipeline based on server availability
    if [ "$SERVER_ENABLED" = true ]; then
        # Dual stream: local + server
        (
        set -m  # Enable job control to create process group
        
        "${CMD[@]}" 2>/dev/null | tee \
            >( ffmpeg -hide_banner -loglevel error \
                -err_detect ignore_err \
                -fflags +genpts+discardcorrupt+nobuffer \
                -flags low_delay \
                -avoid_negative_ts make_zero \
                -f h264 -i pipe:0 \
                -c:v copy \
                -flags:v +global_header \
                -bsf:v dump_extra \
                -f rtsp \
                -rtsp_transport tcp \
                -rtsp_flags prefer_tcp \
                -max_delay "$MAX_RTSP_DELAY" \
                -timeout "$RTSP_TIMEOUT" \
                "${LOCAL_MAIN_RTSP_URL}" 2>&1 | \
                grep -Ev "frame duplication|Broken pipe|Error muxing|Last message repeated|Error submitting.*muxer|Task finished with error code|Terminating thread|vost#.*Error submitting" | \
                while IFS= read -r line; do log "FFmpeg(local-main): $line"; done & ) \
            >( ffmpeg -hide_banner -loglevel error \
                -err_detect ignore_err \
                -fflags +genpts+discardcorrupt+nobuffer \
                -flags low_delay \
                -avoid_negative_ts make_zero \
                -f h264 -i pipe:0 \
                -c:v copy \
                -flags:v +global_header \
                -bsf:v dump_extra \
                -f rtsp \
                -rtsp_transport tcp \
                -rtsp_flags prefer_tcp \
                -max_delay "$MAX_RTSP_DELAY" \
                -timeout "$RTSP_TIMEOUT" \
                "${SERVER_MAIN_RTSP_URL}" 2>&1 | \
                grep -Ev "frame duplication|Broken pipe|Connection refused|Error muxing|Last message repeated|Error submitting.*muxer|Task finished with error code|Terminating thread|vost#.*Error submitting|Connection reset by peer" | \
                while IFS= read -r line; do log "FFmpeg(server-main): $line"; done & ) | \
        ffmpeg -hide_banner -loglevel error \
            -err_detect ignore_err \
            -fflags +genpts+discardcorrupt+nobuffer \
            -flags low_delay \
            -avoid_negative_ts make_zero \
            -f h264 -i pipe:0 \
            -vf "scale=${SUB_WIDTH}:${SUB_HEIGHT}:flags=fast_bilinear" \
            -c:v libx264 -preset ultrafast -tune zerolatency \
            -b:v ${SUB_BITRATE} -maxrate ${SUB_BITRATE} -bufsize $((SUB_BITRATE)) \
            -r ${SUB_FPS} -g ${SUB_FPS} -pix_fmt yuv420p \
            -flags:v +global_header \
            -bsf:v dump_extra \
            -threads 2 \
            -f tee -map 0:v \
            "[f=rtsp:rtsp_transport=tcp:rtsp_flags=prefer_tcp:timeout=${RTSP_TIMEOUT}]${LOCAL_SUB_RTSP_URL}|[f=rtsp:rtsp_transport=tcp:rtsp_flags=prefer_tcp:timeout=${RTSP_TIMEOUT}:onfail=ignore]${SERVER_SUB_RTSP_URL}" \
            2>&1 | \
            grep -Ev "frame duplication|Broken pipe|Connection refused|Error muxing|Last message repeated|Error submitting.*muxer|Task finished with error code|Terminating thread|vost#.*Error submitting|Connection reset by peer" | \
            while IFS= read -r line; do log "FFmpeg(sub): $line"; done
        ) &
        log "✅ Streaming to LOCAL + SERVER (CPU optimized with error recovery)"
    else
        # Local only stream
        (
        set -m  # Enable job control to create process group
        
        "${CMD[@]}" 2>/dev/null | \
        tee >( \
            ffmpeg -hide_banner -loglevel error \
                -err_detect ignore_err \
                -fflags +genpts+discardcorrupt+nobuffer \
                -flags low_delay \
                -avoid_negative_ts make_zero \
                -f h264 -i pipe:0 \
                -c:v copy \
                -flags:v +global_header \
                -bsf:v dump_extra \
                -f rtsp \
                -rtsp_transport tcp \
                -rtsp_flags prefer_tcp \
                -max_delay "$MAX_RTSP_DELAY" \
                -timeout "$RTSP_TIMEOUT" \
                "${LOCAL_MAIN_RTSP_URL}" 2>&1 | \
                grep -Ev "frame duplication|Broken pipe|Error muxing|Last message repeated|Error submitting.*muxer|Task finished with error code|Terminating thread|vost#.*Error submitting" | \
                while IFS= read -r line; do log "FFmpeg(local-main): $line"; done \
        ) | \
        ffmpeg -hide_banner -loglevel error \
            -err_detect ignore_err \
            -fflags +genpts+discardcorrupt+nobuffer \
            -flags low_delay \
            -avoid_negative_ts make_zero \
            -f h264 -i pipe:0 \
            -vf "scale=${SUB_WIDTH}:${SUB_HEIGHT}:flags=fast_bilinear" \
            -c:v libx264 -preset ultrafast -tune zerolatency \
            -b:v ${SUB_BITRATE} -maxrate ${SUB_BITRATE} -bufsize $((SUB_BITRATE)) \
            -r ${SUB_FPS} -g ${SUB_FPS} \
            -pix_fmt yuv420p \
            -flags:v +global_header \
            -bsf:v dump_extra \
            -threads 2 \
            -f rtsp \
            -rtsp_transport tcp \
            -rtsp_flags prefer_tcp \
            -max_delay "$MAX_RTSP_DELAY" \
            -timeout "$RTSP_TIMEOUT" \
            "${LOCAL_SUB_RTSP_URL}" 2>&1 | \
            grep -Ev "frame duplication|Broken pipe|Error muxing|Last message repeated|Error submitting.*muxer|Task finished with error code|Terminating thread|vost#.*Error submitting" | \
            while IFS= read -r line; do log "FFmpeg(local-sub): $line"; done
        ) &
        log "✅ Streaming to LOCAL ONLY (server unavailable)"
    fi

    STREAM_PID=$!
    log "✅ Streaming started (PID: $STREAM_PID)"
    log "   📹 Main: Hardware H.264 → RTSP copy (zero CPU)"
    log "   📹 Sub: Single encoder → split to local + server"
    log "   ⚙️  Main: ${WIDTH}x${HEIGHT} @ ${FPS}fps, ${BITRATE}bps"
    log "   ⚙️  Sub: ${SUB_WIDTH}x${SUB_HEIGHT} @ ${SUB_FPS}fps, ${SUB_BITRATE}bps"
    log "   ⚡ Server mode: $SERVER_ENABLED"
    log "   🌓 Exposure: ${CURRENT_EXPOSURE_MODE}, Gain: ${CURRENT_GAIN}, Shutter: ${CURRENT_SHUTTER}, AWB: ${CURRENT_AWB}"
}

# =========================================================
# Startup checks
# =========================================================
if [ ! -f "$CONFIG" ]; then
    echo "❌ Config not found: $CONFIG"
    exit 1
fi

# Set up signal handlers
trap cleanup_streams EXIT INT TERM

# Initial config load
if ! load_config; then
    log "❌ Failed to load configuration"
    exit 1
fi

# Check camera availability
if ! check_camera; then
    log "❌ Camera check failed at startup"
    exit 1
fi

# Determine initial mode based on time and night_enabled setting
if [ "$NIGHT_ENABLED" = "true" ]; then
    if is_daytime; then
        NIGHT_MODE=false
        set_day_mode
        log "🌞 Auto day/night enabled - Starting in DAY mode (7 AM - 7 PM)"
    else
        NIGHT_MODE=true
        set_night_mode
        log "🌛 Auto day/night enabled - Starting in NIGHT mode (7 PM - 7 AM)"
    fi
else
    NIGHT_MODE=false
    set_day_mode
    log "☀️ Auto day/night disabled - Using DAY mode only"
fi

# Wait for local MediaMTX
if ! wait_for_local_mediamtx; then
    log "❌ Local MediaMTX unavailable"
    exit 1
fi

# Check initial server availability
if server_available; then
    log "✅ Server MediaMTX available at ${SERVER_IP}:${RTSP_PORT}"
    SERVER_ENABLED=true
else
    log "⚠️ Server MediaMTX unreachable - will stream LOCAL ONLY"
    SERVER_ENABLED=false
fi

log "================================================"
log "🎥 Raspberry Pi Main + Sub Streaming Started"
log "📡 Local  Main : rtsp://${RTSP_USER}:****@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Main"
log "📡 Local  Sub  : rtsp://${RTSP_USER}:****@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Sub"
log "🌐 Server Main: rtsp://${RTSP_USER}:****@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Main"
log "🌐 Server Sub : rtsp://${RTSP_USER}:****@${SERVER_IP}:${RTSP_PORT}/${STREAM_NAME}/Sub"
log "🌗 Night Mode: $NIGHT_ENABLED (Time-based: 7 AM - 7 PM = Day, 7 PM - 7 AM = Night)"
log "================================================"

# =========================================================
# Main loop
# =========================================================
while true; do

    # -------------------------------------------------------------------------
    # Config change detection (every 60 seconds)
    # -------------------------------------------------------------------------
    if [ $((CONFIG_CHECK_COUNTER % CONFIG_CHECK_INTERVAL)) -eq 0 ]; then
        if config_changed; then
            log "🔄 Config changed – reloading and restarting stream"
            cleanup_streams
            if load_config; then
                # Recheck server after config change
                if server_available; then
                    SERVER_ENABLED=true
                else
                    SERVER_ENABLED=false
                fi
                
                # Reapply day/night mode after config reload
                if [ "$NIGHT_ENABLED" = "true" ]; then
                    if is_daytime; then
                        if [ "$NIGHT_MODE" = true ]; then
                            NIGHT_MODE=false
                            set_day_mode
                            log "🔄 Config reload: Switching to DAY mode"
                        fi
                    else
                        if [ "$NIGHT_MODE" = false ]; then
                            NIGHT_MODE=true
                            set_night_mode
                            log "🔄 Config reload: Switching to NIGHT mode"
                        fi
                    fi
                else
                    if [ "$NIGHT_MODE" = true ]; then
                        NIGHT_MODE=false
                        set_day_mode
                        log "🔄 Config reload: Night mode disabled, switching to DAY mode"
                    fi
                fi
            else
                log "❌ Failed to reload config, keeping previous settings"
            fi
        fi
    fi
    ((CONFIG_CHECK_COUNTER++))

    # -------------------------------------------------------------------------
    # Time-based day/night mode switching (every 60 seconds)
    # -------------------------------------------------------------------------
    if [ "$NIGHT_ENABLED" = "true" ] && [ $((TIME_CHECK_COUNTER % TIME_CHECK_INTERVAL)) -eq 0 ]; then
        if is_daytime; then
            # It's daytime (7 AM - 7 PM)
            if [ "$NIGHT_MODE" = true ]; then
                NIGHT_MODE=false
                set_day_mode
                log "☀️ Time-based switch: Now daytime (7 AM - 7 PM) – restarting stream with DAY settings"
                cleanup_streams  # Must restart to apply new camera settings
            fi
        else
            # It's nighttime (7 PM - 7 AM)
            if [ "$NIGHT_MODE" = false ]; then
                NIGHT_MODE=true
                set_night_mode
                log "🌙 Time-based switch: Now nighttime (7 PM - 7 AM) – restarting stream with NIGHT settings"
                cleanup_streams  # Must restart to apply new camera settings
            fi
        fi
    fi
    ((TIME_CHECK_COUNTER++))

    # If night mode is disabled, ensure we're always in day mode
    if [ "$NIGHT_ENABLED" = "false" ] && [ "$NIGHT_MODE" = true ]; then
        NIGHT_MODE=false
        set_day_mode
        log "☀️ Night mode disabled – forcing DAY mode"
        cleanup_streams
    fi

    # -------------------------------------------------------------------------
    # Server availability check (every 30 seconds)
    # -------------------------------------------------------------------------
    if [ $((SERVER_CHECK_COUNTER % SERVER_CHECK_INTERVAL)) -eq 0 ]; then
        CURRENT_SERVER_STATUS=$SERVER_ENABLED
        
        if server_available; then
            NEW_SERVER_STATUS=true
        else
            NEW_SERVER_STATUS=false
        fi
        
        # If server status changed, restart stream
        if [ "$CURRENT_SERVER_STATUS" != "$NEW_SERVER_STATUS" ]; then
            SERVER_ENABLED=$NEW_SERVER_STATUS
            if [ "$NEW_SERVER_STATUS" = true ]; then
                log "🔄 Server became available – switching to dual-stream mode"
            else
                log "🔄 Server became unavailable – switching to local-only mode"
            fi
            cleanup_streams
        fi
    fi
    ((SERVER_CHECK_COUNTER++))

    # -------------------------------------------------------------------------
    # Stream health check (every 20 seconds)
    # -------------------------------------------------------------------------
    if [ -n "$STREAM_PID" ] && [ $((STREAM_HEALTH_COUNTER % STREAM_HEALTH_CHECK_INTERVAL)) -eq 0 ]; then
        if ! check_stream_health; then
            ((CONSECUTIVE_FAILURES++))
            log "⚠️ Stream health check failed ($CONSECUTIVE_FAILURES/$MAX_CONSECUTIVE_FAILURES)"
            
            if [ $CONSECUTIVE_FAILURES -ge $MAX_CONSECUTIVE_FAILURES ]; then
                log "❌ Stream unhealthy after $MAX_CONSECUTIVE_FAILURES checks – forcing restart"
                cleanup_streams
                CONSECUTIVE_FAILURES=0
            fi
        else
            if [ $CONSECUTIVE_FAILURES -gt 0 ]; then
                log "✅ Stream health recovered"
            fi
            CONSECUTIVE_FAILURES=0
        fi
    fi
    ((STREAM_HEALTH_COUNTER++))

    # -------------------------------------------------------------------------
    # Start/restart stream if needed
    # -------------------------------------------------------------------------
    if [ -z "$STREAM_PID" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then

        if [ -n "$STREAM_PID" ]; then
            log "⚠️ Stream process died, restarting..."
            cleanup_streams
        fi

        # Ensure local MediaMTX is available
        if ! wait_for_local_mediamtx; then
            log "❌ Cannot start stream - local MediaMTX unavailable"
            sleep 5
            continue
        fi

        # Recheck camera
        if ! check_camera; then
            log "❌ Camera unavailable - waiting before retry"
            sleep 5
            continue
        fi

        # Recheck server availability before starting
        if server_available; then
            if [ "$SERVER_ENABLED" = false ]; then
                log "✅ Server MediaMTX became available"
                SERVER_ENABLED=true
            fi
        else
            if [ "$SERVER_ENABLED" = true ]; then
                log "⚠️ Server MediaMTX became unavailable"
                SERVER_ENABLED=false
            fi
        fi

        # Start the streaming pipeline
        start_streaming
        
        # Give the stream time to initialize
        sleep 3
        
        # Verify stream started successfully
        if ! check_stream_health; then
            log "❌ Stream failed to start properly - will retry"
            cleanup_streams
        fi
    fi

    sleep 5
done
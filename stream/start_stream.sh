#!/bin/bash

# =========================================================
# Raspberry Pi Camera → Local MediaMTX
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
MAX_RTSP_DELAY=500000
RTSP_TIMEOUT=5000000  # 5 seconds timeout for RTSP connections (in microseconds)
CONFIG_CHECK_INTERVAL=12  # Check config every 60 seconds (12 * 5s loop)
STREAM_HEALTH_CHECK_INTERVAL=4  # Check stream health every 20 seconds
MAX_CONSECUTIVE_FAILURES=3  # Restart after 3 failed health checks
TIME_CHECK_INTERVAL=12  # Check time every 60 seconds for day/night switching

# State variables
STREAM_PID=""
NIGHT_MODE=false
CONFIG_CHECK_COUNTER=0
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

    # Local RTSP URLs
    LOCAL_MAIN_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Main"
    LOCAL_SUB_RTSP_URL="rtsp://${RTSP_USER}:${RTSP_PASS}@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Sub"

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
# Time-based day/night detection
# =========================================================
is_daytime() {
    local current_hour=$(date +%H)
    # Daytime is from 7 AM (07) to 7 PM (19)
    if [ "$current_hour" -ge 7 ] && [ "$current_hour" -lt 19 ]; then
        return 0  # It's daytime
    else
        return 1  # It's nighttime
    fi
}

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
        kill -TERM -$STREAM_PID 2>/dev/null || kill -TERM $STREAM_PID 2>/dev/null
        sleep 2
        kill -9 -$STREAM_PID 2>/dev/null || kill -9 $STREAM_PID 2>/dev/null
        wait $STREAM_PID 2>/dev/null
    fi

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
# Start streaming pipeline (local only)
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

    # Local-only streaming pipeline
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

    STREAM_PID=$!
    log "✅ Streaming started (PID: $STREAM_PID)"
    log "   📹 Main: Hardware H.264 → RTSP copy (zero CPU)"
    log "   📹 Sub: Software H.264 encode → local RTSP"
    log "   ⚙️  Main: ${WIDTH}x${HEIGHT} @ ${FPS}fps, ${BITRATE}bps"
    log "   ⚙️  Sub: ${SUB_WIDTH}x${SUB_HEIGHT} @ ${SUB_FPS}fps, ${SUB_BITRATE}bps"
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

log "================================================"
log "🎥 Raspberry Pi Main + Sub Streaming Started"
log "📡 Local Main : rtsp://${RTSP_USER}:****@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Main"
log "📡 Local Sub  : rtsp://${RTSP_USER}:****@${LOCAL_IP}:${LOCAL_RTSP_PORT}/${STREAM_NAME}/Sub"
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
            if [ "$NIGHT_MODE" = true ]; then
                NIGHT_MODE=false
                set_day_mode
                log "☀️ Time-based switch: Now daytime (7 AM - 7 PM) – restarting stream with DAY settings"
                cleanup_streams
            fi
        else
            if [ "$NIGHT_MODE" = false ]; then
                NIGHT_MODE=true
                set_night_mode
                log "🌙 Time-based switch: Now nighttime (7 PM - 7 AM) – restarting stream with NIGHT settings"
                cleanup_streams
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
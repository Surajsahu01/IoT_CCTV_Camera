// Global notification function
function showNotification(message, type = 'success') {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'slideIn 0.3s ease-out reverse';
        setTimeout(() => {
            document.body.removeChild(notification);
        }, 300);
    }, 3000);
}

// Highlight active navigation link
document.addEventListener('DOMContentLoaded', function() {
    const currentPath = window.location.pathname;
    const navLinks = document.querySelectorAll('.nav-link');
    
    navLinks.forEach(link => {
        if (link.getAttribute('href') === currentPath) {
            link.style.background = '#334155';
            link.style.color = '#fff';
        }
    });
});

// Auto-hide status messages
function autoHideStatus(elementId, delay = 5000) {
    const element = document.getElementById(elementId);
    if (element && element.textContent.trim() !== '') {
        setTimeout(() => {
            element.style.opacity = '0';
            setTimeout(() => {
                element.textContent = '';
                element.style.opacity = '1';
            }, 500);
        }, delay);
    }
}

// Format bytes to human readable
function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

// Validate IP address
function isValidIP(ip) {
    const pattern = /^(\d{1,3}\.){3}\d{1,3}$/;
    if (!pattern.test(ip)) return false;
    
    const parts = ip.split('.');
    return parts.every(part => {
        const num = parseInt(part, 10);
        return num >= 0 && num <= 255;
    });
}

// Copy to clipboard
function copyToClipboard(text) {
    if (navigator.clipboard) {
        navigator.clipboard.writeText(text).then(() => {
            showNotification('Copied to clipboard!', 'success');
        }).catch(() => {
            fallbackCopy(text);
        });
    } else {
        fallbackCopy(text);
    }
}

function fallbackCopy(text) {
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    try {
        document.execCommand('copy');
        showNotification('Copied to clipboard!', 'success');
    } catch (err) {
        showNotification('Failed to copy', 'error');
    }
    document.body.removeChild(textarea);
}

// Add copy buttons to RTSP URLs
document.addEventListener('DOMContentLoaded', function() {
    const rtspElements = document.querySelectorAll('[id*="rtsp"], [id*="Url"]');
    rtspElements.forEach(el => {
        if (el.textContent && el.textContent.includes('rtsp://')) {
            el.style.cursor = 'pointer';
            el.title = 'Click to copy';
            el.onclick = () => copyToClipboard(el.textContent);
        }
    });
});

// Check connection status periodically
let connectionCheckInterval;

function startConnectionCheck() {
    connectionCheckInterval = setInterval(() => {
        fetch('/api/stream/status')
            .then(response => {
                if (!response.ok) {
                    updateConnectionStatus(false);
                } else {
                    updateConnectionStatus(true);
                }
            })
            .catch(() => {
                updateConnectionStatus(false);
            });
    }, 10000); // Check every 10 seconds
}

function updateConnectionStatus(isConnected) {
    const statusIndicator = document.querySelector('.status-dot');
    const statusText = document.querySelector('.status-text');
    
    if (statusIndicator && statusText) {
        if (isConnected) {
            statusIndicator.style.background = '#22c55e';
            statusText.textContent = 'Connected';
        } else {
            statusIndicator.style.background = '#ef4444';
            statusText.textContent = 'Disconnected';
        }
    }
}

// Start connection check on load
if (document.querySelector('.status-dot')) {
    startConnectionCheck();
}

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    if (connectionCheckInterval) {
        clearInterval(connectionCheckInterval);
    }
});

// Form validation helper
function validateForm(formId) {
    const form = document.getElementById(formId);
    if (!form) return false;
    
    const inputs = form.querySelectorAll('input[required], select[required]');
    let isValid = true;
    
    inputs.forEach(input => {
        if (!input.value.trim()) {
            input.style.borderColor = '#ef4444';
            isValid = false;
        } else {
            input.style.borderColor = '#334155';
        }
    });
    
    return isValid;
}

// Add input listeners to clear error state
document.addEventListener('DOMContentLoaded', function() {
    const inputs = document.querySelectorAll('input[required], select[required]');
    inputs.forEach(input => {
        input.addEventListener('input', () => {
            if (input.value.trim()) {
                input.style.borderColor = '#334155';
            }
        });
    });
});

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
    // Ctrl/Cmd + R: Refresh page data
    if ((e.ctrlKey || e.metaKey) && e.key === 'r') {
        e.preventDefault();
        location.reload();
    }
    
    // Ctrl/Cmd + S: Save (if on settings page)
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault();
        const submitBtn = document.querySelector('form button[type="submit"]');
        if (submitBtn) {
            submitBtn.click();
        }
    }
});

// Loading spinner
function showLoader() {
    const loader = document.createElement('div');
    loader.id = 'loader';
    loader.style.cssText = `
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        width: 50px;
        height: 50px;
        border: 4px solid #334155;
        border-top-color: #60a5fa;
        border-radius: 50%;
        animation: spin 1s linear infinite;
        z-index: 9999;
    `;
    document.body.appendChild(loader);
}

function hideLoader() {
    const loader = document.getElementById('loader');
    if (loader) {
        document.body.removeChild(loader);
    }
}

// Add spin animation
const style = document.createElement('style');
style.textContent = `
    @keyframes spin {
        to { transform: translate(-50%, -50%) rotate(360deg); }
    }
`;
document.head.appendChild(style);

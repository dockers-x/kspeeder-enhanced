# Enhanced KSpeeder image with Caddy reverse proxy
# Solves hardcoded domain issue, supports access via any IP/domain
FROM linkease/kspeeder:latest

LABEL maintainer="czytcn@gmail.com"
LABEL description="KSpeeder with Caddy reverse proxy for any domain/IP access"

# Install Caddy
RUN apk add --no-cache caddy

# Create Caddy configuration file
RUN cat > /etc/caddy/Caddyfile << 'EOF'
# HTTP and HTTPS proxy ports - Supports any domain/IP access
:80, :443 {
    # Health check endpoint
    handle /health {
        header Content-Type "text/plain"
        respond "KSpeeder with Caddy Proxy - Healthy" 200
    }
    
    # Docker Registry API proxy
    handle {
        # Critical: Rewrite Host header to the domain expected by KSpeeder
        header_up Host registry.linkease.net
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Original-Host {host}
        
        # Reverse proxy to local KSpeeder on port 5443
        reverse_proxy https://127.0.0.1:5443 {
            transport http {
                tls_insecure_skip_verify
            }
        }
    }
    
    # Auto HTTPS (using internal CA certificate)
    tls internal
}
EOF

# Create startup script
RUN cat > /start.sh << 'EOF'
#!/bin/sh
echo "=========================================="
echo "Starting KSpeeder + Caddy Proxy"
echo "=========================================="
echo "Ports:"
echo "  80/443  - HTTP/HTTPS Proxy (Any domain/IP)"
echo "  5443    - Original KSpeeder HTTPS"
echo "  5003    - Management Interface"
echo "=========================================="

# Start KSpeeder in background
echo "Starting KSpeeder..."
/entrypoint.sh &
KSPEEDER_PID=$!

# Wait a bit for KSpeeder to initialize
sleep 10

# Start Caddy in foreground (this keeps the container running)
echo "Starting Caddy proxy..."
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
EOF

RUN chmod +x /start.sh

# Expose ports
# New proxy ports
EXPOSE 80
EXPOSE 443
# Keep original ports unchanged  
EXPOSE 5443
EXPOSE 5003

# Entrypoint
CMD ["/start.sh"]

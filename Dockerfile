# Enhanced KSpeeder image with Caddy reverse proxy
# Solves hardcoded domain issue, supports access via any IP/domain
FROM linkease/kspeeder:latest

LABEL maintainer="czytcn@gmail.com"
LABEL description="KSpeeder with Caddy reverse proxy for any domain/IP access"

# Install Caddy and supervisor
RUN apk add --no-cache caddy supervisor && \
    which caddy && \
    caddy version

# Create Caddy configuration file
RUN cat > /etc/caddy/Caddyfile << 'EOF'
# HTTP and HTTPS proxy ports - Supports any domain/IP access
:80, :443 {
    # Health check endpoint
    handle /health {
        respond "KSpeeder with Caddy Proxy - Healthy" 200 {
            header Content-Type "text/plain"
        }
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

# Create supervisor configuration to manage KSpeeder and Caddy services
RUN mkdir -p /etc/supervisor/conf.d && \
cat > /etc/supervisor/conf.d/supervisord.conf << 'EOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
loglevel=info

[program:kspeeder]
command=/entrypoint.sh
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/kspeeder_stderr.log
stdout_logfile=/var/log/supervisor/kspeeder_stdout.log
user=root
priority=1
startsecs=10
startretries=3

[program:caddy]
command=caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/caddy_stderr.log
stdout_logfile=/var/log/supervisor/caddy_stdout.log
user=root
priority=2
# Wait for KSpeeder to start before launching Caddy
startsecs=20
startretries=3
depends_on=kspeeder
EOF

# Create new entrypoint script
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

# Create log directory
mkdir -p /var/log/supervisor

# Start supervisor to manage all services
echo "Starting supervisor..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
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

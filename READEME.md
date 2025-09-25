Enhanced KSpeeder

## 核心功能
1. **基于官方镜像**: 完全兼容 `linkease/kspeeder:latest`
2. **添加Caddy代理**: 通过80/443端口提供无需修改hosts的访问
3. **保持官方端口**: 5443和5003端口功能不变
4. **自动域名重写**: Caddy自动将任何Host头改为`registry.linkease.net`

## 端口说明
- **80**: HTTP代理 - 任意IP/域名访问
- **443**: HTTPS代理 - 任意IP/域名访问
- **5443**: 官方HTTPS端口 - 需要正确的域名/hosts配置
- **5003**: 管理界面 - 官方管理端口

## 使用方式

**Docker Compose (docker-compose.yml)**:
```yaml
version: '3.8'
services:
  kspeeder:
    build: .
    container_name: kspeeder
    ports:
      - "80:80"
      - "443:443"
      - "5443:5443"
      - "5003:5003"
    volumes:
      - ./kspeeder-data:/kspeeder-data
      - ./kspeeder-config:/kspeeder-config
    restart: unless-stopped
```

**客户端配置 (/etc/docker/daemon.json)**:
```json
{
  "registry-mirrors": ["http://YOUR_SERVER_IP"]
}
```

这样客户端就可以直接使用IP地址访问，无需任何hosts文件修改！

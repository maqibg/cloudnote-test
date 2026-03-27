# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

CloudNote 是一个现代化的云笔记应用，提供两个版本：
- **Cloudflare Workers 版本**：基于边缘计算的全球分布式部署
- **Node.js Server 版本**：适合自托管的独立服务器部署

## Project Structure

```
cloudnote/
├── src/                  # CF Workers 版本源码
│   ├── index.ts          # 应用入口
│   ├── routes/           # 路由模块 (note, admin, api)
│   ├── middleware/       # 中间件 (auth, rateLimiter, static)
│   ├── utils/            # 工具函数 (jwt, crypto)
│   └── types.ts          # TypeScript 类型定义
├── .dev.vars.example     # Workers 本地密钥示例
├── wrangler.jsonc        # Workers 配置入口
├── server/               # Node.js Server 版本
│   ├── src/              
│   │   ├── adapters/     # 适配器层 (database, cache, storage)
│   │   ├── routes/       # 路由处理
│   │   ├── middleware/   # 中间件
│   │   └── utils/        # 工具函数
│   └── data/             # SQLite 数据库
└── schema.sql            # 数据库结构
```

## Development Commands

### Cloudflare Workers Version

```bash
# 准备本地开发密钥
cp .dev.vars.example .dev.vars

# 开发服务器
npm run dev

# 类型检查
npm run typecheck

# 干跑构建
npm run build

# 部署到 Cloudflare
npm run deploy

# 运行测试
npm test

# 代码格式化
npm run format

# 初始化本地数据库
npx wrangler d1 execute cloudnote-db --file=./schema.sql --local --yes

# 初始化远程数据库
npx wrangler d1 execute cloudnote-db --file=./schema.sql --remote --yes

# 设置密钥
npx wrangler secret put ADMIN_USERNAME
npx wrangler secret put ADMIN_PASSWORD
npx wrangler secret put JWT_SECRET
```

### Node.js Server Version

```bash
cd server

# 开发模式（热重载）
npm run dev

# 构建
npm run build

# 生产模式
npm start

# 清理构建文件
npm run clean
```

### Deployment Scripts

Windows 系统使用：
```bash
deploy.bat
```

Linux/macOS 系统使用：
```bash
./deploy.sh
```

## Tech Stack

### Cloudflare Workers 版本
- **框架**: Hono Web Framework
- **数据库**: D1 (SQLite)
- **缓存**: Workers KV
- **存储**: R2 对象存储
- **认证**: JWT (jose library)
- **构建**: Wrangler CLI

### Node.js Server 版本
- **框架**: Hono + @hono/node-server
- **数据库**: better-sqlite3 (SQLite)
- **缓存**: node-cache (内存缓存)
- **存储**: 本地文件系统
- **认证**: JWT (jose library)
- **构建**: TypeScript

## Key Features

1. **动态路径笔记**: 通过 URL 路径直接创建笔记（如 `/mynote`）
2. **富文本编辑器**: 基于 Quill.js，支持格式化文本、列表、代码块等
3. **访问控制**: 支持读锁和写锁，使用 PBKDF2 加密密码
4. **管理后台**: `/admin` 路径，提供笔记管理、统计、导入导出功能
5. **安全特性**: CSRF 防护、XSS 防护、SQL 注入防护、速率限制

## Database Schema

主要数据表：
- `notes`: 存储笔记内容、锁定状态、密码哈希等
- `admin_logs`: 记录管理操作日志

## Environment Variables

### 共同配置
- `ADMIN_USERNAME/ADMIN_USER`: 管理员用户名
- `ADMIN_PASSWORD`: 管理员密码
- `JWT_SECRET`: JWT 签名密钥
- `PATH_MIN_LENGTH`: 笔记路径最小长度 (默认 1)
- `PATH_MAX_LENGTH`: 笔记路径最大长度 (默认 20)
- `RATE_LIMIT_PER_MINUTE`: 每分钟请求限制 (默认 60)
- `SESSION_DURATION`: 会话持续时间（秒）(默认 86400)

### Server 版本额外配置
- `PORT`: 服务器端口 (默认 3000)
- `DATABASE_PATH`: SQLite 数据库路径
- `STORAGE_PATH`: 文件存储路径
- `CACHE_TTL`: 缓存过期时间

## API Endpoints

### 笔记操作
- `GET /:path` - 获取或创建笔记页面
- `GET /api/note/:path` - 获取笔记内容
- `POST /api/note/:path` - 保存笔记
- `POST /api/note/:path/unlock` - 解锁笔记
- `POST /api/note/:path/lock` - 设置笔记锁
- `DELETE /api/note/:path/lock` - 移除笔记锁

### 管理接口
- `GET /admin` - 管理面板页面
- `POST /admin/login` - 管理员登录
- `GET /admin/stats` - 获取统计信息
- `GET /admin/notes` - 获取笔记列表
- `DELETE /admin/notes/:path` - 删除笔记
- `GET /admin/export` - 导出笔记
- `POST /admin/import` - 导入笔记

## Architecture Notes

### Cloudflare Workers 版本
- 使用 Hono 的 Cloudflare Workers 适配器
- 通过 Bindings 接口访问 D1、KV、R2 资源
- 支持边缘计算，全球分布式部署
- 自动扩展，无需管理服务器

### Node.js Server 版本
- 使用适配器模式模拟 Cloudflare Workers API
- D1Database 类包装 better-sqlite3
- KVStore 类实现内存缓存
- R2Storage 类使用本地文件系统
- 保持与 CF Workers 版本 API 兼容

## Security Considerations

- 所有密码使用 PBKDF2 加密存储
- JWT 认证保护管理后台
- CSP 头防护 XSS 攻击
- 参数化查询防止 SQL 注入
- 速率限制防止暴力攻击
- CORS 配置控制跨域访问

## Testing Strategy

目前项目没有测试文件，建议添加：
- 单元测试：使用 Vitest (CF Workers) 或 Jest (Server)
- API 测试：测试所有端点的正确性
- 安全测试：验证认证和授权逻辑

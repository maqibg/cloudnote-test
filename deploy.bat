@echo off
setlocal EnableDelayedExpansion

cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo 错误: 未找到 node
  exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
  echo 错误: 未找到 npm
  exit /b 1
)

echo CloudNote Cloudflare Workers 引导部署
echo.

echo [1/6] 安装项目依赖...
call npm install --package-lock=false
if errorlevel 1 exit /b 1

echo [2/6] 执行 TypeScript 检查...
call npm run typecheck
if errorlevel 1 exit /b 1

echo [3/6] 检查 Cloudflare 登录状态...
call npx wrangler whoami >nul 2>nul
if errorlevel 1 (
  echo 未检测到 Cloudflare 登录状态，开始登录。
  call npx wrangler login
  if errorlevel 1 exit /b 1
)

echo [4/6] 收集运行时密钥...
set /p ADMIN_USERNAME=ADMIN_USERNAME [admin]:
if "%ADMIN_USERNAME%"=="" set "ADMIN_USERNAME=admin"

for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$p=Read-Host 'ADMIN_PASSWORD' -AsSecureString; $b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); try {[Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)} finally {[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b)}"`) do set "ADMIN_PASSWORD=%%i"
if not defined ADMIN_PASSWORD (
  echo 错误: ADMIN_PASSWORD 不能为空
  exit /b 1
)

for /f "usebackq delims=" %%i in (`node -e "const crypto=require('node:crypto'); console.log(crypto.randomBytes(32).toString('base64'))"`) do set "JWT_SECRET=%%i"

echo [5/6] 首次部署并自动创建 KV / R2 / D1 资源...
call npm run deploy
if errorlevel 1 exit /b 1

echo [6/6] 初始化远程数据库并上传 Secrets...
call npx wrangler d1 execute cloudnote-db --remote --file=./schema.sql --yes
if errorlevel 1 exit /b 1

set "SECRETS_FILE=%TEMP%\cloudnote-secrets-%RANDOM%%RANDOM%.json"
powershell -NoProfile -Command "$payload = @{ ADMIN_USERNAME = $env:ADMIN_USERNAME; ADMIN_PASSWORD = $env:ADMIN_PASSWORD; JWT_SECRET = $env:JWT_SECRET } | ConvertTo-Json -Compress; [IO.File]::WriteAllText($env:SECRETS_FILE, $payload, [Text.UTF8Encoding]::new($false))"
if errorlevel 1 exit /b 1

call npx wrangler secret bulk "%SECRETS_FILE%"
if errorlevel 1 exit /b 1

del "%SECRETS_FILE%" >nul 2>nul

echo.
echo 部署完成。
echo 本地开发前，请先复制 .dev.vars.example 为 .dev.vars 并填写真实密钥。
echo 然后运行: npm run dev

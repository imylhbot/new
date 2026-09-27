@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"
title SoulSign - Clean Upload to GitHub

set "REPO_URL=https://github.com/imylhbot/new.git"
set "REPO_PAGE=https://github.com/imylhbot/new"

echo ========================================================
echo   SoulSign iOS 15 - 清空远程 main 并上传当前完整源码
echo   %REPO_PAGE%
echo ========================================================
echo.
echo 警告：
echo 1. 本脚本会删除当前目录中的本地 .git 历史；
echo 2. 会创建一个全新的 main 根提交；
echo 3. 使用 --force 覆盖 GitHub 仓库 main 分支现有代码和提交历史；
echo 4. 不会删除 GitHub Releases、Issues、仓库设置或历史 Actions Run。
echo.
set /p "CONFIRM=确认覆盖请输入 YES："
if /I not "%CONFIRM%"=="YES" (
    echo 已取消。
    pause
    exit /b 0
)

where git >nul 2>&1
if errorlevel 1 (
    echo [错误] 没有找到 git，请先安装 Git for Windows。
    pause
    exit /b 1
)

echo.
echo [1/8] 清除旧本地 Git 历史...
if exist ".git" rd /s /q ".git"
if exist ".git" goto :error

echo [2/8] 初始化全新的 main 分支...
git init >nul
if errorlevel 1 goto :error
git symbolic-ref HEAD refs/heads/main

echo [3/8] 设置提交身份...
for /f "delims=" %%A in ('git config --global user.name 2^>nul') do set "GIT_NAME=%%A"
for /f "delims=" %%A in ('git config --global user.email 2^>nul') do set "GIT_EMAIL=%%A"
if not defined GIT_NAME set "GIT_NAME=imylhbot"
if not defined GIT_EMAIL set "GIT_EMAIL=imylhbot@users.noreply.github.com"
git config user.name "%GIT_NAME%"
git config user.email "%GIT_EMAIL%"
echo     Name : %GIT_NAME%
echo     Email: %GIT_EMAIL%

echo [4/8] 绑定 GitHub 仓库...
git remote add origin "%REPO_URL%"
if errorlevel 1 goto :error

echo [5/8] 添加 SoulSign 全部源码...
git add -A
if errorlevel 1 goto :error

echo [6/8] 创建全新的根提交...
git commit -m "SoulSign iOS 15 build fix and cache optimization"
if errorlevel 1 goto :error

echo [7/8] 强制覆盖远程 main...
git push -u origin main --force
if errorlevel 1 goto :push_error

echo [8/8] 完成。
echo.
echo ========================================================
echo 上传成功！
echo %REPO_PAGE%
echo.
echo GitHub 手动打包：
echo Actions ^> SoulSign Manual Release ^> Run workflow
echo ========================================================
echo.
pause
exit /b 0

:push_error
echo.
echo ========================================================
echo 上传失败。
echo 如果出现 403 / Authentication failed，请重新登录 GitHub。
echo 如果提示 protected branch，请关闭 main 分支保护后再运行。
echo ========================================================
echo.
pause
exit /b 1

:error
echo.
echo ========================================================
echo 操作失败，请查看上面的 Git 错误信息。
echo ========================================================
echo.
pause
exit /b 1

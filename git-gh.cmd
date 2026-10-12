@echo off
REM git-gh.cmd - git wrapper for this sandboxed environment.
REM
REM Why this exists: inside the dsh shell sandbox
REM   1) Windows schannel cannot acquire TLS credentials  -> force git's OpenSSL backend
REM   2) direct outbound connections to github.com are reset -> use the local proxy
REM   3) ~/.gitconfig is not writable (outside workspace)   -> keep credentials in this folder
REM
REM Usage:  git-gh.cmd <any git arguments>
REM   e.g.  git-gh.cmd clone https://github.com/owner/repo.git
REM         git-gh.cmd -C repo push -u origin main

setlocal
set "GIT_EXE=C:\Program Files\Git\cmd\git.exe"
set "HTTP_PROXY=http://127.0.0.1:7897"
set "HTTPS_PROXY=http://127.0.0.1:7897"

"%GIT_EXE%" ^
  -c http.sslBackend=openssl ^
  -c credential.helper="store --file=%~dp0.git-credentials" ^
  %*
endlocal

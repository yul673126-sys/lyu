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
REM         git-gh.cmd -C repo ls-remote origin
REM
REM LIMITATION (verified): any operation that needs credentials -- push, and
REM clone/fetch of PRIVATE repos -- will fail here, because this sandbox cannot
REM create the named pipes git uses to talk to a credential helper:
REM     sh.exe: *** fatal error - couldn't create signal pipe, Win32 error 5
REM     fatal: could not read Username for 'https://github.com'
REM For pushing, use push-gh.ps1 instead (it injects the token into the URL,
REM bypassing the helper entirely).

setlocal
set "GIT_EXE=C:\Program Files\Git\cmd\git.exe"
set "HTTP_PROXY=http://127.0.0.1:7897"
set "HTTPS_PROXY=http://127.0.0.1:7897"

"%GIT_EXE%" ^
  -c http.sslBackend=openssl ^
  -c credential.helper="store --file=%~dp0.git-credentials" ^
  %*
endlocal

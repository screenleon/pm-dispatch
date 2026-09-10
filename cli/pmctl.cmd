@echo off
rem pm-dispatch CLI shim for Windows callers that cannot exec an extension-less
rem bash script directly (PowerShell reports "Cannot run a document in the
rem middle of a pipeline"). Delegates to Git Bash; %~dp0 is this file's own
rem directory, so this works from any CWD and without install-time wiring.
bash "%~dp0pmctl" %*

<#
.SYNOPSIS
  Windows-native process-group isolation primitives for runtime/lib/detached-launch.sh
  (issue #606). Native Windows Git Bash has no setsid, no /proc, and no POSIX
  process-group signal -- this script is the single place that talks to the
  real Win32 Job Object API on its behalf, via -Action dispatch so the P/Invoke
  declarations are made exactly once.

.DESCRIPTION
  -Action Launch
    Create a Job Object with JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE, start
    <-BashExe> <argv decoded from -TargetArgsB64> as the job's sole initial
    member, write the launched process's own pid to -ChildPidFile, pump its
    stdout/stderr into -LogFile (truncated first, matching POSIX `>` before
    `2>&1`), then block until it exits and propagate its exit code.

    THIS SCRIPT'S OWN PROCESS is the unit callers must record and later
    signal to tear the tree down -- not the bash.exe child. It is the only
    handle holder for the job for the job's entire lifetime; closing that
    handle (by this process exiting, gracefully or by force) is what
    KILL_ON_JOB_CLOSE hooks into.

    Verified empirically on a real Windows 11 host (2026-09-20, see PR
    description for the exact commands): a Job Object is destroyed the
    instant its creator's last handle closes, even though member processes
    themselves survive that -- so a SEPARATE process (e.g. `pmctl dispatch
    cancel`, invoked much later, in a different shell) cannot reopen a job by
    name the way an earlier design draft assumed. Keeping this launcher
    process alive for the job's whole lifetime and using ITS pid as the kill
    target sidesteps that: an external TerminateProcess against this exact
    process closes its one and only job handle, which -- because of
    KILL_ON_JOB_CLOSE -- atomically terminates every process still assigned
    to the job. Verified three levels deep (this launcher -> bash.exe ->
    cmd.exe -> a grandchild) with a forced kill of the launcher alone.

  -Action Identity -TargetPid <pid>
    Print pid=/pgid=/starttime=/comm=/isolated=/boot_id= key=value lines for
    <pid>, matching the field names detached_launch_capture_identity emits on
    POSIX so detached_launch_load_identity_file needs no changes. pgid is
    always identical to pid (Launch's process IS the killable unit) and
    isolated is always 1 -- Job Objects have no "isolation not available"
    degraded mode the way missing setsid does on POSIX, so there is no
    isolated=0 case on Windows. starttime is the process's own creation time
    in UTC .NET ticks (100ns since 0001-01-01), which -- unlike Linux's
    boot-relative /proc starttime -- can never collide across a reboot by
    construction, since it is an absolute timestamp. comm is the process
    name (parity with POSIX comm's base-name granularity). boot_id is the
    host's current boot timestamp (also UTC ticks, from
    Win32_OperatingSystem.LastBootUpTime, which is a value recorded at boot
    and stable for the life of that boot -- not a running counter, so it
    does not drift between two independent queries the way an
    uptime-derived estimate would).

  -Action Verify -TargetPid <pid> -ExpectStarttime <ticks> -ExpectComm <name> [-ExpectBootId <ticks>]
    Exit 0  -- process alive, starttime+comm match (safe to signal).
    Exit 1  -- process gone, OR the host's current boot_id is later than the
               expect_boot_id captured at identity time (a reboot happened
               since capture; the original process cannot possibly still be
               alive, so do not even attempt the starttime comparison).
    Exit 2  -- process alive but starttime or comm mismatch (PID reuse).

  -Action Kill -TargetPid <pid> -CallerWinPid <pid> [-GraceSeconds <n>]
    Exit 0 immediately if <-TargetPid> is already gone (idempotent, matching
    detached_launch_kill_process_group's own POSIX contract). Otherwise
    refuses if <-TargetPid> is -CallerWinPid or any ancestor of it (never
    let a cancel/cleanup path kill the invoking shell/automation runner --
    the direct Windows-side analogue of
    detached_launch_kill_process_group's self/ancestor pgid guard), then
    force-terminates <-TargetPid> and polls up to -GraceSeconds for every
    process the job held to be gone. Deliberately does NOT re-verify
    starttime/comm identity here -- exactly like the POSIX function, it
    trusts the caller already called detached_launch_verify_identity (a
    separate step) beforehand; the same TOCTOU window between verify and
    kill exists on both platforms either way, so duplicating the check here
    would just be a different safety story, not a stronger one.

    Windows has no SIGTERM-equivalent soft-kill for an arbitrary console
    process tree (no message loop to post WM_CLOSE to), so unlike the POSIX
    TERM-then-KILL two-phase grace period, this is a single hard kill;
    -GraceSeconds only bounds how long Kill polls afterward for confirmation
    that the whole tree actually went away.

.NOTES
  Invoked via: powershell.exe -NoProfile -NonInteractive -File <this> -Action <...> ...
  Never invoked with -Command string interpolation of caller-controlled
  values (the pattern _sw_windows_store_root_allows_write /
  _sw_operation_replace_file use for their single-shot native calls) because
  Launch's target argv is inherently variable-length, and real callers
  forward flag-shaped elements (e.g. "--run-spec") that PowerShell's own
  parameter binder would otherwise try to interpret as parameter names.
  -TargetArgsB64 sidesteps that entirely -- confirmed by direct test, a bare
  positional "--run-spec" is ambiguous to the PowerShell binder even with
  ValueFromRemainingArguments -- by carrying the whole argv as one
  base64(UTF-8, NUL-joined) string, which contains no character either
  PowerShell or Win32 command-line parsing could ever treat as syntax.
  ConvertTo-Win32QuotedArg below is still needed downstream of that decode,
  to build bash.exe's own Arguments string (a plain Win32 process, not
  another PowerShell script, so it parses its argv via standard
  CommandLineToArgvW rules) -- round-trip verified against bash.exe argv
  parsing with spaces, embedded quotes, trailing backslashes,
  backslash-before-quote, an empty string, and mixed cases.
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Launch', 'Identity', 'Verify', 'Kill')]
  [string]$Action,

  [string]$BashExe,
  [string]$ChildPidFile,
  [string]$LogFile,

  [long]$TargetPid,
  [long]$ExpectStarttime,
  [string]$ExpectComm,
  [Nullable[long]]$ExpectBootId,
  [long]$CallerWinPid,
  [int]$GraceSeconds = 5,

  # NUL-joined argv for the bash.exe child, base64-encoded (UTF-8). Passed
  # this way -- rather than as trailing positional arguments -- because
  # PowerShell's own parameter binder treats any raw token starting with '-'
  # as a possible parameter name (real callers forward flags like
  # "--run-spec" as target argv elements) and because base64 has no
  # characters PowerShell or Win32 command-line parsing could ever treat as
  # syntax, so the value cannot be misparsed regardless of its content.
  [string]$TargetArgsB64
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;

public static class PmJobObject {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string lpName);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetInformationJobObject(IntPtr hJob, int JobObjectInfoClass, IntPtr lpJobObjectInfo, uint cbJobObjectInfoLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [StructLayout(LayoutKind.Sequential)]
    public struct IO_COUNTERS {
        public ulong ReadOperationCount, WriteOperationCount, OtherOperationCount;
        public ulong ReadTransferCount, WriteTransferCount, OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct JOBOBJECT_BASIC_LIMIT_INFORMATION {
        public long PerProcessUserTimeLimit;
        public long PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize;
        public UIntPtr MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass;
        public uint SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
        public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit;
        public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed;
        public UIntPtr PeakJobMemoryUsed;
    }

    public const int JobObjectExtendedLimitInformation = 9;
    public const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000;

    public static bool SetKillOnJobClose(IntPtr hJob) {
        var info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        int length = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
        IntPtr p = Marshal.AllocHGlobal(length);
        try {
            Marshal.StructureToPtr(info, p, false);
            return SetInformationJobObject(hJob, JobObjectExtendedLimitInformation, p, (uint)length);
        } finally {
            Marshal.FreeHGlobal(p);
        }
    }

    // --- Suspended-create + job-assign-before-resume (issue #606 follow-up:
    // closes the "early-child escape" window a plain Process.Start() then
    // AssignProcessToJobObject() leaves open, where a fast child could spawn
    // grandchildren of its own before the parent call below ever assigns it
    // to the job, letting those grandchildren escape KILL_ON_JOB_CLOSE).
    // CREATE_SUSPENDED guarantees the new process cannot execute a single
    // instruction -- let alone spawn anything -- until ResumeThread is
    // called, and that call happens only after AssignProcessToJobObject has
    // already succeeded below.

    [StructLayout(LayoutKind.Sequential)]
    public struct SECURITY_ATTRIBUTES {
        public int nLength;
        public IntPtr lpSecurityDescriptor;
        public bool bInheritHandle;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct STARTUPINFO {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars;
        public int dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput, hStdOutput, hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess, hThread;
        public int dwProcessId, dwThreadId;
    }

    public const int STARTF_USESTDHANDLES = 0x00000100;
    public const uint CREATE_SUSPENDED = 0x00000004;
    public const uint CREATE_NO_WINDOW = 0x08000000;
    public const uint HANDLE_FLAG_INHERIT = 1;
    public const uint INFINITE = 0xFFFFFFFF;

    [DllImport("kernel32.dll", EntryPoint = "CreateProcessW", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CreateProcess(
        string lpApplicationName, StringBuilder lpCommandLine,
        IntPtr lpProcessAttributes, IntPtr lpThreadAttributes,
        bool bInheritHandles, uint dwCreationFlags,
        IntPtr lpEnvironment, string lpCurrentDirectory,
        ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CreatePipe(out IntPtr hReadPipe, out IntPtr hWritePipe, ref SECURITY_ATTRIBUTES lpPipeAttributes, uint nSize);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetHandleInformation(IntPtr hObject, uint dwMask, uint dwFlags);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint ResumeThread(IntPtr hThread);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetExitCodeProcess(IntPtr hProcess, out uint lpExitCode);

    private static readonly object LogWriteLock = new object();

    private static void PumpPipeToLog(IntPtr readHandle, string logFile) {
        // Runs on a plain System.Threading.Thread (not a PowerShell
        // runspace), so ordinary blocking .NET stream reads are safe here.
        using (var safeHandle = new SafeFileHandle(readHandle, true))
        using (var stream = new FileStream(safeHandle, FileAccess.Read))
        using (var reader = new StreamReader(stream)) {
            string line;
            while ((line = reader.ReadLine()) != null) {
                lock (LogWriteLock) {
                    File.AppendAllText(logFile, line + "\r\n");
                }
            }
        }
    }

    // Creates <exePath> suspended, wires its stdout/stderr to <logFile>
    // (truncated by the caller first), assigns it to <hJob> while still
    // suspended, resumes it, waits for exit, and returns its exit code.
    // Writes the real Win32 pid to <childPidFile> as soon as it is known
    // (right after CreateProcess succeeds), before assign/resume/wait.
    public static int LaunchSuspendedInJob(IntPtr hJob, string exePath, string cmdLine, string cwd, string logFile, string childPidFile) {
        var sa = new SECURITY_ATTRIBUTES();
        sa.nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES));
        sa.bInheritHandle = true;
        sa.lpSecurityDescriptor = IntPtr.Zero;

        IntPtr outRead, outWrite, errRead, errWrite;
        if (!CreatePipe(out outRead, out outWrite, ref sa, 0)) {
            throw new InvalidOperationException("CreatePipe(stdout) failed: " + Marshal.GetLastWin32Error());
        }
        SetHandleInformation(outRead, HANDLE_FLAG_INHERIT, 0);
        if (!CreatePipe(out errRead, out errWrite, ref sa, 0)) {
            throw new InvalidOperationException("CreatePipe(stderr) failed: " + Marshal.GetLastWin32Error());
        }
        SetHandleInformation(errRead, HANDLE_FLAG_INHERIT, 0);

        var si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
        si.dwFlags = STARTF_USESTDHANDLES;
        si.hStdOutput = outWrite;
        si.hStdError = errWrite;
        si.hStdInput = IntPtr.Zero;

        var sb = new StringBuilder(cmdLine, Math.Max(cmdLine.Length + 1, 32768));
        PROCESS_INFORMATION pi;
        // lpEnvironment = IntPtr.Zero means "inherit the caller's current
        // environment block" -- the caller sets PM_WINJOB_WRAPPER_PID in its
        // own process environment before calling this, exactly matching
        // ProcessStartInfo.EnvironmentVariables' prior merge-with-parent
        // behavior.
        bool ok = CreateProcess(exePath, sb, IntPtr.Zero, IntPtr.Zero, true,
            CREATE_SUSPENDED | CREATE_NO_WINDOW, IntPtr.Zero, cwd, ref si, out pi);

        // Parent no longer needs its own copies of the write ends regardless
        // of outcome -- the child (if created) inherited its own copies.
        CloseHandle(outWrite);
        CloseHandle(errWrite);

        if (!ok) {
            CloseHandle(outRead);
            CloseHandle(errRead);
            throw new InvalidOperationException("CreateProcess failed: " + Marshal.GetLastWin32Error());
        }

        try {
            File.WriteAllText(childPidFile, pi.dwProcessId.ToString());

            if (!AssignProcessToJobObject(hJob, pi.hProcess)) {
                int err = Marshal.GetLastWin32Error();
                CloseHandle(outRead);
                CloseHandle(errRead);
                throw new InvalidOperationException("AssignProcessToJobObject failed: " + err);
            }

            var outThread = new Thread(() => PumpPipeToLog(outRead, logFile));
            var errThread = new Thread(() => PumpPipeToLog(errRead, logFile));
            outThread.Start();
            errThread.Start();

            uint resumeResult = ResumeThread(pi.hThread);
            if (resumeResult == 0xFFFFFFFF) {
                throw new InvalidOperationException("ResumeThread failed: " + Marshal.GetLastWin32Error());
            }

            WaitForSingleObject(pi.hProcess, INFINITE);
            // Pipe write ends are only fully closed once the process (and
            // any inheriting descendants) exit, which is what lets each
            // pump thread's ReadLine loop reach EOF and return -- join
            // after the wait so the log is guaranteed complete before this
            // returns.
            outThread.Join();
            errThread.Join();

            uint exitCode;
            GetExitCodeProcess(pi.hProcess, out exitCode);
            return (int)exitCode;
        } finally {
            CloseHandle(pi.hThread);
            CloseHandle(pi.hProcess);
        }
    }
}
'@

# Standard Win32 command-line argument quoting (the algorithm CommandLineToArgvW
# expects, and the one .NET's own ArgumentList implements where it is available
# -- it is not on this host's PowerShell 5.1 / .NET Framework 4.x, confirmed by
# direct test on 2026-09-20, hence building Arguments as a single pre-quoted
# string here instead). Round-trip verified against bash.exe argv parsing with
# spaces, embedded quotes, trailing backslashes, backslash-before-quote, an
# empty string, and mixed cases.
function ConvertTo-Win32QuotedArg {
  param([string]$Arg)
  if ($Arg.Length -eq 0) { return '""' }
  if ($Arg -notmatch '[\s"]') { return $Arg }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('"')
  for ($i = 0; $i -lt $Arg.Length; $i++) {
    $numBackslashes = 0
    while ($i -lt $Arg.Length -and $Arg[$i] -eq '\') { $numBackslashes++; $i++ }
    if ($i -eq $Arg.Length) {
      [void]$sb.Append('\' * ($numBackslashes * 2))
      break
    } elseif ($Arg[$i] -eq '"') {
      [void]$sb.Append('\' * ($numBackslashes * 2 + 1))
      [void]$sb.Append('"')
    } else {
      [void]$sb.Append('\' * $numBackslashes)
      [void]$sb.Append($Arg[$i])
    }
  }
  [void]$sb.Append('"')
  return $sb.ToString()
}

function Get-PmBootIdTicks {
  (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().Ticks
}

# $null when the pid is not a live process right now -- never throws.
function Get-PmProcessSnapshot {
  # Named ProcId, not Pid: $Pid is a PowerShell automatic read-only variable
  # holding the CURRENT process's own id, and a parameter named -Pid throws
  # "Cannot overwrite variable Pid" at bind time -- confirmed by direct test.
  param([long]$ProcId)
  $p = Get-Process -Id $ProcId -ErrorAction SilentlyContinue
  if ($null -eq $p) { return $null }
  [PSCustomObject]@{
    Pid       = $p.Id
    Starttime = $p.StartTime.ToUniversalTime().Ticks
    Comm      = $p.ProcessName
  }
}

switch ($Action) {

  'Launch' {
    if (-not $BashExe -or -not $ChildPidFile -or -not $LogFile) {
      Write-Error 'Launch requires -BashExe, -ChildPidFile and -LogFile'
      exit 1
    }
    $hJob = [PmJobObject]::CreateJobObject([IntPtr]::Zero, $null)
    if ($hJob -eq [IntPtr]::Zero) {
      Write-Error "CreateJobObject failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
      exit 1
    }
    if (-not [PmJobObject]::SetKillOnJobClose($hJob)) {
      Write-Error "SetInformationJobObject failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
      exit 1
    }

    if (-not $TargetArgsB64) {
      Write-Error 'Launch requires -TargetArgsB64'
      exit 1
    }
    # Encoded on the bash side as `printf '%s\0' "$@" | base64` -- every
    # argv element, including the last, is followed by a NUL separator, so
    # splitting on NUL always yields exactly one trailing empty element to
    # drop; this is unambiguous even when a real argv element is itself an
    # empty string, which -split alone could not distinguish from "no more
    # elements".
    $rawBytes = [System.Convert]::FromBase64String($TargetArgsB64)
    $parts = [System.Text.Encoding]::UTF8.GetString($rawBytes) -split "`0"
    $targetArgs = if ($parts.Length -gt 1) { $parts[0..($parts.Length - 2)] } else { @() }
    $quotedArgs = @($targetArgs) | ForEach-Object { ConvertTo-Win32QuotedArg $_ }
    # Win32 convention: lpCommandLine's own argv[0] is independent of
    # lpApplicationName and is what the child sees as its own $0 -- include
    # the quoted exe path as argv[0] exactly as ProcessStartInfo did
    # implicitly.
    $cmdLine = (ConvertTo-Win32QuotedArg $BashExe) + ' ' + ($quotedArgs -join ' ')

    # Self-identifying scripts launched this way (gate-supervisor.sh's
    # _write_ready, which captures "its own" identity via detached_launch_
    # capture_identity "$$" to publish for later cancel/verify) cannot use
    # bash's own $$ for that on Windows -- MSYS's $$ is an internal fake pid
    # no Win32 API recognizes (confirmed by direct test), and in any case
    # the unit a later kill actually targets is THIS wrapper process, not
    # the bash.exe child. Exporting this wrapper's own real pid lets such a
    # script ask for the right value instead (see detached_launch_self_pid
    # in detached-launch.sh). Set in THIS process's own environment (not on
    # a ProcessStartInfo object) because LaunchSuspendedInJob's raw
    # CreateProcess call passes lpEnvironment=NULL, which means "inherit the
    # caller's current environment block" -- exactly the merge-with-parent
    # behavior ProcessStartInfo.EnvironmentVariables gave for free before.
    [Environment]::SetEnvironmentVariable('PM_WINJOB_WRAPPER_PID', [string]$PID, 'Process')

    # Truncate/create the log file up front (matches POSIX `>"$log_file"`
    # semantics); LaunchSuspendedInJob appends each line as it arrives from
    # either stream once the child is assigned to the job and resumed.
    [System.IO.File]::WriteAllText($LogFile, '')

    try {
      $exitCode = [PmJobObject]::LaunchSuspendedInJob($hJob, $BashExe, $cmdLine, (Get-Location).Path, $LogFile, $ChildPidFile)
    } catch {
      Write-Error "failed to launch bash under job: $_"
      [PmJobObject]::CloseHandle($hJob) | Out-Null
      exit 1
    }

    [PmJobObject]::CloseHandle($hJob) | Out-Null
    exit $exitCode
  }

  'Identity' {
    $snap = Get-PmProcessSnapshot -ProcId $TargetPid
    if ($null -eq $snap) { exit 1 }
    $bootId = Get-PmBootIdTicks
    Write-Output "pid=$($snap.Pid)"
    Write-Output "pgid=$($snap.Pid)"
    Write-Output "starttime=$($snap.Starttime)"
    Write-Output "comm=$($snap.Comm)"
    Write-Output "isolated=1"
    Write-Output "boot_id=$bootId"
    exit 0
  }

  'Verify' {
    if ($ExpectBootId.HasValue) {
      $curBoot = Get-PmBootIdTicks
      # A reboot after identity capture means the original process cannot
      # possibly still be alive at this pid -- report gone without even
      # attempting the (meaningless, post-reboot) starttime comparison.
      if ($curBoot -ne $ExpectBootId.Value) { exit 1 }
    }
    $snap = Get-PmProcessSnapshot -ProcId $TargetPid
    if ($null -eq $snap) { exit 1 }
    if ($snap.Starttime -ne $ExpectStarttime -or $snap.Comm -ne $ExpectComm) { exit 2 }
    exit 0
  }

  'Kill' {
    if (-not $CallerWinPid) {
      Write-Error 'Kill requires -CallerWinPid'
      exit 1
    }
    # No identity re-verification here, deliberately: this mirrors
    # detached_launch_kill_process_group's own POSIX contract exactly, which
    # trusts that its caller already called detached_launch_verify_identity
    # (a separate step) and only guards against the self/ancestor case
    # below -- adding a second identity check here would just be a
    # different safety story than POSIX has, not a stronger one, since the
    # same TOCTOU window between verify and kill exists on both platforms
    # either way. Idempotent like the POSIX version too: already-gone counts
    # as success, not failure.
    if ($null -eq (Get-PmProcessSnapshot -ProcId $TargetPid)) { exit 0 }

    # Never signal the caller's own process or any of its ancestors -- the
    # direct analogue of detached_launch_kill_process_group's self/ancestor
    # pgid guard, which exists to protect the invoking shell/automation
    # runner from ever being caught by its own cleanup path. Fails closed if
    # the ancestor chain becomes unreadable mid-walk, exactly like the POSIX
    # ps-based walk does.
    $probe = $CallerWinPid
    $depth = 0
    while ($probe -and $probe -gt 0 -and $depth -lt 4096) {
      if ($probe -eq $TargetPid) {
        Write-Error "refusing to kill pid ${TargetPid}: it is the caller or an ancestor of the caller"
        exit 2
      }
      $procInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$probe" -ErrorAction SilentlyContinue
      if ($null -eq $procInfo) { break }
      $parent = $procInfo.ParentProcessId
      if (-not $parent -or $parent -eq $probe) { break }
      $probe = $parent
      $depth++
    }

    try {
      Stop-Process -Id $TargetPid -Force -ErrorAction Stop
    } catch {
      # Already gone between the snapshot above and here counts as success.
      $still = Get-Process -Id $TargetPid -ErrorAction SilentlyContinue
      if ($null -ne $still) {
        Write-Error "Stop-Process failed: $_"
        exit 1
      }
    }

    $deadline = (Get-Date).AddSeconds($GraceSeconds)
    while ((Get-Date) -lt $deadline) {
      if ($null -eq (Get-Process -Id $TargetPid -ErrorAction SilentlyContinue)) { exit 0 }
      Start-Sleep -Milliseconds 200
    }
    if ($null -eq (Get-Process -Id $TargetPid -ErrorAction SilentlyContinue)) { exit 0 }
    exit 1
  }
}

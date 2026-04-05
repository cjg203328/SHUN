using System;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

internal static class OpenClawLauncher
{
    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        try
        {
            var shouldOpenDashboard = true;
            var repairGateway = false;
            foreach (var arg in Environment.GetCommandLineArgs())
            {
                if (string.Equals(arg, "--no-open", StringComparison.OrdinalIgnoreCase))
                {
                    shouldOpenDashboard = false;
                }
                else if (string.Equals(arg, "--repair-gateway", StringComparison.OrdinalIgnoreCase))
                {
                    repairGateway = true;
                }
            }

            var openClawCmdPath = GetOpenClawCmdPath();
            if (!File.Exists(openClawCmdPath))
            {
                ShowError(
                    "OpenClawLauncher",
                    "Could not find openclaw.cmd.\r\n\r\nExpected path:\r\n" + openClawCmdPath);
                return;
            }

            var configPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                ".openclaw",
                "openclaw.json");

            if (!File.Exists(configPath))
            {
                ShowError(
                    "OpenClawLauncher",
                    "OpenClaw is not initialized yet.\r\n\r\nPlease run this once in PowerShell:\r\nopenclaw.cmd onboard --mode local");
                return;
            }

            var port = ReadConfigInt(File.ReadAllText(configPath), "\"port\"\\s*:\\s*(\\d+)", 18789);

            if (repairGateway)
            {
                EnsureAdministrator();
                RepairGateway(openClawCmdPath, port);
                if (!WaitForGateway(openClawCmdPath, timeoutMs: 45000, intervalMs: 1000))
                {
                    ShowError(
                        "OpenClawLauncher",
                        "OpenClaw gateway repair did not complete in time.\r\n\r\nYou can inspect:\r\n" +
                        configPath);
                    return;
                }

                if (shouldOpenDashboard)
                {
                    OpenDashboard(configPath);
                }

                return;
            }

            if (!IsGatewayHealthy(openClawCmdPath))
            {
                var listeningPid = GetListeningPid(port);
                if (listeningPid > 0)
                {
                    RelaunchElevated(shouldOpenDashboard, "--repair-gateway");
                    return;
                }

                StartGateway(openClawCmdPath, force: false);

                var ready = WaitForGateway(openClawCmdPath, timeoutMs: 45000, intervalMs: 1000);
                if (!ready)
                {
                    ShowError(
                        "OpenClawLauncher",
                        "OpenClaw gateway did not become ready in time.\r\n\r\nYou can inspect:\r\n" +
                        configPath);
                    return;
                }
            }

            if (shouldOpenDashboard)
            {
                OpenDashboard(configPath);
            }
        }
        catch (Exception ex)
        {
            ShowError("OpenClawLauncher", ex.Message);
        }
    }

    private static string GetOpenClawCmdPath()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        return Path.Combine(appData, "npm", "openclaw.cmd");
    }

    private static void EnsureAdministrator()
    {
        using (var identity = WindowsIdentity.GetCurrent())
        {
            var principal = new WindowsPrincipal(identity);
            if (!principal.IsInRole(WindowsBuiltInRole.Administrator))
            {
                throw new InvalidOperationException("Administrator permissions are required to repair the OpenClaw gateway.");
            }
        }
    }

    private static bool IsGatewayHealthy(string openClawCmdPath)
    {
        var startInfo = CreateCmdWrapperStartInfo(
            openClawCmdPath,
            "health --json");

        using (var process = Process.Start(startInfo))
        {
            if (process == null)
            {
                return false;
            }

            if (!process.WaitForExit(8000))
            {
                TryKill(process);
                return false;
            }

            return process.ExitCode == 0;
        }
    }

    private static void StartGateway(string openClawCmdPath, bool force)
    {
        var startInfo = CreateCmdWrapperStartInfo(
            openClawCmdPath,
            force ? "gateway run --force" : "gateway run");
        startInfo.RedirectStandardOutput = false;
        startInfo.RedirectStandardError = false;

        var process = Process.Start(startInfo);
        if (process == null)
        {
            throw new InvalidOperationException("Failed to start OpenClaw gateway.");
        }
    }

    private static void RepairGateway(string openClawCmdPath, int port)
    {
        var pid = GetListeningPid(port);
        if (pid > 0)
        {
            StopProcessTree(pid);
            Thread.Sleep(1500);
        }

        StartGateway(openClawCmdPath, force: true);
    }

    private static bool WaitForGateway(string openClawCmdPath, int timeoutMs, int intervalMs)
    {
        var startedAt = Environment.TickCount;
        while (Environment.TickCount - startedAt < timeoutMs)
        {
            Thread.Sleep(intervalMs);
            if (IsGatewayHealthy(openClawCmdPath))
            {
                return true;
            }
        }

        return false;
    }

    private static void OpenDashboard(string configPath)
    {
        var config = File.ReadAllText(configPath);
        var port = ReadConfigInt(config, "\"port\"\\s*:\\s*(\\d+)", 18789);
        var token = ReadConfigString(config, "\"token\"\\s*:\\s*\"([^\"]+)\"", string.Empty);

        var url = "http://127.0.0.1:" + port + "/";
        if (!string.IsNullOrWhiteSpace(token))
        {
            url += "#token=" + token;
        }

        Process.Start(url);
    }

    private static int GetListeningPid(int port)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "cmd.exe",
            Arguments = "/c netstat -ano -p tcp",
            CreateNoWindow = true,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WindowStyle = ProcessWindowStyle.Hidden
        };

        using (var process = Process.Start(startInfo))
        {
            if (process == null)
            {
                return -1;
            }

            var output = process.StandardOutput.ReadToEnd();
            process.WaitForExit(5000);

            var pattern = "^\\s*TCP\\s+\\S+:" + port + "\\s+\\S+\\s+LISTENING\\s+(\\d+)\\s*$";
            var match = Regex.Match(output, pattern, RegexOptions.Multiline | RegexOptions.IgnoreCase);
            int pid;
            if (match.Success && int.TryParse(match.Groups[1].Value, out pid))
            {
                return pid;
            }
        }

        return -1;
    }

    private static void StopProcessTree(int pid)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "taskkill.exe",
            Arguments = "/PID " + pid + " /T /F",
            CreateNoWindow = true,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WindowStyle = ProcessWindowStyle.Hidden
        };

        using (var process = Process.Start(startInfo))
        {
            if (process == null)
            {
                throw new InvalidOperationException("Failed to stop the existing OpenClaw gateway process.");
            }

            if (!process.WaitForExit(8000) || process.ExitCode != 0)
            {
                var error = process.StandardError.ReadToEnd();
                if (string.IsNullOrWhiteSpace(error))
                {
                    error = process.StandardOutput.ReadToEnd();
                }

                throw new InvalidOperationException(
                    "Failed to stop the existing OpenClaw gateway process." +
                    (string.IsNullOrWhiteSpace(error) ? string.Empty : "\r\n\r\n" + error.Trim()));
            }
        }
    }

    private static ProcessStartInfo CreateCmdWrapperStartInfo(string openClawCmdPath, string openClawArgs)
    {
        return new ProcessStartInfo
        {
            FileName = "cmd.exe",
            Arguments = "/c \"" + openClawCmdPath + "\" " + openClawArgs,
            WorkingDirectory = Path.GetDirectoryName(openClawCmdPath) ?? Environment.CurrentDirectory,
            CreateNoWindow = true,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WindowStyle = ProcessWindowStyle.Hidden
        };
    }

    private static void RelaunchElevated(bool shouldOpenDashboard, string extraArg)
    {
        var executablePath = Environment.GetCommandLineArgs()[0];
        var builder = new StringBuilder();
        if (!shouldOpenDashboard)
        {
            builder.Append("\"--no-open\"");
        }
        if (!string.IsNullOrWhiteSpace(extraArg))
        {
            if (builder.Length > 0)
            {
                builder.Append(" ");
            }
            builder.Append("\"");
            builder.Append(extraArg.Replace("\"", "\\\""));
            builder.Append("\"");
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = executablePath,
            Arguments = builder.ToString(),
            UseShellExecute = true,
            Verb = "runas",
            WindowStyle = ProcessWindowStyle.Normal
        };

        Process.Start(startInfo);
    }

    private static int ReadConfigInt(string content, string pattern, int fallback)
    {
        var match = Regex.Match(content, pattern, RegexOptions.IgnoreCase);
        int value;
        if (match.Success && int.TryParse(match.Groups[1].Value, out value))
        {
            return value;
        }

        return fallback;
    }

    private static string ReadConfigString(string content, string pattern, string fallback)
    {
        var match = Regex.Match(content, pattern, RegexOptions.IgnoreCase);
        if (match.Success)
        {
            return match.Groups[1].Value;
        }

        return fallback;
    }

    private static void TryKill(Process process)
    {
        try
        {
            process.Kill();
        }
        catch
        {
        }
    }

    private static void ShowError(string title, string message)
    {
        MessageBox.Show(message, title, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}

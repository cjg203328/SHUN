using System;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Text.RegularExpressions;
using System.Windows.Forms;

internal static class CloseOpenClawLauncher
{
    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        try
        {
            var silent = false;
            foreach (var arg in Environment.GetCommandLineArgs())
            {
                if (string.Equals(arg, "--silent", StringComparison.OrdinalIgnoreCase))
                {
                    silent = true;
                }
            }

            if (!IsAdministrator())
            {
                RelaunchElevated();
                return;
            }

            var configPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                ".openclaw",
                "openclaw.json");

            if (!File.Exists(configPath))
            {
                if (!silent)
                {
                    ShowInfo("CloseOpenClawLauncher", "OpenClaw config was not found. Nothing to stop.");
                }

                return;
            }

            var config = File.ReadAllText(configPath);
            var port = ReadConfigInt(config, "\"port\"\\s*:\\s*(\\d+)", 18789);
            var pid = GetListeningPid(port);

            if (pid <= 0)
            {
                if (!silent)
                {
                    ShowInfo("CloseOpenClawLauncher", "OpenClaw gateway is not running.");
                }

                return;
            }

            StopProcessTree(pid);

            if (!silent)
            {
                ShowInfo("CloseOpenClawLauncher", "OpenClaw gateway has been stopped.");
            }
        }
        catch (Exception ex)
        {
            ShowError("CloseOpenClawLauncher", ex.Message);
        }
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
                throw new InvalidOperationException("Failed to stop OpenClaw gateway.");
            }

            if (!process.WaitForExit(8000) || process.ExitCode != 0)
            {
                var error = process.StandardError.ReadToEnd();
                if (string.IsNullOrWhiteSpace(error))
                {
                    error = process.StandardOutput.ReadToEnd();
                }

                throw new InvalidOperationException(
                    "Failed to stop OpenClaw gateway." +
                    (string.IsNullOrWhiteSpace(error) ? string.Empty : "\r\n\r\n" + error.Trim()));
            }
        }
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

    private static bool IsAdministrator()
    {
        using (var identity = WindowsIdentity.GetCurrent())
        {
            var principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
    }

    private static void RelaunchElevated()
    {
        var args = Environment.GetCommandLineArgs();
        var executablePath = args[0];

        var builder = new System.Text.StringBuilder();
        for (var i = 1; i < args.Length; i++)
        {
            if (i > 1)
            {
                builder.Append(" ");
            }

            builder.Append("\"");
            builder.Append(args[i].Replace("\"", "\\\""));
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

    private static void ShowInfo(string title, string message)
    {
        MessageBox.Show(message, title, MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    private static void ShowError(string title, string message)
    {
        MessageBox.Show(message, title, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}

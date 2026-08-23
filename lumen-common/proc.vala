// Shared process-spawn helpers (lumen-common). Source-level reuse only.
namespace LumenCommon {
    public class Proc {
        // Synchronous: run argv, capture stdout, return it (or null on spawn
        // failure / nonzero is NOT treated as failure — we still return stdout).
        // argv form avoids shell quoting; PATH is searched.
        //
        // `env` is an optional list of "KEY=VALUE" overrides applied on top of
        // the inherited environment — cheaper than prefixing argv with `env`,
        // which costs an extra process just to set one variable.
        public static string? run_capture(string[] argv, string[]? env = null) {
            try {
                var flags = GLib.SubprocessFlags.STDOUT_PIPE
                          | GLib.SubprocessFlags.STDERR_SILENCE;
                GLib.Subprocess sp;
                if (env == null) {
                    sp = new GLib.Subprocess.newv(argv, flags);
                } else {
                    var launcher = new GLib.SubprocessLauncher(flags);
                    foreach (var kv in env) {
                        int eq = kv.index_of_char('=');
                        if (eq > 0)
                            launcher.setenv(kv.substring(0, eq), kv.substring(eq + 1), true);
                    }
                    sp = launcher.spawnv(argv);
                }
                string? outbuf = null;
                sp.communicate_utf8(null, null, out outbuf, null);
                return outbuf;
            } catch (GLib.Error e) {
                return null;
            }
        }

        // Fire-and-forget: spawn argv detached, don't wait. Errors swallowed.
        public static void spawn_detached(string[] argv) {
            try {
                GLib.Pid pid;
                GLib.Process.spawn_async(null, argv, null,
                    GLib.SpawnFlags.SEARCH_PATH, null, out pid);
                GLib.Process.close_pid(pid);
            } catch (GLib.SpawnError e) {}
        }
    }
}

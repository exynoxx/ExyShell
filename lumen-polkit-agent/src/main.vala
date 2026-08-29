using Gtk;

// lumen-polkit-agent — the LumenShell PolicyKit authentication agent.
//
// PolicyKit (polkitd) only prompts the user for a password when an
// *authentication agent* is registered for the active session. A bare Wayfire
// session has none, so every privileged action (mounting disks, installing
// packages, `pkexec foo`, NetworkManager system connections, …) silently
// fails with "not authorized". This daemon fills that gap: it registers a
// PolkitAgent.Listener for our login session and pops a password dialog
// whenever polkitd asks for authentication.
//
// It is also what makes lumen-drawer's "Ctrl+click → run as administrator"
// work: that path shells out to `pkexec`, whose org.freedesktop.policykit.exec
// action routes straight through this agent.
//
// Realize-hidden idiom (same as lumen-osd / lumen-lockscreen): no window exists
// until polkitd calls BeginAuthentication; the AuthFlow builds an AuthDialog on
// demand. Must run as a child of the Wayfire session (Wayfire [autostart]) so
// the session it registers for is the one the user is sitting in front of.
namespace LumenPolkitAgent {

public class App : Gtk.Application {

    private LumenAgentListener? listener = null;
    private void* reg_handle = null;
    private bool activated = false;

    public App() {
        Object(application_id: "org.lumenshell.PolkitAgent",
               flags: ApplicationFlags.DEFAULT_FLAGS);
    }

    protected override void activate() {
        if (activated) return;
        activated = true;

        install_css();

        if (!register_agent()) {
            // Another agent already owns this session (a full DE was started
            // alongside us), or polkit is unavailable. Nothing useful to do —
            // exit rather than linger as a dead process that never prompts.
            quit();
            return;
        }
        hold();
    }

    private bool register_agent() {
        try {
            // The subject is *this* process's login session; polkitd will only
            // call us for authentications originating in the same session.
            var subject = new Polkit.UnixSession.for_process_sync(
                (int) Posix.getpid(), null);
            if (subject == null) {
                warning("lumen-polkit-agent: cannot resolve this process's "
                        + "login session (not under logind?)");
                return false;
            }

            listener = new LumenAgentListener(this);
            reg_handle = listener.register(
                PolkitAgent.RegisterFlags.NONE,
                subject,
                "/org/lumenshell/PolkitAgent/AuthenticationAgent",
                null);
            message("lumen-polkit-agent: registered as the session "
                    + "authentication agent");
            return true;
        } catch (Error e) {
            warning("lumen-polkit-agent: registration failed (is another "
                    + "authentication agent already running?): %s", e.message);
            return false;
        }
    }

    public override void shutdown() {
        if (reg_handle != null) {
            PolkitAgent.Listener.unregister(reg_handle);
            reg_handle = null;
        }
        base.shutdown();
    }

    private void install_css() {
        var p = new Gtk.CssProvider();
        p.load_from_string(AGENT_CSS);
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), p,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
}

public static int main(string[] args) {
    return new App().run(args);
}

}

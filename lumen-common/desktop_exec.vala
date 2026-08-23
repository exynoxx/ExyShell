namespace LumenCommon {

    // Strip .desktop Exec field codes (%f %F %u %U %i %c %k %d %D %n %N %v %m).
    // AppInfo.launch() expands them; a raw argv handed to Shell.parse_argv or
    // Process.spawn must not carry them. "%%" is the escaped literal and keeps
    // one '%'.
    //
    // Scanning char by char (rather than splitting on spaces and matching a
    // fixed list) is what makes this total: it drops every field code, including
    // ones embedded in a longer token, and never eats a real argument.
    public string strip_field_codes(string exec) {
        var sb = new StringBuilder();
        int i = 0;
        unichar c;
        bool pct = false;
        while (exec.get_next_char(ref i, out c)) {
            if (pct) {
                if (c == '%') sb.append_c('%');
                pct = false;
            } else if (c == '%') {
                pct = true;
            } else {
                sb.append_unichar(c);
            }
        }
        return sb.str.strip();
    }
}

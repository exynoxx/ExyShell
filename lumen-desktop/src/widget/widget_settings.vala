// Per-instance widget variables.
//
// Every widget on the desktop gets its own settings bag, read from the
// "settings" object of its entry in desktop.json. The file browser reads
// "root" and "show-hidden" from here; a future clock widget would read
// "format", a weather widget "location", and so on — no plumbing changes,
// because DesktopConfig hands the bag straight to the widget factory.
//
// Values are stored as strings and coerced on read, so a config that writes
// 22 or "22" for an int both work.

namespace LumenDesktop {

    public class WidgetSettings : GLib.Object {

        private GLib.HashTable<string, string> values
            = new GLib.HashTable<string, string>(str_hash, str_equal);

        public void put(string key, string value) {
            values.insert(key, value);
        }

        public bool has(string key) {
            return values.contains(key);
        }

        // For serialising the bag back out to desktop.json. Values come back
        // as they were stored — strings — because that is all this bag ever
        // knew about them.
        public GLib.List<weak string> keys() {
            return values.get_keys();
        }

        public string get_raw(string key) {
            var v = values.lookup(key);
            return v ?? "";
        }

        public string get_string(string key, string fallback) {
            var v = values.lookup(key);
            return (v == null || v == "") ? fallback : v;
        }

        // As get_string, but expands a leading ~ and any $VAR / ${VAR}, so
        // paths in the config file can be written the way a user would type
        // them in a shell.
        public string get_path(string key, string fallback) {
            return expand_path(get_string(key, fallback));
        }

        public int get_int(string key, int fallback) {
            var v = values.lookup(key);
            if (v == null) return fallback;
            int parsed;
            return int.try_parse(v.strip(), out parsed) ? parsed : fallback;
        }

        public double get_double(string key, double fallback) {
            var v = values.lookup(key);
            if (v == null) return fallback;
            double parsed;
            // Always parse with the C locale: config files are machine-facing
            // and use '.' regardless of the user's LC_NUMERIC.
            return double.try_parse(v.strip(), out parsed) ? parsed : fallback;
        }

        public bool get_bool(string key, bool fallback) {
            var v = values.lookup(key);
            if (v == null) return fallback;
            switch (v.strip().down()) {
                case "1": case "true":  case "yes": case "on":  return true;
                case "0": case "false": case "no":  case "off": return false;
                default: return fallback;
            }
        }

        public static string expand_path(string raw) {
            var p = raw.strip();
            if (p == "" || p == "~") return GLib.Environment.get_home_dir();
            if (p.has_prefix("~/")) {
                return GLib.Path.build_filename(
                    GLib.Environment.get_home_dir(), p.substring(2));
            }
            if (p.index_of_char('$') >= 0) {
                var expanded = expand_vars(p);
                if (expanded.has_prefix("~/")) {
                    return GLib.Path.build_filename(
                        GLib.Environment.get_home_dir(), expanded.substring(2));
                }
                return expanded;
            }
            return p;
        }

        // Minimal $VAR / ${VAR} substitution. Unset variables expand to "",
        // matching shell behaviour.
        private static string expand_vars(string raw) {
            var sb = new GLib.StringBuilder();
            int i = 0;
            int n = raw.length;
            while (i < n) {
                if (raw[i] != '$') {
                    sb.append_c(raw[i]);
                    i++;
                    continue;
                }
                i++;
                if (i >= n) { sb.append_c('$'); break; }
                bool braced = raw[i] == '{';
                if (braced) i++;
                var name = new GLib.StringBuilder();
                while (i < n && (raw[i].isalnum() || raw[i] == '_')) {
                    name.append_c(raw[i]);
                    i++;
                }
                if (braced && i < n && raw[i] == '}') i++;
                if (name.len == 0) { sb.append_c('$'); continue; }
                var val = GLib.Environment.get_variable(name.str);
                if (val != null) sb.append(val);
            }
            return sb.str;
        }
    }
}

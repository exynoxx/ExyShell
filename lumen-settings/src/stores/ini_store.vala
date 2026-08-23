using GLib;

namespace LumenSettings {

    /* Section-aware INI store over GLib.KeyFile.
     *
     * KEEP_COMMENTS makes KeyFile preserve comments, blank lines, group order
     * and key order across a load/save cycle; new keys land at the end of their
     * group and new groups at EOF. The only difference from the file as written
     * by hand is that KeyFile emits `key=value` where a human writes
     * `key = value` — Wayfire's parser accepts both. */
    public class IniStore : GLib.Object {
        public string path { get; construct; }

        const KeyFileFlags FLAGS =
            KeyFileFlags.KEEP_COMMENTS | KeyFileFlags.KEEP_TRANSLATIONS;

        KeyFile kf = new KeyFile();

        // False when the file exists but could not be parsed even after
        // normalisation. save() then refuses to write: KeyFile would emit only
        // the fragment it managed to read, truncating the user's wayfire.ini.
        bool writable = true;

        public IniStore(string path) {
            Object(path: path);
            load();
        }

        // Re-read the backing file from disk, discarding the in-memory copy.
        // Needed when more than one page mutates the SAME file (e.g. the Panel
        // page and the Wayfire Plugins page both edit wayfire.ini's [core]
        // plugins): each holds its own IniStore, so a writer must reload first
        // or it clobbers the other's changes with its stale snapshot.
        public void reload() {
            load();
        }

        public string? get_value(string section, string key) {
            try {
                return kf.get_value(section, key);
            } catch (KeyFileError e) {
                return null;
            }
        }

        public Gee.ArrayList<string> sections() {
            var result = new Gee.ArrayList<string>();
            foreach (var g in kf.get_groups()) result.add(g);
            return result;
        }

        public Gee.ArrayList<string> keys_in(string section) {
            var result = new Gee.ArrayList<string>();
            try {
                foreach (var k in kf.get_keys(section)) result.add(k);
            } catch (KeyFileError e) {
                // Missing section — no keys.
            }
            return result;
        }

        public void set_value(string section, string key, string value) {
            kf.set_value(section, key, value);
        }

        public void remove_key(string section, string key) {
            try {
                kf.remove_key(section, key);
            } catch (KeyFileError e) {
                // Already absent.
            }
        }

        public void save() {
            if (!writable) {
                warning("IniStore: refusing to overwrite unparseable %s", path);
                return;
            }
            if (DirUtils.create_with_parents(Path.get_dirname(path), 0755) != 0) {
                warning("IniStore: cannot create directory for %s", path);
                return;
            }
            try {
                kf.save_to_file(path);
            } catch (FileError e) {
                warning("IniStore: write %s: %s", path, e.message);
            }
        }

        void load() {
            kf = new KeyFile();
            writable = true;
            if (!FileUtils.test(path, FileTest.EXISTS)) return;

            try {
                kf.load_from_file(path, FLAGS);
                return;
            } catch (Error e) {
                // Fall through: retry on a normalised copy.
            }

            string content;
            try {
                FileUtils.get_contents(path, out content);
            } catch (FileError e) {
                warning("IniStore: read %s: %s", path, e.message);
                writable = false;
                return;
            }

            try {
                kf = new KeyFile();
                kf.load_from_data(normalize(content), -1, FLAGS);
            } catch (KeyFileError e) {
                warning("IniStore: %s is not parseable (%s); it will be read as "
                        + "empty and left untouched", path, e.message);
                kf = new KeyFile();
                writable = false;
            }
        }

        // KeyFile rejects three shapes the old hand-rolled parser tolerated:
        // ';' comments, lines that are neither comment nor `key=value`, and
        // keys appearing before the first group. Turn each into a '#' comment
        // so the rest of the file still loads and the text survives a save.
        static string normalize(string content) {
            var sb = new StringBuilder();
            bool in_group = false;
            foreach (var line in content.split("\n")) {
                var t = line.strip();
                bool ok = t == ""
                    || t.has_prefix("#")
                    || (t.has_prefix("[") && t.has_suffix("]"))
                    || (in_group && t.index_of_char('=') > 0);
                sb.append(ok ? line : "#" + line);
                sb.append_c('\n');
                if (t.has_prefix("[")) in_group = true;
            }
            return sb.str;
        }
    }
}

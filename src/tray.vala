using Gtk;
using AppIndicator;

public class TrayApp : Object {
    private Indicator indicator;

    public TrayApp () {
        indicator = new Indicator ("booconnect-vpn-tray", "security-low-symbolic", IndicatorCategory.APPLICATION_STATUS);
        
        var menu = new Gtk.Menu();
        var item_show = new Gtk.MenuItem.with_label ("Show BooConnect");
        item_show.activate.connect (() => { exec(""); });
        menu.append (item_show);
        
        menu.append (new Gtk.SeparatorMenuItem());

        var item_quit = new Gtk.MenuItem.with_label ("Quit");
        item_quit.activate.connect (() => { exec("--disconnect"); Gtk.main_quit(); });
        menu.append (item_quit);
        
        menu.show_all();
        indicator.set_menu (menu);
        indicator.set_status (IndicatorStatus.ACTIVE);

        Timeout.add (2000, () => { update_ui(); return true; });
        update_ui();
    }

    private bool is_vpn_running() {
        try {
            int status;
            string dummy_output;
            Process.spawn_command_line_sync ("pgrep -x openconnect", out dummy_output, null, out status);
            return (status == 0);
        } catch (Error e) { return false; }
    }

    void update_ui() {
        string icon = is_vpn_running() ? "security-high-symbolic" : "security-low-symbolic";
        Idle.add(() => { indicator.set_icon(icon); return false; });
    }

    void exec(string arg) {
        try {
            string p = File.new_for_path(FileUtils.read_link("/proc/self/exe")).get_parent().get_path();
            Process.spawn_command_line_async(p + "/BooConnect " + arg);
        } catch (Error e) {}
    }
}

int main (string[] args) {
    Gtk.init (ref args);
    new TrayApp(); 
    Gtk.main();
    return 0;
}


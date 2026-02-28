using Gtk;
using Adw;
using Json;

public class VpnConfig : GLib.Object {
    public string host { get; set; default = ""; }
    public string user { get; set; default = ""; }
    public string pin { get; set; default = ""; }
    public string sudo { get; set; default = ""; }
}

public class BooConnectWindow : Adw.ApplicationWindow {
    private VpnConfig config;
    private string config_path;
    private string res_dir;
    private Subprocess? process = null;
    
    private bool is_connected = false;
    private bool is_connecting = false;
    private bool is_waiting_sms = false;
    private bool is_verifying_sms = false;
    private bool is_pin_armed = false;
    private bool is_disconnecting = false;
    private bool sudo_password_sent = false;

    private Adw.StatusPage status_page;
    private Button connect_btn;
    private StringBuilder output_buffer = new StringBuilder();

    public BooConnectWindow(Adw.Application app) {
        GLib.Object(application: app);
        this.title = "BooConnect";
        this.set_default_size(400, 450);

        this.res_dir = Environment.get_user_data_dir() + "/BooConnect";
        this.config_path = Environment.get_user_config_dir() + "/.vpn_config.json";

        var toolbar_view = new Adw.ToolbarView();
        var header = new Adw.HeaderBar();
        var menu_btn = new Button.from_icon_name("preferences-system-symbolic");
        menu_btn.clicked.connect(open_settings);
        header.pack_end(menu_btn);
        toolbar_view.add_top_bar(header);

        status_page = new Adw.StatusPage();
        status_page.title = "BooConnect";
        status_page.description = "Ready to connect";
        
        try {
            var file = GLib.File.new_for_path(res_dir + "/AppIcon.svg");
            status_page.paintable = Gdk.Texture.from_file(file);
        } catch (Error e) {
            status_page.icon_name = "network-vpn-symbolic";
        }

        connect_btn = new Button.with_label("Connect");
        connect_btn.add_css_class("suggested-action");
        connect_btn.add_css_class("pill");
        connect_btn.halign = Align.CENTER;
        connect_btn.margin_bottom = 32;
        connect_btn.clicked.connect(on_connect_clicked);

        var box = new Box(Orientation.VERTICAL, 0);
        box.append(status_page);
        box.append(connect_btn);
        
        toolbar_view.set_content(box);
        this.set_content(toolbar_view);

        load_config();
        check_running_process();
    }

    private void send_notification(string title, string body) {
        try {
            string sound_path = res_dir + "/Alert.wav";
            if (FileUtils.test(sound_path, FileTest.EXISTS)) {
                Process.spawn_command_line_async("paplay " + sound_path);
            }
        } catch (Error e) {}

        try {
            string icon_path = res_dir + "/AppIcon.svg";
            string icon_arg = FileUtils.test(icon_path, FileTest.EXISTS) ? "-i \"" + icon_path + "\"" : "";
            string cmd = "notify-send -a \"BooConnect\" \"%s\" \"%s\" %s".printf(title, body, icon_arg);
            string[] argv = {"sh", "-c", cmd};
            Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
        } catch (Error e) {}
    }

    private void check_running_process() {
        try {
            int exit_status;
            string dummy;
            Process.spawn_command_line_sync("pidof openconnect", out dummy, null, out exit_status);
            if (exit_status == 0) set_connected_state(true);
        } catch (Error e) {}
    }

    private void set_connected_state(bool connected) {
        is_connected = connected;
        is_connecting = false;
        if (connected) {
            status_page.title = "Connected";
            status_page.description = "VPN Active";
            connect_btn.label = "Disconnect";
            connect_btn.remove_css_class("suggested-action");
            connect_btn.add_css_class("destructive-action");
        } else {
            status_page.title = "BooConnect";
            status_page.description = "Ready to connect";
            connect_btn.label = "Connect";
            connect_btn.remove_css_class("destructive-action");
            connect_btn.add_css_class("suggested-action");
        }
    }

    private void on_connect_clicked() {
        if (is_connected || is_connecting) disconnect_vpn();
        else connect_vpn();
    }

    private void connect_vpn() {
        if (is_connecting) return;
        is_connecting = true;
        is_disconnecting = false;
        sudo_password_sent = false; 
        output_buffer.truncate(0); 
        status_page.title = "Connecting...";
        
        try { Process.spawn_command_line_sync("sudo -k"); } catch (Error e) {}

        string[] args;
        if (FileUtils.test(res_dir + "/vpnc-script", FileTest.EXISTS)) {
            args = new string[] { "/usr/bin/sudo", "-S", "openconnect", "--protocol=anyconnect", "--useragent=AnyConnect", "--non-inter", "--passwd-on-stdin", "--user=" + config.user, "--server=" + config.host, "--script=" + res_dir + "/vpnc-script" };
        } else {
            args = new string[] { "/usr/bin/sudo", "-S", "openconnect", "--protocol=anyconnect", "--useragent=AnyConnect", "--non-inter", "--passwd-on-stdin", "--user=" + config.user, "--server=" + config.host };
        }

        try {
            process = new Subprocess.newv(args, SubprocessFlags.STDIN_PIPE | SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            monitor_process.begin();
            read_stream.begin();
        } catch (Error e) { 
            disconnect_vpn(); 
        }
    }

    private async void monitor_process() {
        try { if (process != null) yield process.wait_async();
        } catch (Error e) {}
        Idle.add(() => { if ((is_connected || is_connecting) && !is_disconnecting) disconnect_vpn(); return false; });
    }

    private async void read_stream() {
        if (process == null) return;
        read_pipe.begin(process.get_stdout_pipe(), "STDOUT");
        read_pipe.begin(process.get_stderr_pipe(), "STDERR");
    }

    private async void read_pipe(InputStream pipe, string source) {
        uint8[] buffer = new uint8[256];
        try {
            while (true) {
                ssize_t n = yield pipe.read_async(buffer, Priority.DEFAULT, null);
                if (n <= 0) break;
                if (is_disconnecting) continue;
                
                string chunk = (string) buffer[0:n]; 
                process_incoming_data(chunk);
            }
        } catch (Error e) {}
    }

    private void process_incoming_data(string data) {
        output_buffer.append(data);
        string current = output_buffer.str.down();

        if (!sudo_password_sent && "[sudo]" in current && "password" in current) {
            write_to_proc(config.sudo + "\n" + config.pin + "\n");
            sudo_password_sent = true;
            output_buffer.truncate(0);
            return;
        }

        if ("cstp connected" in current || "got connect response" in current) {
            if (!is_connected) {
                is_connected = true;
                is_connecting = false;
                output_buffer.truncate(0);
                Idle.add(() => {
                    set_connected_state(true);
                    send_notification("VPN Connected", "Secure tunnel established successfully.");
                    return false;
                });
            }
            return;
        }

        if (is_connected) return;
        if ("response:" in current || "token:" in current) {
            if (!is_verifying_sms && !is_waiting_sms && !is_connected) {
                is_waiting_sms = true;
                output_buffer.truncate(0); 
                Idle.add(() => { ask_sms_custom(); return false; });
            }
        }
    }

    private void write_to_proc(string t) {
        try { if (process != null) process.get_stdin_pipe().write_all(t.data, null);
        } catch (Error e) {}
    }

    public void disconnect_vpn() {
        is_disconnecting = true;
        if (is_connected) send_notification("VPN Disconnected", "Session terminated.");
        is_connected = false; is_connecting = false;
        try {
            string cmd = "echo '" + config.sudo + "' | sudo -S pkill openconnect";
            Process.spawn_command_line_async("sh -c \"" + cmd + "\"");
        } catch (Error e) {}
        if (process != null) { process.force_exit();
        process = null; }
        set_connected_state(false);
        Timeout.add(1000, () => { is_disconnecting = false; return false; });
    }

    private void ask_sms_custom() {
        var win = new Adw.Window();
        win.title = "Authentication"; 
        win.modal = true; 
        win.set_default_size(320, -1);
        
        var vbox = new Box(Orientation.VERTICAL, 15); 
        vbox.margin_top = 25; vbox.margin_bottom = 25;
        vbox.margin_start = 25; vbox.margin_end = 25;

        var icon = new Image.from_icon_name("dialog-password-symbolic");
        icon.set_pixel_size(48);
        vbox.append(icon);
        
        var label = new Label("Token Code:");
        label.add_css_class("title-3");
        vbox.append(label);
        
        var entry = new Entry();
        entry.set_placeholder_text("Code");
        entry.set_alignment(0.5f);
        entry.activates_default = true;
        vbox.append(entry); 
        
        var btn_box = new Box(Orientation.HORIZONTAL, 15);
        btn_box.halign = Align.CENTER;
        btn_box.margin_top = 10;
        
        var btn_cancel = new Button.with_label("Cancel"); 
        btn_cancel.add_css_class("destructive-action");
        btn_cancel.add_css_class("pill");

        var btn_ok = new Button.with_label("Verify"); 
        btn_ok.add_css_class("suggested-action");
        btn_ok.add_css_class("pill");
        btn_ok.set_receives_default(true);
        
        btn_box.append(btn_cancel);
        btn_box.append(btn_ok);
        vbox.append(btn_box);
        
        btn_ok.clicked.connect(() => { 
            write_to_proc(entry.get_text() + "\n"); 
            is_waiting_sms = false; 
            is_verifying_sms = true; 
            win.close(); 
        });

        btn_cancel.clicked.connect(() => {
            write_to_proc("\n");
            try {
                string cmd = "echo '" + config.sudo + "' | sudo -S pkill -9 openconnect";
                Process.spawn_command_line_async("sh -c \"" + cmd + "\"");
            } catch (Error e) {}
            disconnect_vpn();
            is_waiting_sms = false;
            win.close();
        });
        
        win.set_content(vbox); 
        win.set_default_widget(btn_ok);
        win.present();
        entry.grab_focus();
    }

    private void open_settings() {
        var win = new Adw.Window();
        win.title = "Settings"; 
        win.modal = true;
        win.set_default_size(350, -1);

        var group = new Adw.PreferencesGroup(); 
        group.margin_top = 20; group.margin_bottom = 20;
        group.margin_start = 20; group.margin_end = 20;
        
        var h = new Adw.EntryRow(); h.title = "Host"; h.text = config.host;
        var u = new Adw.EntryRow(); u.title = "User"; u.text = config.user;
        var p = new Adw.PasswordEntryRow(); p.title = "Password/PIN";
        p.text = config.pin;
        var s = new Adw.PasswordEntryRow(); s.title = "Linux Pass"; s.text = config.sudo;
        
        group.add(h); group.add(u); group.add(p); group.add(s);
        var save = new Button.with_label("Save"); 
        save.add_css_class("suggested-action");
        save.add_css_class("pill");
        save.halign = Align.CENTER;
        save.margin_bottom = 24;
        save.clicked.connect(() => { 
            config.host = h.text; 
            config.user = u.text; 
            config.pin = p.text; 
            config.sudo = s.text; 
            save_config(); 
            win.close(); 
        });
        var b = new Box(Orientation.VERTICAL, 0); 
        b.append(new Adw.HeaderBar()); 
        b.append(group); 
        b.append(save);
        
        win.set_content(b); 
        win.present();
    }

    private void load_config() {
        config = new VpnConfig();
        if (FileUtils.test(config_path, FileTest.EXISTS)) {
            try {
                string content;
                FileUtils.get_contents(config_path, out content);
                var obj = new Parser(); obj.load_from_data(content);
                var root = obj.get_root().get_object();
                config.host = root.get_string_member("host"); config.user = root.get_string_member("user");
                config.pin = root.get_string_member("pin"); config.sudo = root.get_string_member("sudo");
            } catch (Error e) {}
        } else {
            Idle.add(() => { open_settings(); return false; });
        }
    }

    private void save_config() {
        var root = new Json.Object();
        root.set_string_member("host", config.host); root.set_string_member("user", config.user);
        root.set_string_member("pin", config.pin); root.set_string_member("sudo", config.sudo);
        var gen = new Generator(); gen.set_root(new Json.Node.alloc().init_object(root));
        try { FileUtils.set_contents(config_path, gen.to_data(null));
        } catch (Error e) {}
    }
}

int main(string[] args) {
    var app = new Adw.Application("io.github.izsakirobi.booconnect", ApplicationFlags.FLAGS_NONE);
    app.activate.connect(() => { new BooConnectWindow(app).present(); });
    return app.run(args);
}


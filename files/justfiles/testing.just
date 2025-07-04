# Toggle GNOME Thumbnailer
toggle-gnome-thumbnailer-testing:
    #!/usr/bin/bash
    set -euo pipefail
    GSETTING="org.gnome.desktop.thumbnailers disable-all"
    if $(command -p gsettings get $GSETTING); then
      command -p gsettings set $GSETTING false
      echo "The GNOME thumbnailer is now enabled"
    else
      command -p gsettings set $GSETTING true
      echo "The GNOME thumbnailer is now disabled"
    fi

# Harden Flatpaks further by disabling all permissions by default and rejecting known arbitrary DBus names, applies only to the current user
flatpak-permissions-lockdown-testing:
    #!/usr/bin/bash
    kCommand="flatpak override --user"
    kSharePermissions=("network" "ipc")
    kSocketPermissions=("inherit-wayland-socket" "gpg-agent" "cups" "pcsc" "ssh-auth" "system-bus" "session-bus" "pulseaudio" "fallback-x11" "x11")
    kDevicePermissions=("all" "shm" "kvm" "input" "usb")
    kFeaturePermissions=("per-app-dev-shm" "canbus" "bluetooth" "multiarch" "devel")
    kFilesystemPermissions=("home" "host-etc" "host")
    kDangerousFilesystemPermissions=("~/.bashrc" "~/.bash_profile" "/home" "/var/home" "/var" "/media" "/run/media" "/run" "/mnt")
    kKnownSessionBusNames=("org.xfce.ScreenSaver" "org.mate.ScreenSaver" "org.cinnamon.ScreenSaver" "org.gnome.ScreenSaver" "org.kde.kwalletd6" "org.gnome.Mutter.IdleMonitor.*" "org.gnome.ControlCenter" "org.gnome.Settings" "org.gnome.SettingsDaemon.MediaKeys" "org.gnome.SessionManager" "org.gnome.Shell.Screenshot" "org.kde.kiod5" "org.kde.kwin.Screenshot" "org.kde.JobViewServer" "org.gtk.vfs.*" "org.freedesktop.secrets" "org.kde.kconfig.notify" "org.kde.kpasswdserver" "org.kde.*" "org.kde.StatusNotifierWatcher" "org.kde.kded6" "org.kde.kpasswdserver6" "org.kde.kiod6" "com.canonical.Unity" "org.freedesktop.Notifications" "org.freedesktop.FileManager1" "org.freedesktop.impl.portal.PermissionStore" "org.freedesktop.Flatpak" "com.canonical.AppMenu.Registrar" "org.kde.KGlobalSettings" "org.kde.kded5" "com.canonical.Unity.LauncherEntry" "org.kde.kwalletd5" "org.gnome.SettingsDaemon" "org.a11y.Bus" "com.canonical.indicator.application" "org.freedesktop.ScreenSaver" "ca.desrt.dconf" "org.freedesktop.PowerManagement" "org.gnome.Software" "org.freedesktop.Tracker3.Writeback" "io.missioncenter.MissionCenter.Gatherer")
    kKnownSystemBusNames=("org.bluez" "org.freedesktop.home1" "org.freedesktop.hostname1" "org.freedesktop.import1" "org.freedesktop.locale1" "org.freedesktop.LogControl1" "org.freedesktop.machine1" "org.freedesktop.network1" "org.freedesktop.oom1" "org.freedesktop.portable1" "org.freedesktop.resolve1" "org.freedesktop.sysupdate1" "org.freedesktop.timesync1" "org.freedesktop.timedate1" "org.freedesktop.systemd1" "org.freedesktop.Avahi" "org.freedesktop.Avahi.*" "org.freedesktop.login1" "org.freedesktop.NetworkManager" "org.freedesktop.UPower" "org.freedesktop.UDisks2" "org.freedesktop.fwupd")
    kFlatsealNameAccess=("org.gnome.Software" "org.freedesktop.impl.portal.PermissionStore")
    kWarehouseNameAccess=("org.freedesktop.Flatpak")
    confirmation=""

    echo "This will configure flatpak to automatically reject most permissions (with the exception of the Wayland socket and the Dri device, since these are commonly used and ensure at the very least most apps will work without crashing)."
    echo "This will also grant Flatseal and Warehouse access to certain permissions to allow them to operate and make reconfiguring much easier."
    echo "NOTE: This will break just about all Flatpaks by default, it is ON YOU to configure them to work with this configuration."
    echo "NOTE 2: This DOES NOT enable hardened_malloc, use the harden-flatpak ujust command."
    echo ""
    read -rp "Would you like to proceed? [y/N] " confirmation
    if [[ "$confirmation" == [Yy]* ]]; then
        echo "-- Share Permissions --"
        for i in "${kSharePermissions[@]}"; do
            echo "	Rejecting $i..."
            $kCommand --unshare="$i"
        done
        echo ""
        echo "-- Socket Permissions --"
        for i in "${kSocketPermissions[@]}"; do
            echo "	Rejecting $i..."
            $kCommand --nosocket="$i"
        done
        echo ""
        echo "-- Device Permissions --"
        for i in "${kDevicePermissions[@]}"; do
            echo "	Rejecting $i..."
            $kCommand --nodevice="$i"
        done
        echo ""
        echo "-- Feature Permissions --"
        for i in "${kFeaturePermissions[@]}"; do
            echo "	Rejecting $i..."
            $kCommand --disallow="$i"
        done
        echo ""
        echo "-- Filesystem Permissions --"
        for i in "${kFilesystemPermissions[@]}"; do
            echo "	Rejecting $i..."
            $kCommand --nofilesystem="$i"
        done
        echo ""
        echo "-- Dangerous Filesystem Permissions --"
        echo "Note: This is a VERY flawed implementation but it does cover a few blatant sandbox escape methods (such as the .bashrc escape or mounted drive access)"
        echo "It is not possible to cover all files since each file can be requested manually and therefore must be rejected manually"
        for i in "${kDangerousFilesystemPermissions[@]}"; do
            echo "	Rejecting $i..."
            $kCommand --nofilesystem="$i"
        done
        echo ""
        echo "NOTE: The next 2 lockdowns are NOT complete and only cover a list of known names, this can be expanded at any time"
        echo "-- Session Bus Name Access --"
        for i in "${kKnownSessionBusNames[@]}"; do
            echo "	Rejecting $i..."
            $kCommand --no-talk-name="$i"
        done
        echo ""
        echo "-- System Bus Name Access --"
        for i in "${kKnownSystemBusNames[@]}"; do
            echo "	Rejecting $i..."
            $kCommand --system-no-talk-name="$i"
        done
        echo ""
        echo "-- Persistent Filesystem Grant --"
        echo "Note: This is to unbreak many Flatpaks by allowing the app to store persistent data in their own, isolated home directory without accessing the user's"
        echo "	Granting access to persistent home..."
        $kCommand --persist=.
        echo ""
        echo "-- Granting Access to Common Permissions --"
        echo "Note: This will grant all apps access to some permissions to ensure most apps work by default, this also encourages the use of these permissions instead of their alternatives"
        echo "	Granting access to Wayland and hardware acceleration..."
        $kCommand --socket=wayland --device=dri
        echo ""
        echo "-- Granting Flatseal Access to Bus Names --"
        for i in "${kFlatsealNameAccess[@]}"; do
            echo "	Granting $i..."
            $kCommand --talk-name="$i" com.github.tchx84.Flatseal
        done
        echo ""
        echo "-- Granting Warehouse Access to Bus Names --"
        for i in "${kWarehouseNameAccess[@]}"; do
            echo "	Granting $i..."
            $kCommand --talk-name="$i" io.github.flattool.Warehouse
        done
        echo ""
        echo "Done"
    fi

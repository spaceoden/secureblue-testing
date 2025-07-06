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

# Toggle bash environment lockdown (mitigates LD_PRELOAD attacks). Use skip_approval to bypass initial prompt, and apply_for_all_users to bypass secondary prompt.
toggle-bash-environment-lockdown-testing skip_approval="false" apply_for_all_users="prompt":
    #!/bin/run0 /bin/bash
    set -euo pipefail
    source /usr/lib/ujust/libformatting.sh

    # The below function fetches the minimium and maximium UIDS as configured in /etc/login.defs.
    # Any UIDs within this change are true user ids rather than system agents, and therefore
    # should be locked down. The user_string variable uses this fetched UID range to find all
    # existing users and their home directory along with formatting this data for later use.
    # The IFS line simply converts this data into a bash array.
    function user_list_lookup() {
        uid_min="$(grep -Po '^\s*UID_MIN\s+\K\d+' /etc/login.defs)"
        uid_max="$(grep -Po '^\s*UID_MAX\s+\K\d+' /etc/login.defs)"
        user_string="$(getent passwd | awk -F':' -v max="$uid_max" -v min="$uid_min" 'max >= $3 && $3 >= min {print $1}' | tr '\n' ',' | sed 's/,*$//')"
        IFS=',' read -ra user_list <<< "$user_string"
    }

    # $SUDO_USER is the user who started the script instead of whichever authorized it via polkit
    # or the root home. From there this $USER_HOME uses getent to lookup their home directory to
    # later check if they have an existing .bashrc file.
    user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    if lsattr "$user_home/.bashrc" 2>/dev/null | awk '{print $1}' | grep -q 'i'; then
        pending_status="unlocked"
    else
        pending_status="locked"
    fi

    # Below variable is created to only call date once and use the same time across the script
    # despite execution time.
    current_time="$(date | tr ' ' '_')"

    if [[ "$pending_status" == "locked" ]]; then
        echo "${bold}WARNING${unbold} This will change your ~/.bashrc, ~/.bash_profile, ~/.config/bash_completion, ~/.profile, ~/.bash_logout, ~/.bash_login, ~/.bashrc.d/, and ~/.config/environment.d/"
        echo "This is needed to ensure the mitigation (see LD_PRELOAD attacks) is effective."
        echo "This script will create backups of the old versions in ~/bash_env_files/$current_time."
    else
        echo "${bold}WARNING${unbold} .bashrc, .bash_profile, and more will be unlocked and made editable by non-root users. This represents a security risk (see LD_PRELOAD attacks)"
    fi

    # shellcheck disable=SC2050
    if [[ "{{ skip_approval }}" == "false" ]]; then
        echo "Do you understand?"
        echo 'Please type in "YES I UNDERSTAND" and press enter'
        read -r accept
        if [[ "$accept" != "YES I UNDERSTAND" ]]; then
            exit
        fi
    elif [[ "{{ skip_approval }}" != "true" ]]; then
        echo 'Invalid skip_approval arguement, only "true", "false", or empty allowed.'
        exit
    fi

    # shellcheck disable=SC2050
    if [[ "{{ apply_for_all_users }}" == "prompt" ]]; then
        user_list_lookup
        echo "Do you want this change to apply to ${bold}all${unbold} users (${user_list[*]})? [y/N]"
        echo "Otherwise, it will only apply to the user who launched this script ($SUDO_USER)."
        read -r reply
        if [[ "$reply" != [yY]* ]]; then
            user_list=("$SUDO_USER")
        fi
    elif [[ "{{ apply_for_all_users }}" == "false" ]]; then
        user_list=("$SUDO_USER")
    elif [[ "{{ apply_for_all_users }}" == "true" ]]; then
        user_list_lookup
    else
        echo 'Invalid apply_for_all_users arguement, only "true", "false", or empty allowed.'
        exit
    fi

    for user in "${user_list[@]}"; do
        echo "Applying for user: $user"
        user_home="$(getent passwd "$user" | awk -F':' '{ print $6}')"
        [ -d "$user_home" ] || { echo "Variable \$user_home for $user is somehow empty (check your getent passwd entries)"; echo "safely exiting."; exit 1; }

        BASH_ENV_FILES=(
            "$user_home/.bashrc"
            "$user_home/.bash_profile"
            "$user_home/.config/bash_completion"
            "$user_home/.profile"
            "$user_home/.bash_logout"
            "$user_home/.bash_login"
            "$user_home/.bashrc.d/"
            "$user_home/.config/environment.d/"
            "$user_home/.config/fish/"
        )

        # Purpose of the below block is to actually lock or unlock the current selected user
        # across the configured BASH_ENV_FILES
        #    If the script is locking:
        #        to copy the old env files and directories to folder with the time appended to its name
        #        remove immutability (to allow the script to overwrite any existing immutable environment files)
        #        create default or blank copies (deleting the old versions)
        #        add immutability

        if [[ "$pending_status" == "locked" ]]; then
            backup_dest="$user_home/bash_env_files/$current_time/"
            mkdir -p "$backup_dest"

            for file in "${BASH_ENV_FILES[@]}"; do
                # skel_file converts "$user_home/.bashrc" to ".bashrc"
                skel_file="${file#"${user_home}/"}"
                if [ ! -f "$file" ] && [ ! -d "$file" ] && [ -e "$file" ]; then
                    echo "Special file detected on absolute filepath ($file) from BASH_ENV_FILES. It will not be modified."
                elif [ -f "$file" ]; then
                    chattr -i "$file"
                    rsync -a --mkpath "$file" "$backup_dest$skel_file"
                    rm "$file"
                elif [ -d "$file" ]; then
                    chattr -R -i "$file"
                    rsync -a --mkpath "$file" "$backup_dest$skel_file"
                    rm -r "$file"
                fi

                # Now we create new empty/default files and directories
                if [ "${file: -1}" == "/" ]; then
                    install -D -d -o "$user" -g "$user" -m 700 "$file"
                    chattr +i -R "$file"
                elif [ -f "/etc/skel/$skel_file" ]; then
                    install -D -o "$user" -g "$user" -m 700 "/etc/skel/$skel_file" "$file"
                    chattr +i "$file"
                else
                    install -D -o "$user" -g "$user" -m 700 /dev/null "$file"
                    chattr +i "$file"
                fi
            done

            chmod -R 700 "$user_home/bash_env_files"
            chown -R "$user:" "$user_home/bash_env_files"
        else
            for file in "${BASH_ENV_FILES[@]}"; do
                if [ ! -f "$file" ] && [ ! -d "$file" ] && [ -e "$file" ]; then
                    echo "Special file detected on absolute filepath ($file) from BASH_ENV_FILES. It will not be modified."
                elif [ -f "$file" ]; then
                    chattr -i "$file"
                elif [ -d "$file" ]; then
                    chattr -R -i "$file"
                fi
            done
        fi
    done

    echo "${user_list[@]}" "$pending_status."
    echo "${bold}NOTE${unbold}: until a reboot, any process with an open file descriptor will continue to have the access they had before this script was run."

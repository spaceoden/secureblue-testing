# Toggle GNOME Thumbnailer
toggle-gnome-thumbnailer-testing:
    #!/usr/bin/bash
    set -euo pipefail
    GSETTING="$(command -p gsettings get org.gnome.desktop.thumbnailers disable-all)"
    if [[ "$GSETTING" == "true" ]]; then
      command -p gsettings set org.gnome.desktop.thumbnailers disable-all false
      echo "The GNOME thumbnailer is now enabled"
    else
      command -p gsettings set org.gnome.desktop.thumbnailers disable-all true
      echo "The GNOME thumbnailer is now disabled"
    fi

#Toggle KDE Thumbnailer
toggle-kde-thumbnailer-testing:
    #!/usr/bin/bash
    set -euo pipefail
    echo 'wip'

# Toggle support for using GNOME user extensions
toggle-gnome-extensions-testing:
    #!/usr/bin/bash
    set -euo pipefail
    GSETTING="$(command -p gsettings get org.gnome.shell allow-extension-installation)"
    if [[ "${GSETTING}" == "false" ]]; then
      command -p gsettings set org.gnome.shell allow-extension-installation true
      echo "Support for GNOME user extensions is now enabled"
    elif [[ "${GSETTING}" == "true" ]]; then
      command -p gsettings set org.gnome.shell allow-extension-installation false
      echo "Support for GNOME user extensions is now disabled"
    fi

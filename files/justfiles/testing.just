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

# Toggle GNOME Thumbnailer
toggle-gnome-thumbnailer-testing:
    #!/usr/bin/bash
    set -euo pipefail
    GSETTING="org.gnome.desktop.thumbnailers disable-all"
    if [[ "$(command -p gsettings get $GSETTING)" == "true" ]]; then
      command -p gsettings set $GSETTING false
      echo "The GNOME thumbnailer is now enabled"
    else
      command -p gsettings set $GSETTING true
      echo "The GNOME thumbnailer is now disabled"
    fi

#Toggle KDE Thumbnailer
toggle-kde-thumbnailer-testing:
    #!/usr/bin/bash
    set -euo pipefail
    echo 'wip'

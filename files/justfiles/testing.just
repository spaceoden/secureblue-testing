# Toggle GNOME Thumbnailer
toggle-gnome-thumbnailer:
    #!/usr/bin/bash
    set -euo pipefail
    GSETTING="org.gnome.desktop.thumbnailers disable-all"
    if $(gsettings get $GSETTING); then
      gsettings set $GSETTING false
      echo "The GNOME thumbnailer is now enabled"
    else
      gsettings set $GSETTING true
      echo "The GNOME thumbnailer is now disabled"
    fi

# Toggle support for using GNOME user extensions
toggle-gnome-extensions-testing:
    #!/usr/bin/bash
    set -euo pipefail
    GSETTING="org.gnome.shell allow-extension-installation"
    if $(gsettings get $GSETTING); then
      gsettings reset $GSETTING
      echo "Support for GNOME user extensions is now disabled"
    else
      gsettings set $GSETTING true
      echo "Support for GNOME user extensions is now enabled"
    fi

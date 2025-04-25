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

# Add additional boot parameters for hardening (requires reboot)
set-kargs-hardening-testing MODE="":
    #!/usr/bin/bash
    mode="{{ MODE }}"
    if [[ "$mode" =~ "'" ]]; then
        echo 'WARNING: Single quotes in the argument are forbidden to avoid command execution'
        exit 1
    fi
    if [[ "$mode" == "non-interactive" ]]; then
        IAEMU_NO="--append-if-missing=ia32_emulation=0"
    else
        read -rp "Do you need support for 32-bit processes/syscalls? (This is mostly used by legacy software, with some exceptions, such as Steam) [y/N]: " YES
        if [[ "$YES" == [Yy]* ]]; then
            echo "Keeping 32-bit support."
        else
            IAEMU_NO="--append-if-missing=ia32_emulation=0"
            echo "Disabling 32-bit support, for the next boot."
        fi
        read -rp "Do you want to force disable Simultaneous Multithreading (SMT) / Hyperthreading? (This can cause a reduction in the performance of certain tasks in favor of security) (Note that in most hardware SMT will be disabled anyways to mitigate a known vulnerability, this turns it off on all hardware regardless) [y/N]: " YES
        if [[ "$YES" == [Yy]* ]]; then
            NOSMT_YES="--append-if-missing=nosmt=force"
            echo "Force disabling SMT/Hyperthreading."
        else
            echo "Not force disabling SMT/Hyperthreading."
        fi
        read -rp "Would you like to set additional (unstable) hardening kargs? (Warning: Setting these kargs may lead to boot or stability issues on some hardware.) [y/N]: " YES
        if [[ "$YES" == [Yy]* ]]; then
        UNSTABLE_YES="--append-if-missing=efi=disable_early_pci_dma \
            --append-if-missing=gather_data_sampling=force \
            --append-if-missing=amd_iommu=force_isolation \
            --append-if-missing=debugfs=off"
            echo "Setting unstable hardening kargs."
        else
            echo "Not setting unstable hardening kargs."
        fi
    fi
    echo "Applying boot parameters..."
    rpm-ostree kargs \
      ${UNSTABLE_YES:+$UNSTABLE_YES} ${IAEMU_NO:+$IAEMU_NO} ${NOSMT_YES:+$NOSMT_YES} \
      --append-if-missing=init_on_alloc=1 \
      --append-if-missing=init_on_free=1 \
      --append-if-missing=slab_nomerge \
      --append-if-missing=page_alloc.shuffle=1 \
      --append-if-missing=randomize_kstack_offset=on \
      --append-if-missing=vsyscall=none \
      --append-if-missing=lockdown=confidentiality \
      --append-if-missing=random.trust_cpu=off \
      --append-if-missing=random.trust_bootloader=off \
      --append-if-missing=iommu=force \
      --append-if-missing=intel_iommu=on \
      --append-if-missing=iommu.passthrough=0 \
      --append-if-missing=iommu.strict=1 \
      --append-if-missing=pti=on \
      --append-if-missing=module.sig_enforce=1 \
      --append-if-missing=mitigations=auto,nosmt \
      --append-if-missing=spectre_v2=on \
      --append-if-missing=spec_store_bypass_disable=on \
      --append-if-missing=l1d_flush=on \
      --append-if-missing=l1tf=full,force \
      --append-if-missing=kvm-intel.vmentry_l1d_flush=always
    echo "Hardening kargs applied."

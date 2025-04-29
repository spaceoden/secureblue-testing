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

# Toggle MAC Randomization
toggle-mac-randomization-test:
    #! /bin/run0 /bin/bash
    RAND_MAC_FILE="/etc/NetworkManager/conf.d/rand_mac.conf"

    if test -e $RAND_MAC_FILE; then
        rm -f $RAND_MAC_FILE
        echo "MAC randomization disabled."
        systemctl restart NetworkManager
    else
        echo "MAC randomization can be stable (persisting the same random MAC per access point across disconnects/reboots),"
        echo "or it can be randomized per-connection (every time it connects to the same access point it uses a new MAC)."
        randomization_choice=""
        read -rp "Do you want to use per-connection Wi-Fi MAC address randomization? [y/N] " randomization_choice

        cp /usr$RAND_MAC_FILE $RAND_MAC_FILE
        if [[ "$randomization_choice" == [Yy]* ]]; then
            sed -i 's/wifi.cloned-mac-address=stable/wifi.cloned-mac-address=random/' $RAND_MAC_FILE
            echo "Per-connection MAC randomization enabled."
        else
            echo "Stable MAC randomization enabled."
        fi
        systemctl restart NetworkManager
    fi

# setup system DNS resolution
dns-selector-testing:
    #! /bin/run0 /bin/bash
    # constants
    readonly resolved_conf="/etc/systemd/resolved.conf.d/10-securedns.conf"
    readonly policy_file="/etc/trivalent/policies/managed/10-securedns-browser.json"
    mkdir -p /etc/systemd/resolved.conf.d/
    mkdir -p /etc/trivalent/policies/managed/
    # variables
    valid_input="0"
    resolver_selection=""
    resolver_subselection=""
    resolver_has_second_ip=""
    resolver_supports_ipv6=""
    resolver_dnssec=""
    resolver_ipv4_address=""
    resolver_ipv4_address_2=""
    resolver_ipv6_address=""
    resolver_ipv6_address_2=""
    resolver_hostname=""
    resolver_https_address=""
    set_browser_policy=""
    opportunistic=""
    clear_state=""

    echo "Below will be some options to set the DNS resolver for systemd-resolved."
    echo "All resolvers support DNS-over-TLS (DoT) or DNS-over-QUIC (DoQ), DNS-over-HTTPS (DoH), and DNSSEC."
    echo "Please select which DNS resolver you would like to set:"
    echo "    0) Network Default - do nothing, rely purely on the network for resolution"
    echo "    1) Opportunistic Upgrade - try to upgrade to DoT (encrypted DNS) resolution and/or DNSSEC enforcement (this configuration may break networking)"
    echo "    2) Control D - has content filtering, anycast"
    echo "    3) Mullvad - has content filtering, anycast"
    echo "    4) Cloudflare - very fast with some data collection, anycast"
    echo "    5) DNSForge - powerful filtering but can be very slow"
    echo "    6) Custom Resolver - use a custom resolver (must support DoT/DoQ, ideally also supports DNSSEC, DoH support is also required to set a browser policy should that be desired)"
    while [[ "$valid_input" == "0" ]]; do
        read -rp "Selection [0-6]: " resolver_selection
        if [[ "$resolver_selection" == [0123456]* ]]; then
            valid_input="1"
        else
            echo "That is not a valid selection."
        fi
    done
    valid_input="0"

    echo "" # blank space
    case "$resolver_selection" in
        0)
            clear_state="1"
            echo "Resetting resolved to default state."
            ;;
        1)
            clear_state="1"
            opportunistic="1"
            ;;
        2)
            resolver_has_second_ip="y"
            resolver_supports_ipv6="y"
            resolver_dnssec="y"
            echo "Setting resolver Control D."
            echo "What content would you like to filter:"
            echo "    0) No filtering"
            echo "    1) Malware: Malware filtering"
            echo "    2) Standard: Malware + ad and tracker filtering"
            echo "    3) Social: Standard + social media filtering"
            echo "    4) Family: Social + adult content filtering (also enables safe search in major search engines)"
            while [[ "$valid_input" == "0" ]]; do
                read -rp "Selection [0-4]: " resolver_subselection
                if [[ "$resolver_subselection" == [01234]* ]]; then
                    valid_input="1"
                else
                    echo "That is not a valid selection."
                fi
            done
            valid_input="0"
            case "$resolver_subselection" in
                # Source for the IP addresses and hostnames/URLs: https://controld.com/free-dns
                0)
                    resolver_ipv4_address="76.76.2.0"
                    resolver_ipv4_address_2="76.76.10.0"
                    resolver_ipv6_address="2606:1a40::"
                    resolver_ipv6_address_2="2606:1a40:1::"
                    resolver_hostname="p0.freedns.controld.com"
                    resolver_https_address="https://freedns.controld.com/p0"
                    ;;
                1)
                    resolver_ipv4_address="76.76.2.1"
                    resolver_ipv4_address_2="76.76.10.1"
                    resolver_ipv6_address="2606:1a40::1"
                    resolver_ipv6_address_2="2606:1a40:1::1"
                    resolver_hostname="p1.freedns.controld.com"
                    resolver_https_address="https://freedns.controld.com/p1"
                    ;;
                2)
                    resolver_ipv4_address="76.76.2.2"
                    resolver_ipv4_address_2="76.76.10.2"
                    resolver_ipv6_address="2606:1a40::2"
                    resolver_ipv6_address_2="2606:1a40:1::2"
                    resolver_hostname="p2.freedns.controld.com"
                    resolver_https_address="https://freedns.controld.com/p2"
                    ;;
                3)
                    resolver_ipv4_address="76.76.2.3"
                    resolver_ipv4_address_2="76.76.10.3"
                    resolver_ipv6_address="2606:1a40::3"
                    resolver_ipv6_address_2="2606:1a40:1::3"
                    resolver_hostname="p3.freedns.controld.com"
                    resolver_https_address="https://freedns.controld.com/p3"
                    ;;
                4)
                    resolver_ipv4_address="76.76.2.4"
                    resolver_ipv4_address_2="76.76.10.4"
                    resolver_ipv6_address="2606:1a40::4"
                    resolver_ipv6_address_2="2606:1a40:1::4"
                    resolver_hostname="family.freedns.controld.com"
                    resolver_https_address="https://freedns.controld.com/family"
                    ;;
            esac
            ;;
        3)
            resolver_has_second_ip="n"
            resolver_supports_ipv6="y"
            resolver_dnssec="y"
            echo "Setting resolver Mullvad."
            echo "What content would you like to filter:"
            echo "    0) No filtering"
            echo "    1) Standard: Ad and tracker filtering"
            echo "    2) Base: Standard + malware filtering"
            echo "    3) Extended: Base + social media filtering"
            echo "    4) Family: Base + gambling and adult content filtering"
            echo "    5) All: Family + social media filtering"
            while [[ "$valid_input" == "0" ]]; do
                read -rp "Selection [0-5]: " resolver_subselection
                if [[ "$resolver_subselection" == [012345]* ]]; then
                    valid_input="1"
                else
                    echo "That is not a valid selection."
                fi
            done
            valid_input="0"
            case "$resolver_subselection" in
                # Source for the IP addresses and hostnames/URLs: https://mullvad.net/en/help/dns-over-https-and-dns-over-tls
                0)
                    resolver_ipv4_address="194.242.2.2"
                    resolver_ipv6_address="2a07:e340::2"
                    resolver_hostname="dns.mullvad.net"
                    ;;
                1)
                    resolver_ipv4_address="194.242.2.3"
                    resolver_ipv6_address="2a07:e340::3"
                    resolver_hostname="adblock.dns.mullvad.net"
                    ;;
                2)
                    resolver_ipv4_address="194.242.2.4"
                    resolver_ipv6_address="2a07:e340::4"
                    resolver_hostname="base.dns.mullvad.net"
                    ;;
                3)
                    resolver_ipv4_address="194.242.2.5"
                    resolver_ipv6_address="2a07:e340::5"
                    resolver_hostname="extended.dns.mullvad.net"
                    ;;
                4)
                    resolver_ipv4_address="194.242.2.6"
                    resolver_ipv6_address="2a07:e340::6"
                    resolver_hostname="family.dns.mullvad.net"
                    ;;
                5)
                    resolver_ipv4_address="194.242.2.9"
                    resolver_ipv6_address="2a07:e340::9"
                    resolver_hostname="all.dns.mullvad.net"
                    ;;
            esac
            resolver_https_address="https://$resolver_hostname/dns-query"
            ;;
        4)
            resolver_has_second_ip="y"
            resolver_supports_ipv6="y"
            resolver_dnssec="y"
            echo "Setting resolver Cloudflare. (glory to the cloud)"
            echo "What content would you like to filter:"
            echo "    0) No filtering"
            echo "    1) Security: Malware filtering"
            echo "    2) Family: Security + adult content filtering"
            while [[ "$valid_input" == "0" ]]; do
                read -rp "Selection [0-2]: " resolver_subselection
                if [[ "$resolver_subselection" == [012]* ]]; then
                    valid_input="1"
                else
                    echo "That is not a valid selection."
                fi
            done
            valid_input="0"
            case "$resolver_subselection" in
                # Source for the IP addresses and hostnames/URLs: https://developers.cloudflare.com/1.1.1.1/infrastructure/network-operators/#available-endpoints
                0)
                    resolver_ipv4_address="1.1.1.1"
                    resolver_ipv4_address_2="1.0.0.1"
                    resolver_ipv6_address="2606:4700:4700::1111"
                    resolver_ipv6_address_2="2606:4700:4700::1001"
                    resolver_hostname="cloudflare-dns.com"
                    ;;
                1)
                    resolver_ipv4_address="1.1.1.2"
                    resolver_ipv4_address_2="1.0.0.2"
                    resolver_ipv6_address="2606:4700:4700::1112"
                    resolver_ipv6_address_2="2606:4700:4700::1002"
                    resolver_hostname="security.cloudflare-dns.com"
                    ;;
                2)
                    resolver_ipv4_address="1.1.1.3"
                    resolver_ipv4_address_2="1.0.0.3"
                    resolver_ipv6_address="2606:4700:4700::1113"
                    resolver_ipv6_address_2="2606:4700:4700::1003"
                    resolver_hostname="family.cloudflare-dns.com"
                    ;;
            esac
            resolver_https_address="https://$resolver_hostname/dns-query"
            ;;
        5)
            resolver_has_second_ip="y"
            resolver_supports_ipv6="y"
            resolver_dnssec="y"
            echo "Setting resolver DNSForge."
            echo "What content would you like to filter:"
            echo "    0) Standard: Ad, tracker, and malware filtering"
            echo "    1) Clean: Standard + adult content filtering"
            echo "    2) Hard: Clean + stricter ad, tracker, and malware filtering"
            while [[ "$valid_input" == "0" ]]; do
                read -rp "Selection [0-2]: " resolver_subselection
                if [[ "$resolver_subselection" == [012]* ]]; then
                    valid_input="1"
                else
                    echo "That is not a valid selection."
                fi
            done
            valid_input="0"
            case "$resolver_subselection" in
                # Source for the IP addresses and hostnames/URLs: https://dnsforge.de/#dnsdaten
                0)
                    resolver_ipv4_address="176.9.93.198"
                    resolver_ipv4_address_2="176.9.1.117"
                    resolver_ipv6_address="2a01:4f8:151:34aa::198"
                    resolver_ipv6_address_2="2a01:4f8:141:316d::117"
                    resolver_hostname="dnsforge.de"
                    ;;
                1)
                    resolver_ipv4_address="49.12.223.2"
                    resolver_ipv4_address_2="49.12.43.208"
                    resolver_ipv6_address="2a01:4f8:c17:4fbc::2"
                    resolver_ipv6_address_2="2a01:4f8:c012:ed89::208"
                    resolver_hostname="clean.dnsforge.de"
                    ;;
                2)
                    resolver_ipv4_address="49.12.222.213"
                    resolver_ipv4_address_2="88.198.122.154"
                    resolver_ipv6_address="2a01:4f8:c17:2c61::213"
                    resolver_ipv6_address_2="2a01:4f8:c013:5ec0::154"
                    resolver_hostname="hard.dnsforge.de"
                    ;;
            esac
            resolver_https_address="https://$resolver_hostname/dns-query"
            ;;
        6)
            echo "Setting custom resolver."
            echo "NOTE: If the resolver does not support DoT/DoQ or DNSSEC, this process will not work."
            echo ""
            echo "Please provide the technical information."
            read -rp "Please enter the resolver's IP address (e.g. '1.1.1.2'): " resolver_ipv4_address
            read -rp "Does the resolver provide two distinct IP addresses (e.g. '1.1.1.2' and '1.0.0.2')? [Y/n] " resolver_has_second_ip
            resolver_has_second_ip=${resolver_has_second_ip:-y}
            if [[ "$resolver_has_second_ip" == [Yy]* ]]; then
                read -rp "Please enter the resolver's second IP address: " resolver_ipv4_address_2
            fi
            read -rp "Does the resolver support IPv6 (e.g. '2606:4700:4700::1112')? [Y/n] " resolver_supports_ipv6
            resolver_supports_ipv6=${resolver_supports_ipv6:-y}
            if [[ "$resolver_supports_ipv6" == [Yy]* ]]; then
                read -rp "Please enter the resolver's IPv6 address: " resolver_ipv6_address
                if [[ "$resolver_has_second_ip" == [Yy]* ]]; then
                    read -rp "Please enter the resolver's second IPv6 address: " resolver_ipv6_address_2
                fi
            fi
            read -rp "Please enter the second resolver's hostname (e.g. 'security.cloudflare-dns.com'): " resolver_hostname
            read -rp "Do you want to enable DNSSEC (this can cause networking issues notably in virtual machines, it is recommended if you do not suffer issues)? [Y/n] " resolver_dnssec
            resolver_dnssec=${resolver_dnssec:-y}
            ;;
    esac

    if [[ "$clear_state" == "1" ]]; then
        if [[ -f "$policy_file" ]]; then
            rm $policy_file
            echo "Removed browser policy."
        fi
    fi

    if [[ "$opportunistic" == "1" ]]; then
        cat << EOF > "$resolved_conf"
    [Resolve]
    DNSOverTLS=opportunistic
    DNSSEC=allow-downgrade
    EOF
    elif [[ "$clear_state" == "1" ]]; then
        if [[ -f "$resolved_conf" ]]; then
            rm $resolved_conf
        fi
        echo "Configuration file for resolved removed."
    else
        read -rp "Would you like the resolver to be set in the default browser (Trivalent) via management policy? [y/N] " set_browser_policy
        if [[ "$set_browser_policy" == [Yy]* && "$resolver_selection" == 6 ]]; then
            read -rp "Please enter the second resolver's HTTPS address (e.g. 'https://security.cloudflare-dns.com/dns-query'): " resolver_https_address
        fi

        resolved_conf_dns_string=""
        resolved_conf_dns_string+="DNS="
        resolved_conf_dns_string+=" $resolver_ipv4_address"
        resolved_conf_dns_string+="#$resolver_hostname"
        if [[ "$resolver_has_second_ip" == [Yy]* ]]; then
            resolved_conf_dns_string+=" $resolver_ipv4_address_2"
            resolved_conf_dns_string+="#$resolver_hostname"
        fi
        if [[ "$resolver_supports_ipv6" == [Yy]* ]]; then
            resolved_conf_dns_string+=" $resolver_ipv6_address"
            resolved_conf_dns_string+="#$resolver_hostname"
            if [[ "$resolver_has_second_ip" == [Yy]* ]]; then
                resolved_conf_dns_string+=" $resolver_ipv6_address_2"
                resolved_conf_dns_string+="#$resolver_hostname"
            fi
        fi

        resolved_conf_dnssec_string=""
        if [[ "$resolver_dnssec" == [Yy]* ]]; then
            resolved_conf_dnssec_string+="DNSSEC=true"
        fi

        cat << EOF > "$resolved_conf"
    [Resolve]
    DNSOverTLS=true
    $resolved_conf_dns_string
    $resolved_conf_dnssec_string
    EOF
    fi

    systemctl restart systemd-resolved

    echo "Configation for resolved set and service restarted."

    if [[ "$set_browser_policy" != [Yy]* ]]; then
        exit 0
    fi
    cat << EOF > "$policy_file"
    {
        "DnsOverHttpsMode": "secure",
        "DnsOverHttpsTemplates": "$resolver_https_address"
    }
    EOF

    echo "Browser policy set with selected resolver."

#!/bin/sh
# QNByPass 清除 + 改机 脚本
# 用法：/var/jb/usr/bin/qnbypass

B="com.qunar.iphoneclient"
CFG="/var/jb/var/mobile/Library/Preferences/.qnbypass.plist"

case "$1" in
  clear)
    echo "=== 清除去哪儿数据 ==="
    killall -9 QunariPhone_Cook_CM 2>/dev/null
    sleep 1
    for P in /var/jb/var/mobile/Containers/Data/Application/*/.com.apple.mobile_container_manager.metadata.plist; do
      grep -q "$B" "$P" 2>/dev/null && rm -rf "$(dirname "$P")" && echo "Cleared data"
    done
    for P in /var/jb/var/mobile/Containers/Shared/AppGroup/*/.com.apple.mobile_container_manager.metadata.plist; do
      grep -qi qunar "$P" 2>/dev/null && rm -rf "$(dirname "$P")" && echo "Cleared AppGroup"
    done
    rm -f /var/jb/var/Keychains/keychain-2.db* 2>/dev/null
    killall -9 securityd 2>/dev/null
    echo "Done!"
    ;;
    
  modify)
    echo "=== 改机 ==="
    MODELS="iPhone14,4 iPhone14,5 iPhone14,2 iPhone14,3 iPhone13,2"
    set -- $MODELS
    R=$(($RANDOM % $# + 1))
    M=$(eval echo \$$R)
    UUID=$(uuidgen)
    mkdir -p /var/jb/var/mobile/Library/Preferences
    cat > "$CFG" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>enabled</key><true/>
<key>hwMachine</key><string>$M</string>
<key>idfv</key><string>$UUID</string>
</dict></plist>
EOF
    echo "Model: $M"
    echo "IDFV: $UUID"
    echo "Done! Open Qunar to test."
    ;;
    
  status)
    [ -f "$CFG" ] && cat "$CFG" || echo "Not configured"
    ;;
    
  *)
    echo "QNByPass v3.0"
    echo "  qnbypass clear  - Clear all Qunar data"
    echo "  qnbypass modify - Apply device spoofing"
    echo "  qnbypass status - Show current config"
    ;;
esac

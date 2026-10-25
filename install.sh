#!/bin/bash
# The SwiftBar plugin was retired in favour of the native PowerBar.app.
# This stub stays so `powerbar update` and the old one-line installer explain
# that, instead of failing on a missing file.
cat <<'MSG'
The powerbar SwiftBar plugin has been retired. PowerBar is now a native
menu bar app that needs neither SwiftBar nor macmon:
  https://github.com/michielwittkampf/powerbar#readme

To remove the plugin:   powerbar uninstall
To keep the plugin, install its last version (0.4.0):
  curl -fsSL https://raw.githubusercontent.com/michielwittkampf/powerbar/v0.4.0/install.sh | POWERBAR_BRANCH=v0.4.0 bash
MSG
exit 1

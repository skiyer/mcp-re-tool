#!/bin/sh
# Point the MCP server at a read-only toolchain image and prepare the writable
# user directory.
#
# Contract:
#   /opt/toolchain  read-only toolchain image (squashfs / ext4 / ...) holding the
#                   tool's installation tree; the license file lives inside it,
#                   in the program directory
#   $IDAUSR         writable directory for registry / session state
#   /work           writable working directory for samples and databases
set -e

: "${IDADIR:=/opt/toolchain}"
: "${IDAUSR:=/root/.idapro}"
export IDADIR IDAUSR

if [ ! -d "$IDADIR" ]; then
    echo "error: no toolchain mounted at $IDADIR" >&2
    echo "  mount it read-only, e.g.  -v /path/to/ida94.sqfs:/opt/toolchain:ro" >&2
    exit 1
fi

mkdir -p "$IDAUSR"
printf '{"Paths":{"ida-install-dir":"%s"}}' "$IDADIR" > "$IDAUSR/ida-config.json"

# Optional: license injected as its own read-only mount.
if [ -f /license/idapro.hexlic ] && [ ! -f "$IDAUSR/idapro.hexlic" ]; then
    cp /license/idapro.hexlic "$IDAUSR/"
fi

# Accept the EULA once (idempotent). Needs a complete toolchain installation.
if [ ! -f "$IDAUSR/ida.reg" ]; then
    python3 - <<'PY' || echo "warning: could not seed EULA (incomplete toolchain?)" >&2
import idapro, ida_registry
for v in (90, 91, 92, 93, 94):
    ida_registry.reg_write_int(f"EULA {v}", 1)
PY
fi

exec ida-mcp "$@"

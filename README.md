# mcp-re-tool

An MCP server for reverse-engineering toolchains, where the toolchain is a
**read-only disk image mounted at run time**.

The image ships only the MCP server runtime. The (large, licensed) toolchain
stays outside and is mounted into the sandbox when you start it, so the image
stays tiny, publishable and architecture-neutral.

> **This image contains no proprietary binaries or licenses** — only the public
> `ida-mcp` package and its dependencies. You supply your own licensed toolchain
> image at run time.

## Mount contract

| Guest path | Mode | Purpose |
|---|---|---|
| `/opt/toolchain` (`$IDADIR`) | **ro** | Toolchain installation tree (disk image). Must contain the license file in its program directory (`idapro*.hexlic`). |
| `/root/.idapro` (`$IDAUSR`) | **rw** | Registry / EULA / sessions. Must be writable. |
| `/work` | **rw** | Samples and databases. Must be writable — the database is written next to the sample. |

`entrypoint.sh` validates the mount, writes `ida-config.json`, optionally copies
a license from `/license`, seeds the EULA once, then `exec`s the MCP server.

## Build the toolchain image

A single-file filesystem built from *your own* licensed installation:

```bash
# squashfs — recommended: smallest, naturally read-only
mksquashfs /path/to/install-tree toolchain.sqfs \
    -comp zstd -Xcompression-level 22 -b 1M -noappend

# or ext4 — if you want a writable image
truncate -s 1200M toolchain.ext4
mke2fs -t ext4 -F -m 0 -O ^has_journal,^64bit,^resize_inode -N 8192 \
       -d /path/to/install-tree toolchain.ext4
e2fsck -f -y toolchain.ext4 && resize2fs -M toolchain.ext4
```

Put the license **inside the image, in the program directory**, named
`idapro*.hexlic`. The image architecture must match the sandbox
(`x64linux` for amd64, `armlinux` for arm64).

## Run in microsandbox

HTTP transport:

```bash
msb run ghcr.io/skiyer/mcp-re-tool:latest --name mcp-re-tool -d \
  --mount-disk ~/toolchain.sqfs:/opt/toolchain:ro \
  --mount-dir  ~/.mcp-usrdir:/root/.idapro \
  --mount-dir  "$PWD:/work" \
  -p 127.0.0.1:8737:8737 \
  -- http --host 0.0.0.0 --port 8737
```

MCP endpoint: `http://127.0.0.1:8737/mcp`

stdio transport (an agent spawns it directly):

```bash
msb run ghcr.io/skiyer/mcp-re-tool:latest --no-tty \
  --mount-disk ~/toolchain.sqfs:/opt/toolchain:ro \
  --mount-dir  ~/.mcp-usrdir:/root/.idapro \
  --mount-dir  "$PWD:/work" \
  -- stdio --agent=my-agent
```

Notes:

- Host paths must be **real** paths — msb rejects paths that go through a symlink
  (e.g. anything under `/tmp`).
- Published ports bind to `127.0.0.1` by default; add a bind address to expose one.
- The MCP HTTP transport has **no authentication** — keep it on loopback or reach
  it through an SSH tunnel.
- Sandboxes are durable: `msb list`, `msb rm <name>`.

## Sharing one server

One `ida-mcp` process = one shared analysis session. To let several agents share
it, run **one** server sandbox and have the agents connect to it. Do not start a
separate server per sandbox: those are independent sessions, and concurrent
writers of the same database corrupt it.

## Multi-arch

CI builds `linux/amd64` and `linux/arm64` from the same Dockerfile (the image has
no architecture-specific binaries). The **toolchain image** is architecture
specific — mount the matching one.

## License

MIT — see [LICENSE](LICENSE). Covers this repository only; the toolchain you
mount is governed by its own license.

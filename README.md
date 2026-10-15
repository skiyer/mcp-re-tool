# mcp-re-tool

Run an MCP server for reverse-engineering toolchains on top of a **read-only toolchain image mounted at run time**.

The container only ships the MCP server runtime. The (large, proprietary, licensed) toolchain stays outside the image and is bind-mounted read-only when you start the container. This keeps the image tiny, publishable and arch-neutral, while letting you update or swap the toolchain without rebuilding anything.

> **This image contains no proprietary binaries or licenses.** It installs only the public `ida-mcp` PyPI package and its Python dependencies. You supply your own legally licensed toolchain image at run time.

---

## How it works

```text
 host                              container
 ────                              ─────────
 toolchain.sqfs ────(ro)──────────▶ /opt/toolchain   toolchain install tree + license
 usrdir/        ────(rw)──────────▶ /root/.idapro    registry / session state
 work/          ────(rw)──────────▶ /work            samples + databases
                                   ida-mcp :8737     MCP server (stdio / HTTP)
```

The entrypoint:

1. validates that a toolchain is mounted at `$IDADIR` (default `/opt/toolchain`),
2. writes `$IDAUSR/ida-config.json` pointing at it,
3. optionally copies a license from `/license`,
4. seeds the EULA once (idempotent),
5. `exec`s the MCP server.

## Quick start

```bash
docker run --rm -i \
  -v ~/images/ida94-x64.sqfs:/opt/toolchain:ro \
  -v ~/.mcp-usrdir:/root/.idapro \
  -v "$PWD:/work" \
  ghcr.io/skiyer/mcp-re-tool:latest stdio --agent=my-agent
```

HTTP transport (bind to loopback and tunnel, or publish a port):

```bash
docker run --rm -d --name mcp-re-tool \
  -v ~/images/ida94-x64.sqfs:/opt/toolchain:ro \
  -v ~/.mcp-usrdir:/root/.idapro \
  -v "$PWD:/work" -p 8737:8737 \
  ghcr.io/skiyer/mcp-re-tool:latest http --host 0.0.0.0 --port 8737
```

MCP endpoint: `http://127.0.0.1:8737/mcp`.

## Mount contract

| Path | Mode | Purpose |
|---|---|---|
| `/opt/toolchain` (`$IDADIR`) | **ro** | Toolchain installation tree. Must contain the license file in the program directory (`idapro*.hexlic`). |
| `/root/.idapro` (`$IDAUSR`) | **rw** | Registry, EULA, sessions. Must be writable. |
| `/work` | **rw** | Input binaries and generated databases. Must be writable — IDA writes the `.i64/.id0/.id1/...` next to the sample. |
| `/license/idapro.hexlic` | ro | Optional: license injected as its own mount instead of living in the toolchain image. |

Environment: `IDADIR`, `IDAUSR`, `IDA_MCP_STATE_DIR`.

## Building the toolchain image (bring your own)

The toolchain image is a **filesystem image** (a single file) mounted read-only. Any of these work:

- **squashfs** (recommended for read-only toolchains — smallest, kernel-supported):

  ```bash
  mksquashfs /path/to/install-tree toolchain.sqfs \
      -comp zstd -Xcompression-level 22 -b 1M -noappend
  ```

- **ext4** (if you need write access or maximum compatibility):

  ```bash
  truncate -s 1200M toolchain.ext4
  mke2fs -t ext4 -F -m 0 -O ^has_journal,^64bit,^resize_inode -N 8192 \
         -d /path/to/install-tree toolchain.ext4
  e2fsck -f -y toolchain.ext4 && resize2fs -M toolchain.ext4
  ```

Put the license **inside the image, in the program directory**, named to match
`idapro*.hexlic`. Build the image from *your own licensed installation*; this
repository intentionally provides no way to obtain the toolchain.

## Kubernetes

- **Recommended:** bake the toolchain into a private image (never publish it) and run this runtime as a single-replica Deployment with `emptyDir` for `$IDAUSR` and a PVC for `/work`.
- **Or** keep the toolchain as a `.sqfs` on a PVC and mount it via a privileged `initContainer` (`mount -t squashfs -o loop,ro`) plus `hostPath`, then bind that directory into the main container read-only.

The MCP server has **no authentication**; keep it on a private network / use an SSH tunnel, and never expose it publicly.

## Multi-arch

The image is built for `linux/amd64` and `linux/arm64` from the same Dockerfile, because it contains no architecture-specific binaries. The **toolchain image**, however, is architecture-specific — mount the correct one for the node (e.g. an `amd64` toolchain on amd64 nodes).

## Development

```bash
docker build -t mcp-re-tool .
docker buildx build --platform linux/amd64,linux/arm64 -t mcp-re-tool .
```

CI builds and pushes both architectures to GHCR on every push to `main` and on tags.

## License

MIT — see [LICENSE](LICENSE). This license covers **this repository only**; the toolchain you mount is governed by its own license.

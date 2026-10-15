# syntax=docker/dockerfile:1
# Runtime image for an MCP server whose toolchain is supplied as a read-only
# disk image mounted at run time.
#
# This image contains NO proprietary toolchain binaries or licenses — only the
# official MCP server package and its Python dependencies.
FROM python:3.12-slim-bookworm

RUN pip install --no-cache-dir ida-mcp

ENV IDADIR=/opt/toolchain \
    IDAUSR=/root/.idapro \
    IDA_MCP_STATE_DIR=/root/.idapro/mcp \
    PYTHONUNBUFFERED=1

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /work
EXPOSE 8737
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["http", "--host", "0.0.0.0", "--port", "8737"]

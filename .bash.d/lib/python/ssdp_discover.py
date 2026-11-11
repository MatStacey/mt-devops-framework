"""SSDP discovery: send one M-SEARCH and print the devices that reply.

Prints ``ip<TAB>server<TAB>st<TAB>location`` lines, de-duplicated on
``(ip, location)`` and sorted by IP, and nothing else on stdout.
"""

import argparse
import socket
import sys
import time

MAX_MX_SECONDS = 5
RECEIVE_BUFFER_BYTES = 65535
OK_STATUS_PREFIX = "HTTP/1.1 200"
MISSING_HEADER = "-"
SEARCH_TARGET = "ssdp:all"


def build_search_request(address: str, port: int, mx_seconds: int) -> bytes:
    """Build the M-SEARCH datagram for ``ssdp:all``.

    Args:
        address: Multicast address placed in the HOST header.
        port: UDP port placed in the HOST header.
        mx_seconds: Maximum wait advertised to responders, capped at 5.

    Returns:
        The request bytes with CRLF line endings.
    """
    lines = [
        "M-SEARCH * HTTP/1.1",
        f"HOST: {address}:{port}",
        'MAN: "ssdp:discover"',
        f"MX: {min(mx_seconds, MAX_MX_SECONDS)}",
        f"ST: {SEARCH_TARGET}",
        "",
        "",
    ]
    return "\r\n".join(lines).encode("ascii")


def parse_response(data: bytes, ip: str) -> dict[str, str] | None:
    """Parse one SSDP reply.

    Args:
        data: Raw datagram bytes.
        ip: Source IP address of the datagram.

    Returns:
        A dict with ``ip``, ``server``, ``st`` and ``location`` (a missing
        header becomes ``-``), or None when the reply is not ``HTTP/1.1 200``.
    """
    lines = data.decode("utf-8", errors="replace").splitlines()
    if not lines or not lines[0].strip().upper().startswith(OK_STATUS_PREFIX):
        return None
    headers: dict[str, str] = {}
    for line in lines[1:]:
        name, separator, value = line.partition(":")
        if separator:
            headers[name.strip().lower()] = value.strip()
    return {
        "ip": ip,
        "server": headers.get("server", MISSING_HEADER) or MISSING_HEADER,
        "st": headers.get("st", MISSING_HEADER) or MISSING_HEADER,
        "location": headers.get("location", MISSING_HEADER) or MISSING_HEADER,
    }


def discover(address: str, port: int, timeout: int) -> list[dict[str, str]]:
    """Send one M-SEARCH and collect replies until the timeout.

    Args:
        address: SSDP multicast address.
        port: SSDP UDP port.
        timeout: Seconds to keep listening.

    Returns:
        Unique replies (by IP and LOCATION), sorted by IP.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
    sock.sendto(build_search_request(address, port, timeout), (address, port))
    found: dict[tuple[str, str], dict[str, str]] = {}
    deadline = time.monotonic() + timeout
    while (remaining := deadline - time.monotonic()) > 0:
        sock.settimeout(remaining)
        try:
            data, (source_ip, _) = sock.recvfrom(RECEIVE_BUFFER_BYTES)
        except TimeoutError:
            break
        reply = parse_response(data, source_ip)
        if reply:
            found[(reply["ip"], reply["location"])] = reply
    sock.close()
    return sorted(
        found.values(), key=lambda r: tuple(int(p) for p in r["ip"].split("."))
    )


def main(argv: list[str] | None = None) -> int:
    """Run discovery and print the results.

    Args:
        argv: Command-line arguments (default: ``sys.argv[1:]``).

    Returns:
        0 on success, 1 when the socket cannot be used.
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--address", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--timeout", type=int, required=True)
    args = parser.parse_args(argv)
    try:
        replies = discover(args.address, args.port, args.timeout)
    except OSError as error:
        print(f"SSDP discovery failed: {error}", file=sys.stderr)
        return 1
    for reply in replies:
        print("\t".join([reply["ip"], reply["server"], reply["st"], reply["location"]]))
    return 0


if __name__ == "__main__":
    sys.exit(main())

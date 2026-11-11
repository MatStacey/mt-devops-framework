"""Tests for lib/python/ssdp_discover.py's reply parsing and request building."""

import ssdp_discover

REPLY = (
    b"HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=1800\r\n"
    b"Server: Linux/5 UPnP/1.0 Tv/1.0\r\nst: upnp:rootdevice\r\n"
    b"LOCATION: http://192.168.1.20:8080/desc.xml\r\n\r\n"
)


def test_headers_are_read_case_insensitively():
    reply = ssdp_discover.parse_response(REPLY, "192.168.1.20")
    assert reply == {
        "ip": "192.168.1.20",
        "server": "Linux/5 UPnP/1.0 Tv/1.0",
        "st": "upnp:rootdevice",
        "location": "http://192.168.1.20:8080/desc.xml",
    }


def test_a_reply_without_server_uses_a_dash():
    data = b"HTTP/1.1 200 OK\r\nST: x\r\nLOCATION: http://h/d\r\n\r\n"
    assert ssdp_discover.parse_response(data, "10.0.0.2")["server"] == "-"


def test_non_200_and_garbage_replies_are_ignored():
    assert ssdp_discover.parse_response(b"NOTIFY * HTTP/1.1\r\n\r\n", "10.0.0.2") is None
    assert ssdp_discover.parse_response(b"HTTP/1.1 404 Not Found\r\n\r\n", "10.0.0.2") is None
    assert ssdp_discover.parse_response(b"", "10.0.0.2") is None
    assert ssdp_discover.parse_response(b"\xff\xfe\x00", "10.0.0.2") is None


def test_search_request_caps_mx_and_targets_all():
    request = ssdp_discover.build_search_request("239.255.255.250", 1900, 30).decode()
    assert request.startswith("M-SEARCH * HTTP/1.1\r\n")
    assert "MX: 5\r\n" in request
    assert "ST: ssdp:all\r\n" in request
    assert request.endswith("\r\n\r\n")

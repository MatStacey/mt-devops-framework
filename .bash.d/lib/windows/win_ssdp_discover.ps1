param(
    [string]$Address,
    [int]$Port,
    [int]$TimeoutSeconds
)
# Sends one SSDP M-SEARCH from the Windows host and prints
# ip<TAB>server<TAB>st<TAB>location lines (a missing header becomes "-"), de-duplicated
# on (ip, LOCATION) with later replies overwriting earlier ones. The socket is bound to
# the default-route interface, because an unbound socket receives no replies.
$maxMx = [Math]::Min($TimeoutSeconds, 5)
$request = "M-SEARCH * HTTP/1.1`r`nHOST: ${Address}:${Port}`r`nMAN: `"ssdp:discover`"`r`nMX: $maxMx`r`nST: ssdp:all`r`n`r`n"
$bytes = [Text.Encoding]::ASCII.GetBytes($request)
$route = Get-NetRoute -DestinationPrefix 0.0.0.0/0 -ErrorAction SilentlyContinue |
    Sort-Object RouteMetric | Select-Object -First 1
$localIp = $null
if ($route) {
    $localIp = (Get-NetIPAddress -InterfaceIndex $route.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Select-Object -First 1).IPAddress
}
if (-not $localIp) {
    [Console]::Error.WriteLine("No default-route IPv4 address found to bind the SSDP socket to.")
    exit 1
}
$localEndpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Parse($localIp)), 0
$client = New-Object System.Net.Sockets.UdpClient $localEndpoint
$client.Client.ReceiveTimeout = 500
$endpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Parse($Address)), $Port
[void]$client.Send($bytes, $bytes.Length, $endpoint)
$replies = @{}
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    try {
        $remote = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any), 0
        $data = $client.Receive([ref]$remote)
    } catch {
        continue
    }
    $lines = [Text.Encoding]::UTF8.GetString($data) -split "`r?`n"
    if ($lines[0] -notmatch '^HTTP/1\.1 200') { continue }
    $headers = @{}
    foreach ($line in $lines[1..($lines.Length - 1)]) {
        $name, $value = $line -split ':', 2
        if ($value) { $headers[$name.Trim().ToLower()] = $value.Trim() }
    }
    $fields = foreach ($key in 'server', 'st', 'location') {
        if ($headers[$key]) { $headers[$key] } else { '-' }
    }
    $replies["$($remote.Address)|$($fields[2])"] = "$($remote.Address)`t$($fields -join "`t")"
}
$client.Close()
$replies.Values

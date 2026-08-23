param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Add", "Remove")]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [int]$Port,

    [string]$ConnectAddress
)

$ruleName = "MT Serve HTTP ($Port)"
# Scoped to RFC1918 private ranges -- doesn't help against another device
# on the SAME private network (e.g. public Wi-Fi, which hands out private
# IPs too), but stops the rule from ever answering a public-internet
# address in the unlikely case this host has port-forwarding/UPnP set up.
$privateRanges = @("192.168.0.0/16", "10.0.0.0/8", "172.16.0.0/12")

if ($Action -eq "Add") {
    netsh interface portproxy add v4tov4 listenport=$Port listenaddress=0.0.0.0 connectport=$Port connectaddress=$ConnectAddress | Out-Null
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow -RemoteAddress $privateRanges | Out-Null
} else {
    netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=0.0.0.0 | Out-Null
    Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Out-Null
}

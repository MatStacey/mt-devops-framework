def norm: if type == "string" then sub("^https://(www|compute)\\.googleapis\\.com/compute/(v1|beta|alpha)/"; "") else "" end;
def last_segment: if type == "string" then split("/") | last else "-" end;
def where: (.zone // .region // "global") | last_segment;
def host: if type == "string" then (try capture("^https?://(?<h>[^/:]+)").h catch empty) else empty end;
def annotations: (.spec.template.metadata.annotations // {});
def row($kind; $name; $location; $detail): [$kind, $name, $location, $detail] | join("\t");

([$subnets[0][] | select((.network | norm) == $net)]) as $my_subnets
| ([$my_subnets[] | .selfLink | norm]) as $subnet_links
| ([$instance_groups[0][], $negs[0][] | select((.network | norm) == $net)]) as $groups
| ([$groups[] | .selfLink | norm]) as $group_links
| ([$backend_services[0][] | select(
      ((.network | norm) == $net)
      or (any(.backends[]?; ((.group | norm) as $g | $g | IN($group_links[]))))
    )]) as $backend_services_matched
| ([$backend_services_matched[] | .selfLink | norm]) as $service_links
| ([$url_maps[0][] | select(any(
      (.defaultService, .pathMatchers[]?.defaultService, .pathMatchers[]?.pathRules[]?.service, .pathMatchers[]?.routeRules[]?.service);
      ((. | norm) as $s | $s | IN($service_links[]))
    ))]) as $url_maps_matched
| ([$url_maps_matched[] | .selfLink | norm]) as $url_map_links
| ([$http_proxies[0][], $https_proxies[0][], $tcp_proxies[0][], $ssl_proxies[0][]
    | select(
        (((.urlMap | norm) as $u | $u | IN($url_map_links[])))
        or (((.service | norm) as $s | $s | IN($service_links[])))
      )]) as $proxies_matched
| ([$proxies_matched[] | .selfLink | norm]) as $proxy_links
| ([$connectors[0][] | select(
      (.network == $name)
      or ((.network | norm) == $net)
      or (.subnet.name as $s | (.name | split("/") | .[3]) as $r
          | any($my_subnets[]; .name == $s and ((.region | last_segment) == $r)))
    )]) as $connectors_matched
| ([$connectors_matched[] | .name]) as $connector_names
| def connector_matches($value; $region):
    $value != null and ($value | IN($connector_names[]) or ("projects/\($project)/locations/\($region)/connectors/\($value)" | IN($connector_names[])));
  def interface_matches($region):
    (.network == $name) or ((.network | norm) == $net)
    or (.subnetwork as $s | $s != null and any($my_subnets[];
        (.name == $s or (.selfLink | norm) == ($s | norm)) and ((.region | last_segment) == $region)));
  def base_urls: [.[] | select(type == "string" and . != "") | rtrimstr("/")];
  def run_consumers($kind):
    [.[] | (.metadata.labels["cloud.googleapis.com/location"] // "-") as $region
      | (annotations["run.googleapis.com/vpc-access-connector"]) as $connector
      | ((annotations["run.googleapis.com/network-interfaces"] // "[]") | (try fromjson catch [])) as $interfaces
      | ([ (if connector_matches($connector; $region) then "connector=\($connector | last_segment)" else empty end),
           (if any($interfaces[]?; interface_matches($region)) then "direct-vpc" else empty end) ]) as $reasons
      | select(($reasons | length) > 0)
      | {name: .metadata.name, region: $region, detail: ($reasons | join(",")),
         bases: ([.status.url] + ((annotations["run.googleapis.com/urls"] // "[]") | (try fromjson catch [])) | base_urls)}
    ];
  ($run[0] | run_consumers("service")) as $run_matched
| ($run_jobs[0] | run_consumers("job")) as $run_jobs_matched
| ([$functions[0][]
    | (.vpcConnector // .serviceConfig.vpcConnector) as $connector
    | select($connector != null and ($connector | IN($connector_names[])))
    | {name: (.name | last_segment), region: (.name | split("/") | .[3] // "-"),
       detail: "\(.environment // "-") connector=\($connector | last_segment)",
       bases: ([.httpsTrigger.url, .serviceConfig.uri, .url] | base_urls)}
  ]) as $functions_matched
| ([$run_matched[].bases[], $functions_matched[].bases[]]) as $consumer_bases
| (
    ($peerings[]? | row("peering"; .name; "global"; (.peerNetwork // .network // "-"))),
    ($instances[0][] | select(any(.networkInterfaces[]?; (.network | norm) == $net)) | row("instance"; .name; where; "-")),
    ($instance_groups[0][] | select((.network | norm) == $net) | row("instance-group"; .name; where; "-")),
    ($negs[0][] | select((.network | norm) == $net) | row("neg"; .name; where; "-")),
    ($backend_services_matched[] | row("backend-service"; .name; where; "-")),
    ($url_maps_matched[] | row("url-map"; .name; where; "-")),
    ($proxies_matched[] | row("target-proxy"; .name; where; "-")),
    ($forwarding_rules[0][] | select(
        ((.network | norm) == $net)
        or (((.backendService | norm) as $s | $s | IN($service_links[])))
        or (((.target | norm) as $t | $t | IN($proxy_links[])))
      ) | row("forwarding-rule"; .name; where; (.loadBalancingScheme // "-"))),
    ($routers[0][] | select((.network | norm) == $net) | row("router"; .name; where; "nat=\([.nats[]?.name] | join(","))")),
    ($firewalls[0][] | select((.network | norm) == $net) | row("firewall"; .name; where; (.direction // "-"))),
    ($my_subnets[] | select(($auto and .name == $name) | not) | row("subnet"; .name; where; (.ipCidrRange // "-"))),
    ($addresses[0][] | select(
        ((.network | norm) == $net)
        or (((.subnetwork | norm) as $s | $s | IN($subnet_links[])))
      ) | row("address"; .name; where; "\(.status // "-") users=\((.users // []) | length)")),
    ($redis[0][] | select((.authorizedNetwork | norm) == $net) | row("redis"; (.name | last_segment); (.locationId // (.name | split("/") | .[3]) // "-"); "-")),
    ($sql[0][] | select((.settings.ipConfiguration.privateNetwork | norm) == $net) | row("cloud-sql"; .name; (.region // "-"); "-")),
    ($connectors_matched[] | row("vpc-connector"; (.name | last_segment); (.name | split("/") | .[3] // "-"); "-")),
    ($run_matched[] | row("cloud-run"; .name; .region; .detail)),
    ($run_jobs_matched[] | row("cloud-run-job"; .name; .region; .detail)),
    ($functions_matched[] | row("function"; .name; .region; .detail)),
    ($scheduler[0][] | (.httpTarget.uri // "") as $uri
      | select($uri != "" and (
          any($consumer_bases[]; . as $b | $uri == $b or ($uri | startswith($b + "/")) or ($uri | startswith($b + "?")))
          or any($run_jobs_matched[]; . as $j | ($uri | host) == "\($j.region)-run.googleapis.com" and (($uri | split("?")[0]) | endswith("/jobs/\($j.name):run")))
        ))
      | row("scheduler"; (.name | last_segment); (.name | split("/") | .[3] // "-"); ($uri | host)))
  )

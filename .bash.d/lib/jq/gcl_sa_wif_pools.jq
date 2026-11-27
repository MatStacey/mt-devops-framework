# Distinct Workload Identity Pools referenced by the collected bindings, as
# "number<TAB>location<TAB>pool" lines, so each pool is described once.
# Input: the slurped bindings, [{project, sa, members: [...]}].
include "gcl_wif_member";
[.[].members[] | wif_member | [.number, .location, .pool]] | unique[] | @tsv

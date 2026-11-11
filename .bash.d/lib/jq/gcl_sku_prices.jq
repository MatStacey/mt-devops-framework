def price_text:
  (.units // "0" | tostring) as $units
  | ((.nanos // 0) | tostring) as $nanos
  | (("000000000" + $nanos)[-9:]) as $fraction
  | ($units + "." + $fraction) | sub("0+$"; "") | sub("\\.$"; "");

[ .[]
  | select(($region == "") or ((.serviceRegions // []) | index($region)) != null)
  | select(($match == "") or ((.description // "") | test($match; "i")))
  | .description as $description
  | (.pricingInfo[0].pricingExpression // {}) as $expression
  | $expression.tieredRates[]?
  | {description: $description, unit: ($expression.usageUnit // "-"), start: (.startUsageAmount // 0), price: (.unitPrice | price_text)}
]
| sort_by([.description, .start])
| .[]
| [.description, .unit, (.start | tostring), .price]
| join("\t")

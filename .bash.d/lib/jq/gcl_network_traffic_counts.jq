reduce (.[]? | select(.resource.labels[$label] != null)) as $series ($base;
  .[$series.resource.labels[$label]] = ((.[$series.resource.labels[$label]] // 0)
    + (($series.points[0].value.int64Value // $series.points[0].value.doubleValue // 0) | tonumber)))

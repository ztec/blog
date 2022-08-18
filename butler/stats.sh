#!/bin/sh
cat /riper/kube/blog.ztec.fr/logs/access*.log |grep -v ping |grep -v uptimerobot |grep -v StatusCake |goaccess \
-o stats.html \
--log-format='%^ %^[%d:%t %^] "%r" %s %b"%R" "%u" "%h" %^ %^ "%T" %^ ' \
--date-format=%d/%b/%Y --time-format=%T \
--anonymize-ip --exclude-ip 10.0.0.0-10.25.255.255 \
-a --no-ip-validation --real-os --ignore-crawlers \
--ignore-referrer="blog.ztec.fr" \
--hide-referrer="blog.ztec.fr" \
--ignore-panel "KEYPHRASES" \
--date-spec=hr \
--geoip-database /home/zed/geoip/dbip-city-lite-2021-04.mmdb -
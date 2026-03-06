docker compose exec -T mysql mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < ./mysql/scripts/sql/nanbyodata_nando_panel.sql
docker compose exec -T mysql mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < ./mysql/scripts/sql/nanbyodata_nando_panel_hierarchy.sql
docker compose exec -T mysql mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < ./mysql/scripts/sql/nanbyodata_nando_panel_upstream_trace.sql

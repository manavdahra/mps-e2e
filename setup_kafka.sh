#!/usr/bin/env bash

set -e
cub kafka-ready -b kafka:29092 1 40
cub sr-ready schema-registry 8081 40
kafka-topics --bootstrap-server kafka:29092 --delete --topic rawevents.* --if-exists
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.menu.v1 --partitions 1 --replication-factor 1 --if-not-exists
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.recipe_procurement --partitions 1 --replication-factor 1 --if-not-exists
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.forecast.v1 --partitions 1 --replication-factor 1 --if-not-exists
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.slot_item_changed.v1 --partitions 1 --replication-factor 1 --if-not-exists
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.csku.suppliersplits.v1 --partitions 1 --replication-factor 1 --if-not-exists
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.suppliersplits.newalerts --partitions 1 --replication-factor 1 --if-not-exists
kafka-topics --bootstrap-server kafka:29092 --create --topic public.culinary.menu.planning.slots.modification.v1 --partitions 1 --replication-factor 1 --if-not-exists
kafka-topics --bootstrap-server kafka:29092 --create --topic public.culinary.menu.planning.retry.slots.modification.v1 --partitions 1 --replication-factor 1 --if-not-exists
pull_event_schemas.sh
add_avro_schemas.sh schema-registry 8081 rawevents.menu.v1 /home/appuser/menu.avro.json
add_avro_schemas.sh schema-registry 8081 rawevents.recipe_procurement /home/appuser/recipe_procurement.avro.json
add_avro_schemas.sh schema-registry 8081 rawevents.forecast.v1 /home/appuser/forecast.avro.json
add_avro_schemas.sh schema-registry 8081 rawevents.slot_item_changed.v1 /home/appuser/slot_item_changed.avro.json
add_avro_schemas.sh schema-registry 8081 rawevents.csku.suppliersplits.v1 /home/appuser/csku_supplier_splits.avro.json
add_avro_schemas.sh schema-registry 8081 rawevents.suppliersplits.newalerts /home/appuser/supplier_split_new_alerts.avro.json
exit 0

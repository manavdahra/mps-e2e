#!/bin/bash

if [[ -z "${GITHUB_TOKEN}" ]]
then
	echo "You need to set your GITHUB_TOKEN environment variable"
	exit 1
fi

if [[ ! -f ".env" ]]
then
	echo ".env file not found in root folder"
	exit 1
fi

DOCKER_URL=489198589229.dkr.ecr.eu-west-1.amazonaws.com
DOCKER_USR=AWS
SSO_PROFILE=sso-hf-it-developer
REGION=eu-west-1
GITHUB_BASE_URL="https://api.github.com/repos/hellofresh/menu-planning-service/contents/.github/scripts/"
SCRIPTS=(
	"add_avro_schemas.sh"
	"pull_event_schemas.sh"
)
function cleanup_scripts {
	for script in "${SCRIPTS[@]}"
	do
		rm -rf $script
	done
}

printf "\n#################### Cleanup ############################\n"

cleanup_scripts
rm -rf ./db_data
GITHUB_TOKEN=$GITHUB_TOKEN TAG=latest DOCKER_URL=$DOCKER_URL docker-compose -f docker-compose.yaml down --remove-orphan

printf "\n#################### Kafka scripts ############################\n"

for script in "${SCRIPTS[@]}"
do
	curl -H 'Authorization: token '"$GITHUB_TOKEN" \
		-H 'Accept: application/vnd.github.v3.raw' \
		-H 'Accept: application/json' \
		-O -L "${GITHUB_BASE_URL}${script}"
	chmod +x $script
done

printf "\n#################### Docker login ############################\n"

aws sso login --profile $SSO_PROFILE
DOCKER_PWD=$(aws ecr get-login-password --region $REGION --profile $SSO_PROFILE)
echo $DOCKER_PWD | docker login --username $DOCKER_USR --password-stdin "https://$DOCKER_URL"

printf "\n#################### E2E environment setup ############################\n"

GITHUB_TOKEN=$GITHUB_TOKEN TAG=latest DOCKER_URL=$DOCKER_URL docker-compose -f docker-compose.yaml up -d
docker exec $(docker ps -qf 'name=kafka') /bin/bash -c 'set -e; \
cub kafka-ready -b kafka:29092 1 40; \
cub sr-ready schema-registry 8081 40; \
kafka-topics --bootstrap-server kafka:29092 --delete --topic rawevents.* --if-exists; \
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.menu.v1 --partitions 1 --replication-factor 1 --if-not-exists; \
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.recipe_procurement --partitions 1 --replication-factor 1 --if-not-exists; \
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.forecast.v1 --partitions 1 --replication-factor 1 --if-not-exists; \
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.slot_item_changed.v1 --partitions 1 --replication-factor 1 --if-not-exists; \
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.csku.suppliersplits.v1 --partitions 1 --replication-factor 1 --if-not-exists; \
kafka-topics --bootstrap-server kafka:29092 --create --topic rawevents.suppliersplits.newalerts --partitions 1 --replication-factor 1 --if-not-exists; \
kafka-topics --bootstrap-server kafka:29092 --create --topic public.culinary.menu.planning.slots.modification.v1 --partitions 1 --replication-factor 1 --if-not-exists; \
kafka-topics --bootstrap-server kafka:29092 --create --topic public.culinary.menu.planning.retry.slots.modification.v1 --partitions 1 --replication-factor 1 --if-not-exists;'
docker exec $(docker ps -qf 'name=kafka') /bin/bash -c 'set -e; pull_event_schemas.sh;'
docker exec $(docker ps -qf 'name=kafka') /bin/bash -c 'set -e; \
add_avro_schemas.sh schema-registry 8081 rawevents.menu.v1 /home/appuser/menu.avro.json; \
add_avro_schemas.sh schema-registry 8081 rawevents.recipe_procurement /home/appuser/recipe_procurement.avro.json; \
add_avro_schemas.sh schema-registry 8081 rawevents.forecast.v1 /home/appuser/forecast.avro.json; \
add_avro_schemas.sh schema-registry 8081 rawevents.slot_item_changed.v1 /home/appuser/slot_item_changed.avro.json; \
add_avro_schemas.sh schema-registry 8081 rawevents.csku.suppliersplits.v1 /home/appuser/csku_supplier_splits.avro.json; \
add_avro_schemas.sh schema-registry 8081 rawevents.suppliersplits.newalerts /home/appuser/supplier_split_new_alerts.avro.json;'
cleanup_scripts

printf "\n#################### Done ############################\n"

DATABASE_URL     ?= postgres://bixi:bixi@localhost:5433/bixi
DATABASE_URL_DEV ?= postgres://bixi:bixi@localhost:5434/bixi

# AWS config for LocalStack (used by awslocal / tflocal)
export AWS_DEFAULT_REGION    ?= ca-central-1
export AWS_ACCESS_KEY_ID     ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_ENDPOINT_URL      ?= http://localhost:4566

.PHONY: up down migrate reset \
        localstack-up localstack-down localstack-wait \
        tf-local-init tf-local-plan tf-local-apply tf-local-destroy \
        test-collector-lambda test-inference-lambda \
        migrate-aws upload-zips-local

# ── Local nerdctl DB ──────────────────────────────────────────────────────────

up:
	nerdctl compose up -d
	@echo "Waiting for DB to be ready..."
	@until nerdctl exec bixi-db pg_isready -U bixi -d bixi 2>/dev/null; do sleep 1; done
	@echo "DB ready."

down:
	nerdctl compose down

migrate:
	nerdctl cp migrations/001_initial_schema.sql bixi-db:/tmp/
	nerdctl exec bixi-db psql -U bixi -d bixi -f /tmp/001_initial_schema.sql

# Wipe the DB volume and re-create (destructive — dev only)
reset:
	nerdctl compose down -v
	nerdctl compose up -d
	@until nerdctl exec bixi-db pg_isready -U bixi -d bixi 2>/dev/null; do sleep 1; done
	$(MAKE) migrate

# ── LocalStack ────────────────────────────────────────────────────────────────

localstack-up:
	docker compose -f docker-compose.localstack.yml up -d
	$(MAKE) localstack-wait

localstack-down:
	docker compose -f docker-compose.localstack.yml down

localstack-wait:
	@echo "Waiting for LocalStack..."
	@until curl -sf http://localhost:4566/_localstack/health | grep -q '"lambda": "available"'; do sleep 2; done
	@echo "LocalStack ready."

# ── Terraform against LocalStack ──────────────────────────────────────────────
# tflocal is a thin wrapper: pip install terraform-local
# It auto-configures all provider endpoints to http://localhost:4566

tf-local-init:
	cd terraform && tflocal init

tf-local-plan:
	cd terraform && tflocal plan \
		-var="database_url=$(DATABASE_URL_DEV)" \
		-var="enable_rds=false" \
		-var="enable_ecs=false" \
		-var="enable_cloudfront=false"

tf-local-apply:
	cd terraform && tflocal apply -auto-approve \
		-var="database_url=$(DATABASE_URL_DEV)" \
		-var="enable_rds=false" \
		-var="enable_ecs=false" \
		-var="enable_cloudfront=false"

tf-local-destroy:
	cd terraform && tflocal destroy -auto-approve \
		-var="database_url=$(DATABASE_URL_DEV)" \
		-var="enable_rds=false" \
		-var="enable_ecs=false" \
		-var="enable_cloudfront=false"

# ── Upload Lambda zips to LocalStack S3 ──────────────────────────────────────
# Run after tf-local-apply creates the bucket, before testing Lambda.

upload-zips-local:
	@echo "Uploading Lambda zips to LocalStack S3..."
	aws --endpoint-url=http://localhost:4566 s3 cp \
		../bixi-collector/bin/collector.zip \
		s3://bixi-prod-lambda-zips/collector.zip
	aws --endpoint-url=http://localhost:4566 s3 cp \
		../bixi-ml/dist/lambda/inference.zip \
		s3://bixi-prod-lambda-zips/inference.zip
	aws --endpoint-url=http://localhost:4566 s3 cp \
		../bixi-ml/dist/lambda/inference-layer.zip \
		s3://bixi-prod-lambda-zips/inference-layer.zip
	@echo "Done. Now run: make tf-local-apply to create Lambda functions."

# ── Lambda invocation tests ───────────────────────────────────────────────────

test-collector-lambda:
	@echo "Invoking collector Lambda..."
	aws --endpoint-url=http://localhost:4566 lambda invoke \
		--function-name bixi-prod-collector \
		--payload '{}' \
		/tmp/collector-response.json
	@echo "Response:"; cat /tmp/collector-response.json

test-inference-lambda:
	@echo "Invoking inference Lambda..."
	aws --endpoint-url=http://localhost:4566 lambda invoke \
		--function-name bixi-prod-inference \
		--payload '{}' \
		/tmp/inference-response.json
	@echo "Response:"; cat /tmp/inference-response.json

# ── AWS production migrations ─────────────────────────────────────────────────

migrate-aws:
	@echo "Applying schema to RDS (DATABASE_URL must point to prod RDS)"
	PGPASSWORD=$$(echo $(DATABASE_URL) | sed 's/.*:\(.*\)@.*/\1/') \
		psql "$(DATABASE_URL)" -f migrations/001_initial_schema.sql

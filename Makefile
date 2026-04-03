DATABASE_URL ?= postgres://bixi:bixi@localhost:5433/bixi

.PHONY: up down migrate reset

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

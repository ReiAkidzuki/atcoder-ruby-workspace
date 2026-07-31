.DEFAULT_GOAL := help

COUNT ?= 100
SEED ?= 1
RUBY ?= rbenv exec ruby

.PHONY: help setup setup-full vscode-safe update-template doctor self-test login contest tasks new add-case test run bundle init-random random submit

help:
	@echo "AtCoder Ruby workspace"
	@echo
	@echo "  make setup"
	@echo "  make setup-full"
	@echo "  make vscode-safe"
	@echo "  make update-template"
	@echo "  make doctor"
	@echo "  make self-test"
	@echo "  make login"
	@echo "  make contest CONTEST=abc468"
	@echo "  make tasks CONTEST=abc468"
	@echo "  make new CONTEST=abc468 TASK=a"
	@echo "  make add-case TARGET=abc468/a NAME=custom-1 INPUT=input.txt EXPECTED=expected.txt"
	@echo "  make test TARGET=abc468/a"
	@echo "  make run TARGET=abc468/a INPUT=input.txt"
	@echo "  make bundle TARGET=abc468/a"
	@echo "  make init-random TARGET=abc468/a"
	@echo "  make random TARGET=abc468/a COUNT=1000 SEED=1"
	@echo "  make submit TARGET=abc468/a"

setup:
	@./bin/setup

setup-full:
	@./bin/setup --full

vscode-safe:
	@./bin/vscode-safe

update-template:
	@./bin/update-template

doctor:
	@./bin/doctor

self-test:
	@$(RUBY) test/run.rb

login:
	@PATH="$(CURDIR)/.venv/bin:$$PATH" ./.venv/bin/aclogin --tools oj

contest:
	@test -n "$(CONTEST)" || (echo "CONTEST is required"; exit 2)
	@./bin/atcoder contest "$(CONTEST)"

tasks:
	@test -n "$(CONTEST)" || (echo "CONTEST is required"; exit 2)
	@./bin/atcoder tasks "$(CONTEST)"

new:
	@test -n "$(CONTEST)" || (echo "CONTEST is required"; exit 2)
	@test -n "$(TASK)" || (echo "TASK is required"; exit 2)
	@./bin/atcoder new "$(CONTEST)" "$(TASK)"

add-case:
	@test -n "$(TARGET)" || (echo "TARGET is required"; exit 2)
	@test -n "$(NAME)" || (echo "NAME is required"; exit 2)
	@test -n "$(INPUT)" || (echo "INPUT is required"; exit 2)
	@test -n "$(EXPECTED)" || (echo "EXPECTED is required"; exit 2)
	@./bin/atcoder add-case "$(TARGET)" "$(NAME)" "$(INPUT)" "$(EXPECTED)"

test:
	@test -n "$(TARGET)" || (echo "TARGET is required"; exit 2)
	@./bin/atcoder test "$(TARGET)"

run:
	@test -n "$(TARGET)" || (echo "TARGET is required"; exit 2)
	@if test -n "$(INPUT)"; then \
		./bin/atcoder run "$(TARGET)" "$(INPUT)"; \
	else \
		./bin/atcoder run "$(TARGET)"; \
	fi

bundle:
	@test -n "$(TARGET)" || (echo "TARGET is required"; exit 2)
	@./bin/atcoder bundle "$(TARGET)"

init-random:
	@test -n "$(TARGET)" || (echo "TARGET is required"; exit 2)
	@./bin/atcoder init-random "$(TARGET)"

random:
	@test -n "$(TARGET)" || (echo "TARGET is required"; exit 2)
	@./bin/atcoder random "$(TARGET)" "$(COUNT)" "$(SEED)"

submit:
	@test -n "$(TARGET)" || (echo "TARGET is required"; exit 2)
	@./bin/atcoder submit "$(TARGET)"

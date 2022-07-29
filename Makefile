PACTICIPANT ?= "pactflow-example-bi-directional-provider-dredd"
GITHUB_REPO := "pactflow/pactflow-example-bi-directional-provider-dredd"
PACT_CLI_DOCKER_VERSION?=latest

## ====================
## Pactflow Provider Publishing
## ====================
PACT_CLI="docker run --rm -v ${PWD}:/app -w "/app" -e PACT_BROKER_BASE_URL -e PACT_BROKER_TOKEN pactfoundation/pact-cli:${PACT_CLI_DOCKER_VERSION}"
OAS_FILE_PATH?=oas/products.yml
REPORT_FILE_PATH?=output/report.md
REPORT_FILE_CONTENT_TYPE?=text/plain
VERIFIER_TOOL?=dredd

# Only deploy from master
ifeq ($(GIT_BRANCH),master)
	DEPLOY_TARGET=deploy
else
	DEPLOY_TARGET=no_deploy
endif

all: test

## ====================
## CI tasks
## ====================

ci:
	@if make test; then \
		make publish_success; \
	else \
		make publish_failure; \
	fi; \

publish_success: .env
	@echo "\n========== STAGE: publish provider contract (spec + results) - success ==========\n"
	PACTICIPANT=${PACTICIPANT} \
	"${PACT_CLI}" pactflow publish-provider-contract \
      /app/${OAS_FILE_PATH} \
      --provider ${PACTICIPANT} \
      --provider-app-version ${GIT_COMMIT} \
      --branch ${GIT_BRANCH} \
      --content-type application/yaml \
      --verification-exit-code=0 \
      --verification-results /app/${REPORT_FILE_PATH} \
      --verification-results-content-type ${REPORT_FILE_CONTENT_TYPE}\
      --verifier ${VERIFIER_TOOL}

publish_failure: .env
	@echo "\n========== STAGE:  publish provider contract (spec + results) - failure  ==========\n"
	PACTICIPANT=${PACTICIPANT} \
	"${PACT_CLI}" pactflow publish-provider-contract \
      /app/${OAS_FILE_PATH} \
      --provider ${PACTICIPANT} \
      --provider-app-version ${GIT_COMMIT} \
      --branch ${GIT_BRANCH} \
      --content-type application/yaml \
      --verification-exit-code=1 \
      --verification-results ${REPORT_FILE_PATH} \
      --verification-results-content-type ${REPORT_FILE_CONTENT_TYPE}\
      --verifier ${VERIFIER_TOOL}

# Run the ci target from a developer machine with the environment variables
# set as if it was on Github Actions.
# Use this for quick feedback when playing around with your workflows.
fake_ci: .env
	@CI=true \
	GIT_COMMIT=`git rev-parse --short HEAD`-`date +%s` \
	GIT_BRANCH=`git rev-parse --abbrev-ref HEAD` \
	PACT_BROKER_PUBLISH_VERIFICATION_RESULTS=true \
	make ci deploy_target

deploy_target: can_i_deploy $(DEPLOY_TARGET)

## =====================
## Build/test tasks
## =====================

test:
	@echo "\n========== STAGE: test ✅ ==========\n"
	npm run test

## =====================
## Deploy tasks
## =====================

deploy: deploy_app record_deployment

no_deploy:
	@echo "Not deploying as not on master branch"

can_i_deploy: .env
	@echo "\n========== STAGE: can-i-deploy? 🌉 ==========\n"
	"${PACT_CLI}" broker can-i-deploy --pacticipant ${PACTICIPANT} --version ${GIT_COMMIT} --to-environment production

deploy_app:
	@echo "\n========== STAGE: deploy 🚀 ==========\n"
	@echo "Deploying to prod"

record_deployment: .env
	@"${PACT_CLI}" broker record_deployment --pacticipant ${PACTICIPANT} --version ${GIT_COMMIT} --environment production

## =====================
## Pactflow set up tasks
## =====================

## ======================
## Misc
## ======================

.env:
	touch .env

.PHONY: all test clean

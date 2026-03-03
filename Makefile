.PHONY: all build-lambdas build-services clean

LAMBDAS_DIR = exchange-platform/lambdas
SERVICES_DIR = exchange-platform/services

all: build-lambdas build-services

build-lambdas:
	@echo "Building all TS Lambdas..."
	@for dir in $(wildcard $(LAMBDAS_DIR)/*/*/); do \
		echo "-> Building $$dir"; \
		if [ -f "$$dir/package.json" ]; then \
			cd $$dir && npm install && npm run build && cd - > /dev/null; \
		fi \
	done

build-services:
	@echo "Building all Spring/Node Services..."
	@for dir in $(wildcard $(SERVICES_DIR)/*/*/); do \
		echo "-> Building $$dir"; \
		if [ -f "$$dir/build.gradle" ] || [ -f "$$dir/build.gradle.kts" ]; then \
			cd $$dir && ./gradlew build --no-daemon -x test && cd - > /dev/null; \
		elif [ -f "$$dir/package.json" ]; then \
			cd $$dir && npm install && npm run build && cd - > /dev/null; \
		fi \
	done

clean:
	@echo "Cleaning workspaces..."
	@for dir in $(wildcard $(LAMBDAS_DIR)/*/*/); do \
		if [ -f "$$dir/package.json" ]; then \
			cd $$dir && rm -rf node_modules dist out && cd - > /dev/null; \
		fi \
	done
	@for dir in $(wildcard $(SERVICES_DIR)/*/*/); do \
		if [ -f "$$dir/build.gradle" ] || [ -f "$$dir/build.gradle.kts" ]; then \
			cd $$dir && ./gradlew clean --no-daemon && cd - > /dev/null; \
		elif [ -f "$$dir/package.json" ]; then \
			cd $$dir && rm -rf node_modules dist out && cd - > /dev/null; \
		fi \
	done

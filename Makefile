FLUTTER ?= flutter
DART ?= dart
.PHONY: help deps format analyze test verify build.public release.prepare image image.test serve repository.check git.dry git
help:
	@echo "deps format analyze test verify build.public release.prepare image image.test serve repository.check git.dry git"
deps:
	$(FLUTTER) pub get --enforce-lockfile
format:
	$(DART) format --output=none --set-exit-if-changed lib test tool
analyze:
	$(FLUTTER) analyze
test:
	$(FLUTTER) test
	python3 tool/test_api_web.py
	node --test test/pwa_worker_test.mjs test/preferences_bootstrap_test.mjs
	python3 -m unittest discover -s test/tool -p '*_test.py'
	python3 -m unittest discover -s test -p '*_test.py'
repository.check:
	python3 tool/repository_check.py
verify: format analyze test repository.check
build.public:
	python3 tool/build.py --base-href "$(or $(BASE_HREF),/)"
release.prepare:
	python3 tool/release.py prepare
image:
	python3 tool/container.py build
image.test:
	python3 tool/container.py test
serve:
	python3 tool/serve.py
git.dry:
	python3 xops/makefile/git_ops.py dry
git:
	python3 xops/makefile/git_ops.py push

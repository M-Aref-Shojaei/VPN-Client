.PHONY: core-build core-test core-vet app-analyze app-test cloud-safety check

core-build:
	cd core && go build -o routerctl ./cmd/routerctl

core-test:
	cd core && go test ./...

core-vet:
	cd core && go vet ./...

app-analyze:
	cd app && flutter analyze

app-test:
	cd app && flutter test

cloud-safety:
	./scripts/check-cloud-safety.sh

check: core-test core-vet app-analyze app-test

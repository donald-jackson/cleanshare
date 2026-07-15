# CleanShare — developer task runner. See PLAN.md §10.

SCHEME ?= CleanShare
DESTINATION ?= generic/platform=iOS Simulator
DERIVED_DATA ?= ~/Library/Developer/Xcode/DerivedData

NO_SIGN := CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

.PHONY: bootstrap gen build test lint format verify-strip check-trackers clean screenshots

bootstrap:
	./scripts/bootstrap.sh

gen:
	./scripts/generate-project.sh

build: gen
	xcodebuild -project CleanShare.xcodeproj -scheme $(SCHEME) \
		-destination '$(DESTINATION)' -configuration Debug build $(NO_SIGN) \
		| xcbeautify --renderer terminal

test:
	swift test --package-path Packages/CleanShareCore
	xcodebuild -project CleanShare.xcodeproj -scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' test $(NO_SIGN) \
		| xcbeautify --renderer terminal

lint:
	swiftformat --lint . && swiftlint --strict

format:
	swiftformat .

verify-strip:
	cd Packages/CleanShareCore && swift build --product cleanshare-cli
	rm -rf tests/fixtures/cleaned && mkdir -p tests/fixtures/cleaned
	for f in tests/fixtures/dirty/*; do \
	  ./Packages/CleanShareCore/.build/debug/cleanshare-cli clean "$$f" "tests/fixtures/cleaned/$$(basename $$f)" || exit 1; \
	done
	bash scripts/verify-metadata-stripped.sh tests/fixtures/cleaned/*

check-trackers:
	bash scripts/check-no-trackers.sh

clean:
	rm -rf $(DERIVED_DATA)/CleanShare-* .build CleanShare.xcodeproj

screenshots:
	./scripts/screenshots.sh

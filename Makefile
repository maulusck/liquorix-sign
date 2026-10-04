VERSION ?= 1.0.0

pkg:
	mkdir -p dist
	for p in deb rpm archlinux; do VERSION=$(VERSION) nfpm pkg -p $$p -t dist/ || exit 1; done

test:
	sh -n liquorix-sign hooks/debian hooks/fedora
	unshare -r ./test.sh

clean:
	rm -rf dist

.PHONY: pkg test clean

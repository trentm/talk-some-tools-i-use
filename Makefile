
all:

# See <https://help.github.com/articles/creating-project-pages-manually> for
# how to set this up for the first time.
.PHONY: publish
publish:
	mkdir -p tmp
	[[ -d tmp/gh-pages ]] || git clone $(shell git remote get-url origin) tmp/gh-pages
	cd tmp/gh-pages \
		&& git checkout gh-pages \
		&& git pull --rebase origin gh-pages
	cp -PR \
		index.html \
		css \
		img \
		js \
		tmp/gh-pages/
	(cd tmp/gh-pages \
		&& git add -A . \
		&& git commit -a -m "publish latest version" \
		&& git push origin gh-pages || true)
	echo "Published to http://trentm.github.io/$(shell basename $PWD)/"


serve:
	@docker rm -f nathan-archive >/dev/null 2>&1 || true
	@docker run --rm --name nathan-archive -v "$$PWD:/srv/jekyll" -p 8080:8080 -it jekyll/jekyll:latest /bin/sh -c " \
		bundle install && \
		bundle exec jekyll serve -H 0.0.0.0 -P 8080 \
	"

stop:
	@docker stop nathan-archive >/dev/null 2>&1 || true

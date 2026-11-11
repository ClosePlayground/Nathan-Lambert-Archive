# Nathan Lambert Archive

An unofficial, static Jekyll site for public Facebook posts and videos from Nathan Lambert, the Victorian Labor Member for Preston.

## Pages

- `/` for the paginated post archive
- `/videos/` for the paginated video archive
- `/all/` for the full index of posts and videos grouped by year
- `/posts/<id>.html` for individual posts
- `/videos/<id>.html` for individual video records
- `/about/` for information about the archive

## How it works

`_plugins/archive_generator.rb` reads `data/posts.csv` and `data/videos.csv` at build time. It creates a page for each record, paginates the archives, and builds the JSON-LD data used in the page heads. Search is optional: the browser loads a static index only when someone types or selects a year.

The original per-record URLs are preserved: `/posts/post-0001.html` and `/videos/video-0001.html`.

## Local preview

### Docker

```sh
make serve
```

Open http://localhost:8080/Nathan-Lambert-Archive/. Stop the server with `make stop`.

The archive uses a custom Jekyll plugin. Do not add the `github-pages` gem to the Gemfile because it forces safe mode and disables local plugins. Deployment uses the GitHub Actions workflow, which runs Jekyll directly.

### Ruby

Ruby 3.2 or newer is recommended.

```sh
bundle install
bundle exec jekyll serve
```

Open http://localhost:4000/Nathan-Lambert-Archive/.

## Updating the archive

1. Replace `data/posts.csv` and/or `data/videos.csv`.
2. Keep the existing columns and IDs. IDs must be unique and contain only letters, numbers, underscores and hyphens.
3. Commit the changes. The GitHub Actions workflow runs `jekyll build` and deploys `_site` to GitHub Pages.

The CSV files are published at `/data/posts.csv` and `/data/videos.csv`.

## SEO

The site includes canonical URLs, Open Graph and Twitter metadata, Schema.org JSON-LD for posts, videos and collection pages, an XML sitemap, an Atom feed, `robots.txt` rules for search and AI crawlers, and an `llms.txt` summary.

## Notes

- Media files and transcripts are not hosted here.
- Dates are shown in Melbourne time.
- The archive is unofficial and not affiliated with Nathan Lambert, the Victorian Government, or the Labor Party.

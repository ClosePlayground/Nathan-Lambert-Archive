require "csv"
require "time"

module NathanLambertArchive
  class Generator < Jekyll::Generator
    safe true
    priority :low

    POSTS_PER_PAGE = 24
    VIDEOS_PER_PAGE = 24

    def generate(site)
      @site = site

      posts = load_posts
      videos = load_videos
      link_records(posts, videos)

      site.data["archive"] = {
        "posts" => posts,
        "videos" => videos
      }

      all_items = (posts + videos).sort_by { |item| -item["date"].to_time.to_i }

      add_post_pages(posts)
      add_video_pages(videos)
      add_all_page(all_items, "all")
      add_pagination(posts, "posts", POSTS_PER_PAGE, "/")
      add_pagination(videos, "videos", VIDEOS_PER_PAGE, "/videos/")
    end

    private

    def load_posts
      rows = read_csv("posts.csv")
      validate_rows(rows, "archive_id", "posts")

      posts = rows.map do |row|
        timestamp = row["timestamp_unix"].to_i
        date = DateTime.strptime(row["date_melbourne"], "%d/%m/%Y %H:%M")
        text = clean_text(row["post_text"].to_s.strip.empty? ? row["media_descriptions"] : row["post_text"])
        links = parse_links(row["shared_links"])
        title = derive_title(text, row["post_title"], links, date, "Post")

        {
          "id" => row["archive_id"],
          "record_id" => row["archive_id"],
          "kind" => "Post",
          "timestamp" => timestamp,
          "date" => date,
          "date_display" => date.strftime("%-d %B %Y"),
          "date_iso" => Time.at(timestamp).utc.iso8601,
          "year" => date.year,
          "title" => title,
          "seo_title" => truncate(title, 50),
          "text" => text,
          "excerpt" => excerpt(text, "No post text in the export. This record may be a shared link, a media post, or another kind of Facebook activity."),
          "description" => meta_description(text, links, date, "Post"),
          "links" => links,
          "media_count" => row["media_count"].to_i,
          "matched_filenames" => parse_paths(row["matched_video_paths"]),
          "transcript" => clean_text(row["transcript"]),
          "facebook_url" => row["original_facebook_url"].to_s,
          "video_id" => nil,
          "video_url" => nil,
          "video_title" => nil,
          "url" => "/posts/#{row['archive_id']}.html"
        }
      end

      posts.sort_by { |post| -post["timestamp"] }
    end

    def load_videos
      rows = read_csv("videos.csv")
      validate_rows(rows, "video_id", "videos")

      videos = rows.map do |row|
        date = DateTime.strptime(row["date_melbourne"], "%Y-%m-%d %H:%M:%S")
        text = clean_text(row["video_description"])
        title = derive_title(text, "", [], date, "Video")

        {
          "id" => row["video_id"],
          "record_id" => row["video_id"],
          "kind" => "Video",
          "date" => date,
          "date_display" => date.strftime("%-d %B %Y"),
          "date_iso" => date.strftime("%Y-%m-%dT%H:%M:%S"),
          "year" => date.year,
          "title" => title,
          "seo_title" => truncate(title, 50),
          "text" => text,
          "excerpt" => excerpt(text, "No video description was included in the export."),
          "description" => meta_description(text, [], date, "Video"),
          "filename" => row["filename"],
          "transcript" => clean_text(row["transcript"]),
          "url" => "/videos/#{row['video_id']}.html",
          "post_url" => nil,
          "post_title" => nil
        }
      end

      videos.sort_by { |video| -video["date"].to_time.to_i }
    end

    def link_records(posts, videos)
      videos_by_filename = videos.each_with_object({}) do |video, index|
        index[video["filename"]] = video
      end

      posts.each do |post|
        filename = post["matched_filenames"].first
        video = filename && videos_by_filename[filename]
        next unless video

        post["video_id"] = video["id"]
        post["video_url"] = video["url"]
        post["video_title"] = video["title"]
        video["post_url"] = post["url"]
        video["post_title"] = post["title"]
      end
    end

    def add_post_pages(posts)
      posts.each do |post|
        page = page_at("posts/#{post['id']}.html")
        page.data.merge!(
          "layout" => "post",
          "title" => post["title"],
          "seo_title" => post["seo_title"],
          "description" => post["description"],
          "date" => post["date"].to_time,
          "date_iso" => post["date_iso"],
          "date_display" => post["date_display"],
          "record_id" => post["record_id"],
          "text" => post["text"],
          "links" => post["links"],
          "media_count" => post["media_count"],
          "video_url" => post["video_url"],
          "video_title" => post["video_title"],
          "transcript" => post["transcript"],
          "facebook_url" => post["facebook_url"],
          "section" => "posts",
          "permalink" => post["url"],
          "sitemap" => true,
          "schema" => post_schema(post)
        )
        add_page(page)
      end
    end

    def add_video_pages(videos)
      videos.each do |video|
        page = page_at("videos/#{video['id']}.html")
        page.data.merge!(
          "layout" => "video",
          "title" => video["title"],
          "seo_title" => video["seo_title"],
          "description" => video["description"],
          "date_iso" => video["date_iso"],
          "date_display" => video["date_display"],
          "record_id" => video["record_id"],
          "text" => video["text"],
          "filename" => video["filename"],
          "transcript" => video["transcript"],
          "post_url" => video["post_url"],
          "post_title" => video["post_title"],
          "section" => "videos",
          "permalink" => video["url"],
          "sitemap" => true,
          "schema" => video_schema(video)
        )
        add_page(page)
      end
    end

    def add_all_page(items, kind)
      page = @site.pages.find { |candidate| candidate.data["archive"] == kind }
      return unless page

      page.data["items"] = items
      page.data["groups"] = groups_by_year(items)
      page.data["total_count"] = items.length
      page.data["schema"] = collection_schema(page)

      @site.data["archive_total_#{kind}"] = items.length
    end

    def add_pagination(items, kind, per_page, base_path)
      source = @site.pages.find { |candidate| candidate.data["paginate"] == kind }
      return unless source

      total_pages = [(items.length.to_f / per_page).ceil, 1].max
      base_title = source.data["title"]
      base_description = source.data["description"]

      total_pages.times do |index|
        number = index + 1
        url = page_url(base_path, number)
        chunk = items[(number - 1) * per_page, per_page] || []
        title = number == 1 ? base_title : "#{base_title}, page #{number}"
        description = if number == 1
                        base_description
                      else
                        "Page #{number} of #{total_pages} in the #{kind == 'videos' ? 'video' : 'post'} archive, ordered by date."
                      end

        page = number == 1 ? source : build_page(base_path, number)
        page.data["pager"] = pager(items, chunk, per_page, number, total_pages, base_path)
        page.data["title"] = title
        page.data["description"] = description
        page.data["sitemap"] = true
        page.data["schema"] = collection_schema(page, chunk, (number - 1) * per_page, url)

        next if number == 1

        page.data["layout"] = source.data["layout"]
        page.data["section"] = source.data["section"]
        page.data["paginate"] = kind
        page.data["all_url"] = source.data["all_url"]
        page.data["eyebrow"] = source.data["eyebrow"]
        page.data["permalink"] = url
        page.content = ""
        add_page(page)
      end
    end

    def pager(items, chunk, per_page, number, total_pages, base_path)
      {
        "items" => chunk,
        "page" => number,
        "per_page" => per_page,
        "total_pages" => total_pages,
        "total_count" => items.length,
        "previous_url" => number > 1 ? page_url(base_path, number - 1) : nil,
        "next_url" => number < total_pages ? page_url(base_path, number + 1) : nil
      }
    end

    def build_page(base_path, number)
      path = page_url(base_path, number).sub(%r{\A/}, "").sub(%r{/\z}, "")
      page_at("#{path}/index.html")
    end

    def page_at(path)
      directory = File.dirname(path)
      name = File.basename(path)
      Jekyll::PageWithoutAFile.new(@site, @site.source, directory == "." ? "" : directory, name)
    end

    def add_page(page)
      page.content = ""
      @site.pages << page
    end

    def page_url(base_path, number)
      return base_path if number == 1

      "#{base_path}page/#{number}/"
    end

    def collection_schema(page, items = nil, start = 0, url = nil)
      canonical = absolute_url(url || page.url)
      schema = {
        "@type" => "CollectionPage",
        "@id" => canonical,
        "url" => canonical,
        "name" => page.data["title"],
        "description" => page.data["description"],
        "inLanguage" => "en-AU",
        "isPartOf" => { "@type" => "WebSite", "@id" => absolute_url("/") + "#website" }
      }

      if items
        schema["mainEntity"] = {
          "@type" => "ItemList",
          "numberOfItems" => items.length,
          "itemListOrder" => "https://schema.org/ItemListOrderDescending",
          "itemListElement" => items.each_with_index.map do |item, index|
            {
              "@type" => "ListItem",
              "position" => start + index + 1,
              "url" => absolute_url(item["url"]),
              "name" => item["title"]
            }
          end
        }
      end

      schema
    end

    def post_schema(post)
      schema = {
        "@type" => "SocialMediaPosting",
        "@id" => absolute_url(post["url"]) + "#post",
        "url" => absolute_url(post["url"]),
        "headline" => post["title"],
        "datePublished" => post["date_iso"],
        "dateModified" => post["date_iso"],
        "inLanguage" => "en-AU",
        "author" => person_ref,
        "publisher" => publisher_ref,
        "isPartOf" => { "@type" => "CollectionPage", "@id" => absolute_url("/") },
        "mainEntityOfPage" => { "@type" => "WebPage", "@id" => absolute_url(post["url"]) }
      }

      schema["articleBody"] = post["text"] unless post["text"].empty?
      schema["sharedContent"] = post["links"].map { |link| { "@type" => "CreativeWork", "url" => link["url"] } } if post["links"].any?
      schema["associatedMedia"] = { "@type" => "VideoObject", "@id" => absolute_url(post["video_url"]) + "#video" } if post["video_url"]
      schema
    end

    def video_schema(video)
      schema = {
        "@type" => "VideoObject",
        "@id" => absolute_url(video["url"]) + "#video",
        "url" => absolute_url(video["url"]),
        "name" => video["title"],
        "description" => video["description"],
        "uploadDate" => video["date_iso"],
        "inLanguage" => "en-AU",
        "identifier" => video["filename"],
        "author" => person_ref,
        "publisher" => publisher_ref,
        "isPartOf" => { "@type" => "CollectionPage", "@id" => absolute_url("/videos/") },
        "mainEntityOfPage" => { "@type" => "WebPage", "@id" => absolute_url(video["url"]) }
      }

      schema["abstract"] = video["text"] unless video["text"].empty?
      schema["transcript"] = video["transcript"] unless video["transcript"].empty?
      schema
    end

    def person_ref
      {
        "@type" => "Person",
        "@id" => absolute_url("/about/") + "#nathan-lambert",
        "name" => "Nathan Lambert",
        "jobTitle" => "Member for Preston, Victorian Legislative Assembly"
      }
    end

    def publisher_ref
      {
        "@type" => "Organization",
        "name" => "Nathan Lambert Archive",
        "url" => absolute_url("/")
      }
    end

    def groups_by_year(items)
      items.group_by { |item| item["year"] }
           .sort_by { |year, _| -year }
           .map { |year, group| { "year" => year.to_s, "items" => group } }
    end

    def derive_title(text, fallback, links, date, kind)
      first_line = text.lines.map(&:strip).find { |line| !line.empty? }
      return truncate(first_line, 110) if first_line
      return "Shared link: #{domain(links.first['url'])}" if links.any?
      return fallback.strip unless fallback.to_s.strip.empty?

      "#{kind} from #{date.strftime('%-d %B %Y')}"
    end

    def meta_description(text, links, date, kind)
      unless text.empty?
        lines = text.lines.map(&:strip).reject { |line| line.empty? || line.match?(/\A[[:punct:]]+\z/) }
        return truncate(lines.join(" "), 155)
      end

      return "A shared link from Nathan Lambert's public Facebook activity on #{date.strftime('%-d %B %Y')}." if links.any?

      "#{kind} record from #{date.strftime('%-d %B %Y')} in the Nathan Lambert Archive."
    end

    def excerpt(text, fallback)
      return fallback if text.empty?

      lines = text.lines.map(&:strip).reject { |line| line.empty? || line.match?(/\A[[:punct:]]+\z/) }
      truncate(lines.join(" "), 220)
    end

    def truncate(text, limit)
      return text if text.length <= limit

      clipped = text[0, limit].sub(/\s+\S*\z/, "")
      "#{clipped}…"
    end

    def parse_links(raw)
      raw.to_s.lines.map(&:strip)
         .select { |line| line.match?(%r{\Ahttps?://}) }
         .uniq
         .map { |url| { "url" => url, "label" => url } }
    end

    def parse_paths(raw)
      raw.to_s.lines.map(&:strip).reject(&:empty?).map { |path| File.basename(path) }
    end

    def clean_text(value)
      value.to_s
           .gsub(/@\[\d+:\d+:([^\]]+)\]/, '\1')
           .gsub(/\\([:\[\]])/, '\1')
           .gsub(/\r\n?/, "\n")
           .strip
    end

    def domain(url)
      url.sub(%r{\Ahttps?://}, "").split("/").first.to_s.sub(/\Awww\./, "")
    end

    def absolute_url(path)
      base = @site.config["url"].to_s.sub(%r{/\z}, "")
      baseurl = @site.config["baseurl"].to_s.sub(%r{/\z}, "")
      "#{base}#{baseurl}#{path}"
    end

    def read_csv(name)
      CSV.read(File.join(@site.source, "data", name), headers: true, encoding: "bom|utf-8")
    end

    def validate_rows(rows, key, label)
      ids = rows.map { |row| row[key] }
      raise "Missing or unsafe #{key} in #{label}" unless ids.all? { |id| id&.match?(/\A[A-Za-z0-9_-]+\z/) }

      duplicates = ids.tally.select { |_, count| count > 1 }.keys
      raise "Duplicate #{key} in #{label}: #{duplicates.first(5).join(', ')}" if duplicates.any?
    end
  end
end

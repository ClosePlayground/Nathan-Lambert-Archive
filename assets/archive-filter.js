(() => {
  const filter = document.querySelector("[data-archive-filter]");
  if (!filter) return;

  const queryInput = filter.querySelector("#archive-q");
  const yearSelect = filter.querySelector("#archive-year");
  const resetButton = filter.querySelector(".filter-reset");
  const list = document.getElementById("archive-list");
  const results = document.getElementById("archive-results");
  const resultsList = document.getElementById("archive-results-list");
  const status = document.getElementById("archive-results-status");
  const noun = filter.dataset.kind;
  const indexUrl = filter.dataset.index;
  const resultLimit = 100;
  const labels = noun === "videos" ? ["video", "videos"] : ["post", "posts"];

  let cache = null;
  let loading = null;
  let runId = 0;
  let timer = 0;

  const normalize = (value) =>
    value.toLowerCase().normalize("NFKD").replace(/[\u0300-\u036f]/g, "");

  const labelFor = (count) => (count === 1 ? labels[0] : labels[1]);

  const load = () => {
    if (cache) return Promise.resolve(cache);
    if (!loading) {
      loading = fetch(indexUrl)
        .then((response) => {
          if (!response.ok) throw new Error("Search index unavailable");
          return response.json();
        })
        .then((data) => {
          data.forEach((record) => {
            record.search = normalize(
              [record.title, record.text, record.transcript, record.date].join(" ")
            );
          });
          cache = data;
          return data;
        });
    }
    return loading;
  };

  const makeResult = (record) => {
    const card = document.createElement("article");
    card.className = "card";
    const meta = document.createElement("p");
    meta.className = "meta";
    const time = document.createElement("time");
    time.dateTime = record.date_iso;
    time.textContent = record.date;
    meta.append(time);
    const heading = document.createElement("h2");
    const link = document.createElement("a");
    link.href = record.url;
    link.textContent = record.title;
    heading.append(link);
    const excerpt = document.createElement("p");
    excerpt.className = "card-text";
    excerpt.textContent = record.excerpt;
    card.append(meta, heading, excerpt);
    const tag = noun === "videos" ? "Video record" : record.video_url ? "Video attached" : "";
    if (tag) {
      const tagElement = document.createElement("p");
      tagElement.className = "tag";
      tagElement.textContent = tag;
      card.append(tagElement);
    }
    return card;
  };

  const showResults = (visible) => {
    list.hidden = visible;
    results.hidden = !visible;
  };

  const apply = async () => {
    const query = queryInput.value.trim();
    const year = yearSelect.value;
    const active = Boolean(query || year);
    resetButton.hidden = !active;

    if (!active) {
      runId += 1;
      showResults(false);
      status.textContent = "";
      resultsList.replaceChildren();
      return;
    }

    const current = ++runId;
    showResults(true);
    status.textContent = "Searching...";

    try {
      const data = await load();
      if (current !== runId) return;

      const terms = normalize(query).split(/\s+/).filter(Boolean);
      const matches = data.filter((record) => {
        if (year && String(record.year) !== year) return false;
        if (!terms.length) return true;
        return terms.every((term) => record.search.includes(term));
      });

      resultsList.replaceChildren(...matches.slice(0, resultLimit).map(makeResult));

      if (!matches.length) {
        status.textContent = `No matching ${labelFor(0)} found.`;
      } else if (matches.length > resultLimit) {
        status.textContent = `Showing the first ${resultLimit} of ${matches.length} matching ${labelFor(matches.length)}.`;
      } else {
        status.textContent = `${matches.length} matching ${labelFor(matches.length)}.`;
      }
    } catch (error) {
      if (current !== runId) return;
      status.textContent = "Search is unavailable. Use the full index instead.";
      resultsList.replaceChildren();
    }
  };

  const schedule = () => {
    window.clearTimeout(timer);
    timer = window.setTimeout(apply, 120);
  };

  queryInput.addEventListener("input", schedule);
  yearSelect.addEventListener("change", apply);
  resetButton.addEventListener("click", () => {
    queryInput.value = "";
    yearSelect.value = "";
    apply();
    queryInput.focus();
  });
})();

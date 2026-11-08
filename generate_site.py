(root/'style.css').write_text(css,encoding='utf-8')
def frame(title,content,description='Archive of public Facebook posts and videos from Nathan Lambert MP.'):
 return f'''<!doctype html><html lang="en-AU"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{esc(title)} | Nathan Lambert Archive</title><meta name="description" content="{esc(description[:160])}"><link rel="stylesheet" href="{BASE}style.css"><link rel="canonical" href="{esc(BASE)}"></head><body><header><div class="shell"><a class="brand" href="{BASE}">Nathan Lambert Archive</a><div class="subtitle">Public posts, updates and video descriptions</div><nav><a href="{BASE}">Posts</a><a href="{BASE}videos/">Videos</a></nav></div></header><main class="shell">{content}</main><footer><div class="shell">Unofficial searchable archive assembled from a Facebook data export. Dates shown in Melbourne time. Original media files are not hosted here. Available transcripts are machine-generated and may contain errors.</div></footer></body></html>'''
def canonical(page,html_text):return html_text.replace(f'<link rel="canonical" href="{esc(BASE)}">',f'<link rel="canonical" href="{esc(BASE+page)}">')
def url_links(raw):
 urls=[s.strip() for s in (raw or '').splitlines() if s.strip().startswith(('http://','https://'))]
 return '<ul>'+''.join(f'<li><a href="{esc(u)}" rel="noopener noreferrer">{esc(u)}</a></li>' for u in urls)+'</ul>' if urls else ''
for p in posts:
 id=p['archive_id']; text=bodytext(p); title=heading(p)
 warning='<p class="notice">This export record does not include the original post text. It may represent a shared link or another type of Facebook activity.</p>' if not text else ''
 media='<p class="meta">Media files referenced in the export: '+esc(p['media_count'])+'. The original media files are not hosted here.</p>' if p['media_count'] not in ('','0') else ''
 content=f'<article class="article"><p><a href="{BASE}">← All posts</a></p><p class="meta">{date(p["timestamp_unix"])} · {esc(id)}</p><h1>{esc(title)}</h1><p class="meta">{esc(p["post_title"])}</p>{warning}<div class="posttext">{esc(text)}</div>{media}'
 if p['shared_links']:content+='<h2>Links in export</h2><div class="links">'+url_links(p['shared_links'])+'</div>'
 if p['original_facebook_url'].startswith('https://'):content+=f'<p><a href="{esc(p["original_facebook_url"])}">View original Facebook post</a></p>'
 if readable(p['transcript']):content+='<h2>Transcript</h2><div class="posttext">'+esc(p['transcript'])+'</div>'
 content+='</article>'
 path=f'posts/{id}.html'
 (root/path).write_text(canonical(path,frame(title,content,description=text or title)),encoding='utf-8')
for v in videos:
 id=v['video_id']; desc=readable(v['video_description']); title=next((s.strip() for s in desc.splitlines() if s.strip()),'Video record')
 title=title[:110]
 content=f'<article class="article"><p><a href="{BASE}videos/">← All videos</a></p><p class="meta">{esc(v["date_melbourne"][:10])} · {esc(id)}</p><h1>{esc(title)}</h1><p class="meta">Source media filename: {esc(v["filename"])}</p>'
 if desc:content+='<h2>Video description</h2><div class="posttext">'+esc(desc)+'</div>'
 else:content+='<p class="notice">No description was included in the export for this video.</p>'
 if readable(v['transcript']):content+='<h2>Spoken-word transcript</h2><p class="meta">Machine-generated transcription; names and wording may contain errors.</p><div class="posttext">'+esc(v['transcript'])+'</div>'
 else:content+='<p class="notice">Full spoken-word transcript not yet available. The description above is not a transcript.</p>'
 content+='</article>'
 path=f'videos/{id}.html'
 (root/path).write_text(canonical(path,frame(title,content,desc or title)),encoding='utf-8')
# Small searchable JSON index; full body text indexed in individual static pages.
index=[{'id':p['archive_id'],'date':date(p['timestamp_unix']),'year':datetime.fromtimestamp(int(p['timestamp_unix']),ZoneInfo('Australia/Melbourne')).year,'timestamp':int(p['timestamp_unix']),'title':heading(p),'text':bodytext(p),'video':p['matched_video_count'] not in ('','0')} for p in posts]
index.sort(key=lambda p:p['timestamp'],reverse=True)
(root/'search-index.json').write_text(json.dumps(index,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
videoindex=[{'id':v['video_id'],'date':v['date_melbourne'][:10],'title':(next((s.strip() for s in (v['video_description'] or '').splitlines() if s.strip()),'Video record'))[:110],'text':(v['video_description'] or '')+'\n'+(v['transcript'] or '')} for v in videos]
videoindex.sort(key=lambda v:v['date'],reverse=True)
(root/'videos'/'index.json').write_text(json.dumps(videoindex,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
js='''
const $=s=>document.querySelector(s);const state={all:[],filtered:[],page:0};const perPage=30;const section=document.body.dataset.section;const base=document.body.dataset.base;
function element(tag,cls,text){const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e;}
function render(){const host=$('#results');host.replaceChildren();const start=state.page*perPage;const items=state.filtered.slice(start,start+perPage);for(const p of items){const card=element('article','card');const meta=element('div','meta',p.date);const h=element('h2');const a=element('a',null,p.title||'Untitled');a.href=base+(section==='videos'?'videos/':'posts/')+p.id+'.html';h.append(a);const text=element('p',null,(p.text||'No post text in export').slice(0,270)+(p.text&&p.text.length>270?'…':''));card.append(meta,h,text);if(p.video)card.append(element('span','tag','Video attached'));host.append(card);}$('#count').textContent=state.filtered.length.toLocaleString()+' '+(section==='videos'?'videos':'posts')+' found';$('#page').textContent=state.filtered.length?('Page '+(state.page+1)+' of '+Math.ceil(state.filtered.length/perPage)):'';$('#prev').disabled=state.page===0;$('#next').disabled=start+perPage>=state.filtered.length;if(!items.length)host.append(element('p',null,'No matching records.'));}
function filter(){const q=$('#query').value.trim().toLocaleLowerCase();const year=$('#year').value;state.filtered=state.all.filter(p=>(!year||String(p.year||String(p.date).slice(0,4))===year)&&(!q||(p.title+' '+p.text).toLocaleLowerCase().includes(q)));state.page=0;render();}
async function init(){try{const r=await fetch(section==='videos'?'index.json':'search-index.json');if(!r.ok)throw new Error('Could not load search index');state.all=await r.json();const years=[...new Set(state.all.map(p=>String(p.year||String(p.date).slice(0,4))))].sort().reverse();for(const y of years){const opt=document.createElement('option');opt.value=y;opt.textContent=y;$('#year').append(opt);}$('#query').addEventListener('input',filter);$('#year').addEventListener('change',filter);$('#prev').addEventListener('click',()=>{state.page--;render();window.scrollTo({top:0,behavior:'smooth'});});$('#next').addEventListener('click',()=>{state.page++;render();window.scrollTo({top:0,behavior:'smooth'});});filter();}catch(e){$('#count').textContent='Unable to load the archive. Please refresh the page.';}}
init();
'''
(root/'site.js').write_text(js,encoding='utf-8')
controls='''<div class="toolbar"><label for="query" class="meta">Search posts<br><input id="query" type="search" placeholder="Search topics, places, keywords"></label><label for="year" class="meta">Filter by year<br><select id="year"><option value="">All years</option></select></label></div><p class="count" id="count" role="status">Loading archive…</p><div id="results" class="cards"></div><div class="pager"><button id="prev" type="button">Previous</button><span id="page"></span><button id="next" type="button">Next</button></div>'''
landing=frame('Search Facebook posts','<h1>Facebook posts archive</h1><p class="intro">Search public updates from Nathan Lambert MP, including local issues in Preston and Reservoir, parliamentary work and community announcements. Each record has its own permanent webpage for easier linking and search engine discovery.</p><div class="notice">This archive is based on a Facebook data export. Some shared links have no accompanying text. Original media files are not hosted. Machine-generated transcripts are available for some videos.</div>'+controls)
landing=landing.replace('</head>','<script src="site.js" defer></script></head>').replace('<body>','<body data-section="posts" data-base="'+BASE+'">')
(root/'index.html').write_text(landing,encoding='utf-8')
vl=frame('Video archive','<h1>Video archive</h1><p class="intro">Browse video descriptions and search available machine-generated spoken-word transcripts from the Facebook export.</p>'+controls)
vl=canonical('videos/',vl).replace('</head>','<script src="'+BASE+'site.js" defer></script></head>').replace('<body>','<body data-section="videos" data-base="'+BASE+'">')
(root/'videos'/'index.html').write_text(vl,encoding='utf-8')
urls=['', 'videos/']+[f'posts/{p["archive_id"]}.html' for p in posts]+[f'videos/{v["video_id"]}.html' for v in videos]
(root/'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'+''.join('<url><loc>'+xesc(BASE+u)+'</loc></url>\n' for u in urls)+'</urlset>',encoding='utf-8')
(root/'robots.txt').write_text('User-agent: *\nAllow: /\nSitemap: '+BASE+'sitemap.xml\n',encoding='utf-8')
(root/'.nojekyll').write_text('',encoding='utf-8')
# Verify every source record has its own output page.
for p in posts:
 assert (root/'posts'/f"{p['archive_id']}.html").is_file()
for v in videos:
 assert (root/'videos'/f"{v['video_id']}.html").is_file()
assert len(list(root.rglob('*.html')))==len(posts)+len(videos)+2
print('PASS: posts',len(posts),'videos',len(videos),'html pages',len(list(root.rglob('*.html'))))

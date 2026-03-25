---
name: hs-search
description: >
  Search health-samurai.io — docs, blog, case studies, examples.
  Use when user asks about Aidbox, Health Samurai products, or needs to find
  specific documentation, blog posts, pricing, or current product details.
---

# Health Samurai Site Search

Search health-samurai.io content: docs, blog, case studies, landing pages, code examples. Returns up-to-date information with links to source pages.

## Search

```bash
curl -s 'http://localhost:4444/api/llm/search?q=keywords+here&limit=10'
# Optional: &section=docs|blog|landing — filter by content type
```

Returns `{ results: [{ title, url, snippet }], query, total }`.

Use keywords, not full sentences. URL-encode `$` as `%24`. Always single-quote the URL in curl.

## Full page content

When snippets aren't enough (how-to, setup guides, code examples), fetch the `.md` version. Strip `#anchor` from `url`, append `.md`:

```bash
# search result url: /docs/aidbox/access-control/authorization/access-policies#structure
# → strip anchor, add .md:
curl -s 'http://localhost:4444/docs/aidbox/access-control/authorization/access-policies.md'
```

Works for `/docs/...`, `/articles/...`, and top-level pages (`/aidbox.md`, `/price.md`). Not available for GitHub example URLs. Fetch one page at a time — pages can be large.

## Site overview

For broad questions ("what products exist?", "what docs are available?"):

```bash
curl -s 'http://localhost:4444/llms.txt'           # site overview
curl -s 'http://localhost:4444/docs/aidbox/llms.txt' # aidbox docs tree
```

## Answer guidelines

- Be concise: 5-10 sentences with links. Expand only if the user asks for details.
- Include ALL relevant links from search results — docs, articles, AND GitHub examples. Don't drop useful URLs.
- All links to the user MUST use `https://health-samurai.io` as base URL (not docs.aidbox.app). Exception: GitHub URLs from results — use as-is.
- Always end your answer with source links.

## Example

User: "How do I configure access policies in Aidbox?"

```bash
# 1. Search
curl -s 'http://localhost:4444/api/llm/search?q=AccessPolicy'
# 2. Best result: url=/docs/aidbox/access-control/authorization/access-policies#structure
# 3. Snippet too short → fetch full page
curl -s 'http://localhost:4444/docs/aidbox/access-control/authorization/access-policies.md'
# 4. Answer from full content, link to the page with https://health-samurai.io base
```

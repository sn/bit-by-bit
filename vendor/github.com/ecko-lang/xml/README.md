# XML - Ecko Std Lib Package

An XML parser for [Ecko](https://ecko.sh), written in Ecko. Parse a document
into a node tree, query it by tag or path, extract text, and rebuild.

Enough for the XML that APIs answer in: S3 and GCS listings, WebDAV, RSS,
SOAP. Pure computation - no capabilities.

## Install

```bash
ecko get github.com/ecko-lang/xml
```

```ecko
import xml
```

Needs Ecko 0.65.0 or later.

## Usage

```ecko
import xml

doc = xml.parse(rss_source)

xml.find(doc, "item")           # every <item> descendant
xml.find(doc, "channel/item")   # path query: <item> under <channel>
xml.find_one(doc, "title")      # the first <title>, or null
xml.text(node)                  # concatenated text content
xml.text(doc, "channel/title")  # text of the first match, or null
xml.attr(node, "id")            # attribute value (case-sensitive), or null
xml.build(node)                 # recompose to an XML string
xml.escape("R&D <draft>")       # "R&amp;D &lt;draft&gt;"
```

An S3 `ListObjectsV2` page:

```ecko
doc = xml.parse(resp.body)
for c in xml.find(doc, "Contents") {
    key = xml.text(c, "Key")
    size = int(xml.text(c, "Size"))
    etag = xml.text(c, "ETag")        # "\"9b2c...\"" - &quot; already decoded
}
if xml.text(doc, "IsTruncated") == "true" {
    token = xml.text(doc, "NextContinuationToken")
}
```

A node is a map: elements are `{ tag, attrs, children }`, text is
`{ tag: "#text", text }`, and the root is `{ tag: "#root", ... }`.

Malformed input throws, so catch it where the document comes from outside:

```ecko
try {
    doc = xml.parse(body)
} catch (e) {
    match get(e, "kind") {
        "parse" => print("bad XML ({e.reason}) at line {e.line}, column {e.column}")
        "limit" => print("document too large or too deep: {e.message}")
        _ => error(e)
    }
}
```

## API

| Function | Description |
|---|---|
| `parse(src, max_depth = 256, max_size = 16777216)` | Parse XML into a `#root` node tree. Entities and character references are decoded, CDATA becomes text. Throws on malformed input (see Notes) |
| `find(node, path)` | A list. A bare tag matches all descendants; `"a/b/c"` navigates (first segment matches descendants, each further segment its children) |
| `find_all(node, path)` | The same list as `find`, named to read beside `find_one` |
| `find_one(node, path)` | The first match of `find`, or `null` |
| `text(node)` | Concatenated descendant text |
| `text(node, path)` | The text of `find_one(node, path)`, or `null` when nothing matches |
| `attr(node, name)` | Attribute value (case-sensitive), or `null` |
| `build(node)` | Recompose to an XML string (attrs sorted; empty elements self-close; text and attribute values escaped) |
| `escape(s)` | Replace `& < > " '` with entities - safe as text or a quoted attribute value |
| `unescape(s)` | Decode the five predefined entities and numeric references |

Errors from `parse` (and `unescape`) are maps:

```
{ kind: "parse", format: "xml", reason, message, offset, line, column }
```

`offset` counts characters from the start of the document; `line` and
`column` are 1-based. `reason` is stable and is one of:

| reason | cause |
|---|---|
| `unterminated` | a comment, CDATA section, processing instruction or tag that never closes; also a bare `<` in text |
| `bad_tag` | a tag that does not parse: an unquoted or valueless attribute, `</ a>` |
| `mismatched_tag` | `</c>` where `</b>` was due; the message names where `<b>` opened |
| `unexpected_close` | a closing tag with nothing open |
| `unclosed` | the document ends with an element still open (the position is its start tag) |
| `duplicate_attribute` | the same attribute twice on one element |
| `bad_entity` | a `&` that does not begin `&name;` |
| `unknown_entity` | an entity other than the five predefined ones, such as `&nbsp;` |
| `bad_char_ref` | `&#...;` that is not a number, or not a character XML allows |
| `doctype_subset` | a `<!DOCTYPE ... [ ... ]>` with an internal subset |
| `bad_declaration` | `<!ELEMENT>` and similar outside a DOCTYPE, or a DOCTYPE after the root |
| `text_outside_root` | non-whitespace text or CDATA outside every element |
| `no_root` | no element at all, including an empty string |

Over a ceiling, `parse` throws
`{ kind: "limit", format: "xml", limit: "max_size" | "max_depth", max, message, ... }`.

## Notes

- **Malformed input throws.** Before 0.38.0 the parser accepted anything:
  `<a><b>x</c></a>` and an unclosed `<b>` both came back as trees. A
  truncated download or an HTML error page now fails at the line that is
  wrong rather than producing a quietly wrong answer.
- **Entities are decoded.** Before 0.38.0, `<ETag>&quot;abc&quot;</ETag>` came back as
  the literal `&quot;abc&quot;`. It is now `"abc"`, in attribute values too.
  Code that unescaped by hand should stop, or `&amp;lt;` will be decoded
  twice. `build` escapes on the way out, so `build(parse(x))` still parses
  back to the same tree.
- **CDATA is text.** Its content becomes a `#text` node verbatim. 0.37
  dropped it.
- **No DTDs, by decision.** Only the five predefined entities and numeric
  references exist. A DOCTYPE with an internal subset is refused outright
  rather than parsed, so entity-expansion attacks ("billion laughs") have
  nothing to expand. A DOCTYPE without a subset is skipped, and an external
  DTD it names is never fetched.
- **Bounded.** `max_size` (characters, default 16 MiB) is checked before any
  parsing; `max_depth` (default 256) caps element nesting. Both throw kind
  `limit`, the same kind as the runtime's own ceilings. Raise them per call:
  `xml.parse(src, max_depth: 1024)`.
- **Fragments are allowed.** Several top-level elements parse as siblings
  under `#root`, as before. Text outside them must be whitespace.
- **Whitespace is kept.** Whitespace between elements stays as `#text`
  nodes, as in 0.37, so existing trees are unchanged. `text(node, path)` and
  `find` are unaffected by it.
- **Namespaces stay as written.** `s3:Key` is a tag named `s3:Key`; it does
  not match `find(doc, "Key")`, and `xmlns` is an ordinary attribute. S3
  uses a default namespace, so its tags have no prefix.
- Case-sensitive tags and attributes (unlike the `html` package).
- Attribute values are not whitespace-normalised.
- Speed: one native tokenising pass, then a linear walk. A 1 MB S3 listing
  (4,000 objects) parses in about 0.8 s.

## Testing

```bash
ecko test tests/
```

## License

MIT - see [LICENSE](LICENSE).

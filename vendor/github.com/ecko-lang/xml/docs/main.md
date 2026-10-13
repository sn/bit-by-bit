# xml

## `parse(src, max_depth = 256, max_size = 16777216)`

Parse an XML document into a node tree. The root is a `#root` node whose
children are the top-level elements; text becomes `#text` nodes, with the
five predefined entities (`&amp;` `&lt;` `&gt;` `&quot;` `&apos;`) and
numeric references (`&#65;`, `&#x41;`) decoded. CDATA content becomes a
`#text` node verbatim. Comments, processing instructions, the `<?xml ?>`
declaration and a plain `<!DOCTYPE>` are skipped.

Malformed input throws `{ kind: "parse", format: "xml", reason, message,
offset, line, column }`; `reason` is one of `unterminated`, `bad_tag`,
`mismatched_tag`, `unexpected_close`, `unclosed`, `duplicate_attribute`,
`bad_entity`, `unknown_entity`, `bad_char_ref`, `doctype_subset`,
`bad_declaration`, `text_outside_root` or `no_root`. A DOCTYPE with an
internal subset (`[...]`) is refused rather than expanded.

Input over `max_size` characters, or nesting deeper than `max_depth`
elements, throws `{ kind: "limit", limit: "max_size" | "max_depth", max, ... }`.

```ecko
doc = xml.parse("<a><b>x &amp; y</b></a>")
xml.text(doc, "b")   # "x & y"
```

## `find(node, path)`

find(node, path) - a single tag matches descendants; "a/b/c" navigates:
the first segment matches descendants, each further segment its children.
Always returns a list, in document order; `[]` when nothing matches.
Tags compare exactly, namespace prefix included (`s3:Key` is not `Key`).

## `find_all(node, path)`

find_all(node, path) - the same list `find` returns, under the name that
reads clearly beside `find_one`.

## `find_one(node, path)`

find_one(node, path) - the first match of `find(node, path)`, or null.
A bare tag stops at the first match instead of collecting them all.

```ecko
token = xml.find_one(doc, "NextContinuationToken")
```

## `text(node, path = null)`

text(node) - all text under a node, concatenated: the element's own text
plus every descendant's, in document order. Returns "" for an element
with no text.

text(node, path) - the text of `find_one(node, path)`, or null when
nothing matches. This is the S3 shape: `xml.text(item, "Key")`.

## `attr(node, name)`

One attribute's value, or null when the node has no such attribute.

## `escape(s)`

escape(s) - replace `&`, `<`, `>`, `"` and `'` with their entities, so `s`
is safe as element text or as a quoted attribute value.

```ecko
"<Key>" + xml.escape("a&b.txt") + "</Key>"   # "<Key>a&amp;b.txt</Key>"
```

## `unescape(s)`

unescape(s) - decode the five predefined entities and numeric character
references in `s`. An unknown or unterminated entity throws the same
`{ kind: "parse", format: "xml", ... }` error `parse` does, with the
offset into `s`.

## `build(node)`

build(node) -> an XML string (attrs sorted; empty elements self-close).
Text is escaped (`&`, `<`, `>`) and attribute values also escape `"`, so
the output parses back to the same tree.

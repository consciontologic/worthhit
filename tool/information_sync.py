"""Generate safe Flutter information content from the canonical static documents."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlsplit
import argparse
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
NAMES = ('about', 'terms', 'liability')
TARGET = 'lib/ui/information_content.g.dart'


class Node:
    def __init__(self, tag='', attrs=()):
        self.tag, self.attrs, self.children = tag, dict(attrs), []

    def descendants(self, tag):
        for child in self.children:
            if isinstance(child, Node):
                if child.tag == tag:
                    yield child
                yield from child.descendants(tag)

    def text(self):
        return ''.join(child.text() if isinstance(child, Node) and child.tag != 'svg'
                       else '' if isinstance(child, Node) else child for child in self.children)


class DocumentParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node()
        self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs)
        self.stack[-1].children.append(node)
        if tag not in {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'}:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.stack[-1].children.append(Node(tag, attrs))

    def handle_endtag(self, tag):
        if len(self.stack) < 2 or self.stack[-1].tag != tag:
            raise ValueError(f'Unbalanced canonical HTML: {tag}')
        self.stack.pop()

    def handle_data(self, data):
        self.stack[-1].children.append(data)


def one(nodes, description):
    nodes = list(nodes)
    if len(nodes) != 1:
        raise ValueError(f'Expected exactly one {description}')
    return nodes[0]


def safe_link(href, name):
    parsed = urlsplit(urljoin(f'https://worthhit.com/{name}/', href))
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError('Unsupported information link')
    if parsed.hostname == 'worthhit.com':
        path = parsed.path.strip('/')
        if path not in NAMES or parsed.query:
            raise ValueError('Unsupported internal information link')
        if parsed.fragment and not re.fullmatch('[a-z][a-z0-9-]*', parsed.fragment):
            raise ValueError('Unsupported section anchor')
        return '/' + path + ('?section=' + parsed.fragment if parsed.fragment else '')
    return parsed.geturl()


def inline(node, name, *, strong=False, href=None):
    spans = []
    for child in node.children:
        if isinstance(child, str):
            if child:
                spans.append({'text': child, **({'strong': True} if strong else {}),
                              **({'href': href} if href else {})})
        elif child.tag == 'svg':
            continue
        elif child.tag == 'strong':
            spans.extend(inline(child, name, strong=True, href=href))
        elif child.tag == 'a' and href is None:
            spans.extend(inline(child, name, strong=strong, href=safe_link(child.attrs['href'], name)))
        else:
            raise ValueError(f'Unsupported inline content: {child.tag}')
    return spans


def parse_document(source, name):
    parser = DocumentParser()
    parser.feed(source)
    main = one(parser.root.descendants('main'), 'main')
    article = one(main.descendants('article'), 'article')
    heading = one((n for n in main.descendants('div') if n.attrs.get('class') == 'page-heading'), 'page heading')
    result = {
        'title': one(heading.descendants('h1'), 'title').text().strip(),
        'lead': one((n for n in heading.descendants('p') if n.attrs.get('class') == 'lead'), 'lead').text().strip(),
        'updated': one((n for n in heading.descendants('p') if n.attrs.get('class') == 'updated'), 'date').text().strip(),
        'sections': [],
    }
    for section in article.children:
        if isinstance(section, str) and not section.strip():
            continue
        if not isinstance(section, Node) or section.tag != 'section':
            raise ValueError('Unsupported article block')
        entry = {'id': section.attrs['id'], 'title': one(section.descendants('h2'), 'section title').text().strip(), 'blocks': []}
        for block in section.children:
            if isinstance(block, str) and not block.strip():
                continue
            if isinstance(block, Node) and block.tag == 'h2':
                continue
            if not isinstance(block, Node) or block.tag not in {'p', 'ol', 'ul'}:
                raise ValueError('Unsupported information block')
            if block.tag == 'p':
                entry['blocks'].append({'type': 'paragraph', 'paragraphs': [inline(block, name)]})
            else:
                items = [node for node in block.children if not isinstance(node, str) or node.strip()]
                if any(not isinstance(node, Node) or node.tag != 'li' for node in items):
                    raise ValueError('Unsupported list item')
                entry['blocks'].append({'type': 'ordered' if block.tag == 'ol' else 'unordered',
                                        'paragraphs': [inline(item, name) for item in items]})
        result['sections'].append(entry)
    ids = [section['id'] for section in result['sections']]
    if not ids or len(ids) != len(set(ids)):
        raise ValueError('Missing or duplicate section identities')
    return result


def documents(root=ROOT):
    result = {name: parse_document((root / f'web/{name}/index.html').read_text(), name) for name in NAMES}
    for doc in result.values():
        for section in doc['sections']:
            for block in section['blocks']:
                for paragraph in block['paragraphs']:
                    for span in paragraph:
                        link = span.get('href', '')
                        if '?section=' in link and link.startswith('/'):
                            destination, anchor = link[1:].split('?section=')
                            if anchor not in {s['id'] for s in result[destination]['sections']}:
                                raise ValueError('Broken information section link')
    return result


def synchronize(root=ROOT, *, write=False):
    data = json.dumps(documents(root), ensure_ascii=False, indent=2).replace('$', r'\$')
    content = ('// Generated by tool/information_sync.py from canonical web documents.\n'
               '// Do not edit by hand. Run make information.sync after changing prose.\n'
               '// dart format off\n'
               'const informationContent = <String, dynamic>' + data + ';\n')
    target = root / TARGET
    changed = not target.exists() or target.read_text() != content
    if changed and write:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    if synchronize(write=args.write) and not args.write:
        print('Information content drift; run make information.sync.', file=sys.stderr)
        return 1
    print('Information content matches canonical documents.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

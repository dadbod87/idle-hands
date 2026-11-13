"""Sync the editable office panel into the existing single-file client. No network."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
path = root / 'index.html'
source = path.read_text()
start = '/* BEGIN NEXT WEEK UI */'
end = '/* END NEXT WEEK UI */'
if source.count(start) != 1 or source.count(end) != 1:
    raise SystemExit('Expected one office UI block; inspect the client before generating')
a = source.index(start)
b = source.index(end, a) + len(end)
panel = (root / 'tools/next-week-ui.jsx').read_text() + '\n' + (root / 'tools/office-boutique-ui.jsx').read_text() + '\n' + (root / 'tools/weekly-race-ui.jsx').read_text()
path.write_text(source[:a] + start + '\n' + panel + '\n' + end + source[b:])
print('Updated generated UI')

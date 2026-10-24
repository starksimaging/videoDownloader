from pathlib import Path
import re
from lxml import etree

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tmp/pdfs/calibre-unpacked/index.html"
WORK = ROOT / "tmp/pdfs/fetter6-clean.html"

tree = etree.parse(str(SOURCE), etree.XMLParser(remove_blank_text=False))
ns = {"x": "http://www.w3.org/1999/xhtml"}
body, head = tree.find("x:body", ns), tree.find("x:head", ns)
X = "{http://www.w3.org/1999/xhtml}"

def text_of(el):
    return " ".join("".join(el.itertext()).replace("\u00a0", " ").split())

for img in list(body.findall(".//x:img", ns)):
    parent = img.getparent(); parent.remove(img)
    if not text_of(parent): parent.getparent().remove(parent)

repairs = {"Pnd":"find", "Nnd":"find", "Pxed":"fixed", "Wy":"fly",
           "Peld":"field", "afPrm":"affirm", "shufWe":"shuffle",
           "BrieWy":"Briefly", "difPcult":"difficult", "Watter":"flatter",
           "Pnally":"finally"}
for node in body.iter():
    if node.text:
        for wrong, right in repairs.items(): node.text = node.text.replace(wrong, right)
        node.text = node.text.replace("\u00a0", " ")
    if node.tail:
        for wrong, right in repairs.items(): node.tail = node.tail.replace(wrong, right)
        node.tail = node.tail.replace("\u00a0", " ")

for p in list(body.findall("x:p", ns)):
    if not text_of(p): body.remove(p)

def exact(text):
    for p in body.findall("x:p", ns):
        if text_of(p) == text: return p
    raise RuntimeError(f"Missing expected text: {text}")

def set_simple(el, tag, text, ident=None):
    el.tag = X + tag; el.clear()
    if ident: el.set("id", ident)
    el.text = text

for first, second, combined in [
    ("3. What You", "Habitually Do", "3. What You Habitually Do"),
    ("4. Finding and", "Working in the Gap", "4. Finding and Working in the Gap"),
    ("5. Things to Keep in", "Mind", "5. Things to Keep in Mind"),
    ("6. Has the Belief", "Disappeared?", "6. Has the Belief Disappeared?"),
]:
    a, b = exact(first), exact(second); set_simple(a, "p", combined); body.remove(b)

title_a, title_b = exact("Self-Inquiry Guide to"), exact("the Sixth Fetter")
set_simple(title_a, "h1", "Self-Inquiry Guide to the Sixth Fetter", "title")
body.remove(title_b)

chapters = [
    ("1. Summary", "summary"), ("2. Being a “Subject”", "being-a-subject"),
    ("3. What You Habitually Do", "habitually-do"),
    ("4. Finding and Working in the Gap", "working-in-the-gap"),
    ("5. Things to Keep in Mind", "things-to-keep-in-mind"),
    ("6. Has the Belief Disappeared?", "has-the-belief-disappeared"),
]
for text, ident in chapters: set_simple(exact(text), "h2", text, ident)
for text, ident in [("The Turning Exercise", "turning-exercise"),
                    ("The Turning-Toward Exercise", "turning-toward-exercise")]:
    set_simple(exact(text), "h3", text, ident)

closing = exact("Simply The Seen")
set_simple(closing, "h2", "Terms, Conditions and Disclaimer", "terms")
body.remove(exact("Terms, Conditions and Disclaimer"))

for el in body.iter(): el.attrib.pop("class", None)
for p in body.findall("x:p", ns):
    if re.match(r"^\d+\.\s", text_of(p)): p.set("class", "step")

for link in list(head.findall("x:link", ns)): head.remove(link)
style = etree.SubElement(head, X + "style", type="text/css")
style.text = """
body { font-family: serif; line-height: 1.45; margin: 5%; }
h1 { text-align: center; margin: 2.5em 0 2em; }
h2 { page-break-before: always; margin-top: 1.5em; }
h3 { margin-top: 1.75em; }
p { margin: 0 0 0.85em; }
p.step { margin-left: 1em; text-indent: -1em; }
"""
head.find("x:title", ns).text = "Simply The Seen: Self-Inquiry Guide to the Sixth Fetter"
tree.write(str(WORK), encoding="utf-8", xml_declaration=True, pretty_print=True)

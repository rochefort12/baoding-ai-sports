"""Image-only six-page annex fixture; every page is a previously inspected notice.

The bundle intentionally contains different events and a conflicting source pair.
It tests bounded scan recognition, not an approved consolidated event notice.
"""
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from pypdf import PdfReader
qa=Path('.local/notice-trial-20261012/qa')
out=Path('.local/notice-trial-20261012/six-scanned-annexes.pdf')
if out.exists():
    raise RuntimeError('Immutable scan fixture already exists')
pdf=canvas.Canvas(str(out),pagesize=A4)
for name in ['01-测试收费双打通知-1.png','02-测试免费社区赛通知-1.png','03-测试缺项通知-1.png','04-测试冲突原通知-1.png','05-测试冲突补充通知-1.png','06-官方盐田通知网页摘录-1.png']:
    pdf.drawImage(str(qa/name),0,0,width=A4[0],height=A4[1],preserveAspectRatio=True)
    pdf.showPage()
pdf.save()
reader=PdfReader(out)
assert len(reader.pages)==6 and all(not page.extract_text() for page in reader.pages)
print('Six-page scan fixture bytes',out.stat().st_size)

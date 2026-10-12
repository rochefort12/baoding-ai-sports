package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.apache.poi.xwpf.usermodel.XWPFTable;
import org.apache.poi.xwpf.usermodel.XWPFTableRow;
import org.dromara.sports.event.ai.LocalDocumentExtractor.Block;
import org.dromara.sports.event.ai.LocalDocumentExtractor.Extracted;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Tag("local")
class LocalDocumentExtractorTest {
    @Test void longWordKeepsEveryParagraphAndAllEmbeddedImagesIncludingTableCells()throws Exception{
        byte[] png;try(var out=new ByteArrayOutputStream()){javax.imageio.ImageIO.write(new java.awt.image.BufferedImage(8,8,java.awt.image.BufferedImage.TYPE_INT_RGB),"png",out);png=out.toByteArray();}
        byte[] original;try(var doc=new XWPFDocument();var out=new ByteArrayOutputStream()){
            for(int i=0;i<222;i++){var p=doc.createParagraph();p.createRun().setText(i==221?"第12条声明：原文末尾。":"资料段落"+i);if(i<12)p.createRun().addPicture(new java.io.ByteArrayInputStream(png),org.apache.poi.xwpf.usermodel.Document.PICTURE_TYPE_PNG,"table.png",org.apache.poi.util.Units.toEMU(8),org.apache.poi.util.Units.toEMU(8));}
            doc.createTable(1,1).getRow(0).getCell(0).getParagraphs().get(0).createRun().addPicture(new java.io.ByteArrayInputStream(png),org.apache.poi.xwpf.usermodel.Document.PICTURE_TYPE_PNG,"cell.png",org.apache.poi.util.Units.toEMU(8),org.apache.poi.util.Units.toEMU(8));doc.write(out);original=out.toByteArray();
        }
        var parsed=LocalDocumentExtractor.extract(0,"docx",original,20);assertEquals(13,parsed.visuals().size());assertTrue(parsed.visuals().get(12).location().contains("第1列"));assertEquals(64,parsed.visuals().get(0).sha256().length());assertTrue(parsed.blocks().get(221).text().contains("原文末尾"));
        org.junit.jupiter.api.Assertions.assertArrayEquals(png,LocalDocumentExtractor.docxImage(original,12));
        var material=AgentMaterials.extract("1","长规程.docx",original);assertEquals(222,material.sources().size());assertEquals(13,material.visuals().size());
    }

    @Test
    void generatedOfficeAndTextPdfKeepLocation() throws Exception {
        Extracted docx = LocalDocumentExtractor.extract(0, "docx", docx(), 15);
        assertEquals("docx", docx.mediaKind());
        assertTrue(docx.blocks().stream().anyMatch(block -> "段落1".equals(block.label()) && block.text().contains("赛事名称：程序生成赛")));
        assertTrue(docx.blocks().stream().anyMatch(block -> block.label().startsWith("表格1") && block.text().contains("男子单打")));

        Extracted xlsx = LocalDocumentExtractor.extract(1, "xlsx", xlsx(), 15);
        assertTrue(xlsx.blocks().stream().anyMatch(block -> block.label().contains("报名") && block.text().contains("比赛地点：市体育中心")));

        Extracted pdf = LocalDocumentExtractor.extract(2, "pdf", textPdf(), 15);
        assertEquals("pdf-text", pdf.mediaKind());
        assertEquals(1, pdf.pageCount());
        assertTrue(pdf.blocks().stream().anyMatch(block -> "第1页".equals(block.label()) && block.text().contains("Event")));

        var proposal = EventProposalHeuristic.draft(new ObjectMapper(), List.of(docx.blocks().get(0), tableBlock(docx)));
        assertEquals("程序生成赛", proposal.path("event").path("name").path("value").asText());
        assertEquals("filled", proposal.path("event").path("name").path("status").asText());
        assertTrue(proposal.path("units").size() >= 1);
    }

    @Test
    void blankPdfIsScanAndStopsAtPageLimit() throws Exception {
        Extracted scan = LocalDocumentExtractor.extract(0, "pdf", blankPdf(2), 15);
        assertEquals("pdf-scan", scan.mediaKind());
        assertEquals(List.of(1, 2), scan.scanPages());
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
            () -> LocalDocumentExtractor.extract(0, "pdf", blankPdf(16), 15));
    }

    private Block tableBlock(Extracted docx) {
        return docx.blocks().stream().filter(block -> block.kind().equals("docx-table")).findFirst().orElseThrow();
    }

    private byte[] docx() throws Exception {
        try (XWPFDocument document = new XWPFDocument(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            document.createParagraph().createRun().setText("赛事名称：程序生成赛");
            document.createParagraph().createRun().setText("比赛地点：市体育中心");
            XWPFTable table = document.createTable(1, 2);
            XWPFTableRow row = table.getRow(0);
            row.getCell(0).setText("男子单打");
            row.getCell(1).setText("名额 32");
            document.write(out);
            return out.toByteArray();
        }
    }

    private byte[] xlsx() throws Exception {
        try (XSSFWorkbook workbook = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            var sheet = workbook.createSheet("报名");
            sheet.createRow(0).createCell(0).setCellValue("比赛地点：市体育中心");
            workbook.write(out);
            return out.toByteArray();
        }
    }

    private byte[] textPdf() throws Exception {
        try (PDDocument document = new PDDocument(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            PDPage page = new PDPage();
            document.addPage(page);
            try (PDPageContentStream stream = new PDPageContentStream(document, page)) {
                stream.beginText();
                stream.setFont(new PDType1Font(Standard14Fonts.FontName.HELVETICA), 12);
                stream.newLineAtOffset(40, 700);
                stream.showText("Event name sample");
                stream.endText();
            }
            document.save(out);
            return out.toByteArray();
        }
    }

    private byte[] blankPdf(int pages) throws Exception {
        try (PDDocument document = new PDDocument(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            for (int index = 0; index < pages; index++) {
                document.addPage(new PDPage());
            }
            document.save(out);
            return out.toByteArray();
        }
    }
}

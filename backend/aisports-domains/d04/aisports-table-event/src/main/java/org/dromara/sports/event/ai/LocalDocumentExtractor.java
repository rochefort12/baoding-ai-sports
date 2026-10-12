package org.dromara.sports.event.ai;

import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.apache.pdfbox.text.PDFTextStripper;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.xssf.usermodel.XSSFSheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.apache.poi.xwpf.usermodel.IBodyElement;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.apache.poi.xwpf.usermodel.XWPFParagraph;
import org.apache.poi.xwpf.usermodel.XWPFTable;
import org.apache.poi.xwpf.usermodel.XWPFTableCell;
import org.apache.poi.xwpf.usermodel.XWPFTableRow;
import org.apache.poi.xwpf.usermodel.XWPFPicture;
import org.dromara.sports.api.DocumentKinds;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.security.MessageDigest;
import java.util.HexFormat;

/**
 * 本地抽出 Word、Excel 和文字版 PDF 的位置。扫描页只记页码，不在这里调用模型。
 */
public final class LocalDocumentExtractor {

    private static final int TEXT_PAGE = 12;

    private LocalDocumentExtractor() {
    }

    public static Extracted extract(int fileIndex, String sniffedMedia, byte[] body, int maxScanPages) {
        try {
            if ("docx".equals(sniffedMedia)) {
                var visuals = new ArrayList<Visual>();
                return new Extracted("docx", null, List.of(), readDocx(fileIndex, body, visuals), visuals);
            }
            if ("xlsx".equals(sniffedMedia)) {
                return new Extracted("xlsx", null, List.of(), readXlsx(fileIndex, body));
            }
            if ("pdf".equals(sniffedMedia)) {
                return readPdf(fileIndex, body, maxScanPages);
            }
            if (DocumentKinds.image(sniffedMedia)) {
                return new Extracted(sniffedMedia, null, List.of(), List.of(
                    new Block(fileIndex, "image", "图片" + (fileIndex + 1), "")));
            }
            throw new IllegalArgumentException("文件类型无法识别");
        } catch (IOException exception) {
            throw new IllegalArgumentException("文件打不开");
        }
    }

    public static byte[] pdfPagePng(byte[] pdf, int pageNumber) {
        if (pageNumber < 1) {
            throw new IllegalArgumentException("页码无效");
        }
        try (PDDocument document = Loader.loadPDF(pdf)) {
            if (pageNumber > document.getNumberOfPages()) {
                throw new IllegalArgumentException("页码无效");
            }
            BufferedImage image = new PDFRenderer(document).renderImageWithDPI(pageNumber - 1, 110);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(image, "png", out);
            return out.toByteArray();
        } catch (IOException exception) {
            throw new IllegalArgumentException("这一页暂时渲染不出来");
        }
    }

    private static Extracted readPdf(int fileIndex, byte[] body, int maxScanPages) throws IOException {
        try (PDDocument document = Loader.loadPDF(body)) {
            int pages = document.getNumberOfPages();
            PDFTextStripper stripper = new PDFTextStripper();
            List<Block> blocks = new ArrayList<>();
            List<Integer> scans = new ArrayList<>();
            for (int page = 1; page <= pages; page++) {
                stripper.setStartPage(page);
                stripper.setEndPage(page);
                String text = stripper.getText(document).trim();
                if (text.length() >= TEXT_PAGE) {
                    blocks.add(new Block(fileIndex, "pdf-page", "第" + page + "页", clip(text)));
                } else {
                    scans.add(page);
                }
            }
            if (scans.size() > maxScanPages) {
                throw new IllegalArgumentException("扫描版 PDF 最多" + maxScanPages + "页");
            }
            String kind = scans.isEmpty() ? "pdf-text" : "pdf-scan";
            return new Extracted(kind, pages, scans, blocks);
        }
    }

    private static List<Block> readDocx(int fileIndex, byte[] body, List<Visual> visuals) throws IOException {
        List<Block> blocks = new ArrayList<>();
        try (XWPFDocument document = new XWPFDocument(new ByteArrayInputStream(body))) {
            int paragraph = 0;
            int table = 0;
            for (IBodyElement element : document.getBodyElements()) {
                if (element instanceof XWPFParagraph para) {
                    paragraph++;
                    String text = para.getText() == null ? "" : para.getText().trim();
                    if (!text.isEmpty()) {
                        addText(blocks,fileIndex,"docx-paragraph","段落"+paragraph,text);
                    }
                    pictures(para,"段落"+paragraph,visuals,blocks.size());
                } else if (element instanceof XWPFTable current) {
                    table++;
                    int rowNo = 0;
                    for (XWPFTableRow row : current.getRows()) {
                        rowNo++;
                        StringBuilder line = new StringBuilder();
                        int cellNo = 0;
                        for (XWPFTableCell cell : row.getTableCells()) {
                            cellNo++;
                            if (cellNo > 1) {
                                line.append(" | ");
                            }
                            line.append(cell.getText() == null ? "" : cell.getText().trim());
                        }
                        String text = line.toString().trim();
                        if (!text.isEmpty()) {
                            addText(blocks,fileIndex,"docx-table","表格"+table+" 第"+rowNo+"行",text);
                        }
                        for(int c=0;c<row.getTableCells().size();c++)cellPictures(row.getTableCells().get(c),"表格"+table+" 第"+rowNo+"行 第"+(c+1)+"列",visuals,blocks.size());
                    }
                }
            }
        }
        return blocks;
    }

    private static List<Block> readXlsx(int fileIndex, byte[] body) throws IOException {
        List<Block> blocks = new ArrayList<>();
        DataFormatter formatter = new DataFormatter();
        try (XSSFWorkbook workbook = new XSSFWorkbook(new ByteArrayInputStream(body))) {
            for (int sheetIndex = 0; sheetIndex < workbook.getNumberOfSheets(); sheetIndex++) {
                XSSFSheet sheet = workbook.getSheetAt(sheetIndex);
                for (Row row : sheet) {
                    for (Cell cell : row) {
                        String text = formatter.formatCellValue(cell).trim();
                        if (!text.isEmpty()) {
                            String label = sheet.getSheetName() + " 行" + (row.getRowNum() + 1) + "列" + (cell.getColumnIndex() + 1);
                            blocks.add(new Block(fileIndex, "xlsx-cell", label, clip(text)));
                        }
                    }
                }
            }
        }
        return blocks;
    }

    private static String clip(String text) {
        String compact = text.replace('\u0000', ' ').trim();
        if(compact.length()>120000)throw new IllegalArgumentException("资料单段超过120000字，请拆分后上传");
        return compact;
    }

    private static void addText(List<Block> blocks,int file,String kind,String location,String value){
        String text=clip(value);
        for(int start=0;start<text.length();start+=2000)blocks.add(new Block(file,kind,location+(text.length()>2000?" · 片段"+(start/2000+1):""),text.substring(start,Math.min(text.length(),start+2000))));
        if(blocks.size()>1000||blocks.stream().mapToInt(b->b.text().length()).sum()>120000)throw new IllegalArgumentException("资料超过1000段或120000字，请拆分后上传；未进行截断");
    }
    private static void pictures(XWPFParagraph paragraph,String location,List<Visual> visuals,int afterBlock){
        for(var run:paragraph.getRuns())for(XWPFPicture picture:run.getEmbeddedPictures()){
            var data=picture.getPictureData();
            if(data==null)throw new IllegalArgumentException("Word含无法读取的图片引用，请嵌入图片后重新上传");
            byte[] bytes=data.getData();
            if(visuals.size()>=40||bytes.length>15*1024*1024)throw new IllegalArgumentException("Word图片超过40张或单张15MB，请拆分后上传");
            try{String hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));String kind;try{kind=DocumentKinds.sniff(bytes).media();}catch(IllegalArgumentException unsupported){kind="unsupported";}visuals.add(new Visual(visuals.size(),location+" · 图片"+(visuals.size()+1),hash,kind,afterBlock));}
            catch(java.security.NoSuchAlgorithmException e){throw new IllegalStateException(e);}
        }
    }
    private static void cellPictures(XWPFTableCell cell,String location,List<Visual> visuals,int afterBlock){
        for(var element:cell.getBodyElements()){
            if(element instanceof XWPFParagraph p)pictures(p,location,visuals,afterBlock);
            else if(element instanceof XWPFTable t)for(var row:t.getRows())for(var nested:row.getTableCells())cellPictures(nested,location+" · 嵌套表格",visuals,afterBlock);
        }
    }
    /** Reads only embedded bytes, never a relationship URL or external resource. */
    public static byte[] docxImage(byte[] body,int index){
        if(index<0||index>=40)throw new IllegalArgumentException("图片序号无效");
        try(var document=new XWPFDocument(new ByteArrayInputStream(body))){
            var pictures=new ArrayList<XWPFPicture>();
            collectPictures(document.getBodyElements(),pictures);
            if(index>=pictures.size()||pictures.get(index).getPictureData()==null)throw new IllegalArgumentException("图片引用不可读取");
            return pictures.get(index).getPictureData().getData();
        }catch(IOException e){throw new IllegalArgumentException("Word图片无法读取");}
    }
    private static void collectPictures(List<IBodyElement> elements,List<XWPFPicture> pictures){
        for(var element:elements){
            if(element instanceof XWPFParagraph p)for(var run:p.getRuns())pictures.addAll(run.getEmbeddedPictures());
            else if(element instanceof XWPFTable t)for(var row:t.getRows())for(var cell:row.getTableCells())collectPictures(cell.getBodyElements(),pictures);
        }
    }

    public record Block(int fileIndex, String kind, String label, String text) {
    }

    public record Visual(int index,String location,String sha256,String kind,int afterBlock) { }
    public record Extracted(String mediaKind, Integer pageCount, List<Integer> scanPages, List<Block> blocks, List<Visual> visuals) {
        public Extracted(String mediaKind,Integer pageCount,List<Integer> scanPages,List<Block> blocks){this(mediaKind,pageCount,scanPages,blocks,List.of());}
    }
}

package org.dromara.sports.event.ai;

import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.AgentMaterialApi;
import org.dromara.sports.api.DocumentKinds;
import org.dromara.sports.api.StoredObjectApi;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.apache.pdfbox.Loader;
import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.*;
import java.security.MessageDigest;
import java.util.*;
import static org.dromara.sports.platform.core.BusinessSupport.fail;

/** Reuses source-file storage and the local extractor; owner + tenant are checked on every reload. */
@Service @RequiredArgsConstructor
public class AgentMaterials implements AgentMaterialApi {
    private final StoredObjectApi files;
    private final JdbcTemplate db;
    public List<Material> retain(long owner,String tenant,List<Upload> uploads) {
        if(uploads==null||uploads.isEmpty()||uploads.size()>4)throw fail("每次请选择1至4份资料",400);
        long total=uploads.stream().mapToLong(u->u.body().length).sum();
        if(total>20L*1024*1024)throw fail("本次资料合计不能超过20MB，请分批补充",400);
        var parsed=new ArrayList<Material>();
        for(var upload:uploads)parsed.add(extract("",upload.name(),upload.body()));
        var retained=new ArrayList<Material>();
        try {for(int i=0;i<uploads.size();i++){var item=parsed.get(i);long id=files.keepDocument(owner,tenant,StoredObjectApi.AI_SOURCE,uploads.get(i).body());retained.add(new Material(Long.toString(id),item.name(),item.kind(),item.sha256(),item.coverage(),item.pageCount(),item.sources(),item.images(),item.visuals()));}return retained;}
        catch(RuntimeException error){for(var item:retained)try{files.discard(Long.parseLong(item.fileId()),StoredObjectApi.AI_SOURCE,tenant);}catch(RuntimeException ignored){}throw error;}
    }
    private void requireOwner(long file,long owner,String tenant){Integer count=db.queryForObject("SELECT count(*) FROM asp_file WHERE id=? AND owner_account_id=? AND owning_tenant_id=? AND purpose='ai-source' AND status='active'",Integer.class,file,owner,tenant);if(count==null||count!=1)throw fail("这份资料不在本次授权范围",403);}
    public Material read(long file,long owner,String tenant,String name){requireOwner(file,owner,tenant);return extract(Long.toString(file),name,files.readOwnedDocument(file,tenant).body());}
    public String image(long file,long owner,String tenant,int index){
        requireOwner(file,owner,tenant);
        byte[] body=files.readOwnedDocument(file,tenant).body();var kind=DocumentKinds.sniff(body);
        var extracted=LocalDocumentExtractor.extract(0,kind.media(),body,20);
        try{
            if(kind.media().equals("docx")){if(index<0||index>=extracted.visuals().size())throw fail("图片序号无效",400);return imageUrl(LocalDocumentExtractor.docxImage(body,index));}
            if(DocumentKinds.image(kind.media())&&index==0)return imageUrl(body);
            if(index<0||index>=extracted.scanPages().size())throw fail("扫描页序号无效",400);
            return imageUrl(LocalDocumentExtractor.pdfPagePng(body,extracted.scanPages().get(index)));
        }catch(IOException e){throw fail("图片暂时无法读取，请对照原件补充",400);}
    }
    public void discard(long file,long owner,String tenant){requireOwner(file,owner,tenant);files.discard(file,StoredObjectApi.AI_SOURCE,tenant);}
    static Material extract(String fileId,String filename,byte[] body){
        try {
            var kind=DocumentKinds.sniff(body);
            if(kind.media().equals("pdf")){try(var pdf=Loader.loadPDF(body)){if(pdf.getNumberOfPages()>20)throw fail("本次PDF最多20页，请拆分后继续上传",400);}}
            var extracted=LocalDocumentExtractor.extract(0,kind.media(),body,20);
            var sources=new ArrayList<Source>();
            for(var b:extracted.blocks())if(!b.text().isBlank())sources.add(new Source(b.label(),b.text()));
            if(sources.size()>1000||sources.stream().mapToInt(s->s.text().length()).sum()>120000)throw fail("资料超过1000段或120000字，请拆分后上传；未进行截断",400);
            var images=new ArrayList<String>();
            if(DocumentKinds.image(kind.media()))images.add(imageUrl(body));
            else for(int page:extracted.scanPages().stream().limit(6).toList())images.add(imageUrl(LocalDocumentExtractor.pdfPagePng(body,page)));
            var visuals=new ArrayList<Visual>();
            for(var image:extracted.visuals())visuals.add(new Visual(image.index(),image.location(),image.sha256(),image.kind(),image.afterBlock()));
            if(DocumentKinds.image(kind.media()))visuals.add(new Visual(0,"图片1",HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(body)),kind.media()));
            for(int page:extracted.scanPages())visuals.add(new Visual(visuals.size(),"第"+page+"页","","pdf-page",(int)extracted.blocks().stream().filter(b->b.label().matches("第[0-9]+页")&&Integer.parseInt(b.label().replaceAll("[^0-9]",""))<page).count()));
            String coverage="有界识别：已读取全部"+sources.size()+"段文字，共"+sources.stream().mapToInt(s->s.text().length()).sum()+"字；Word每段至多2000字分片，未截断；图片/扫描页共"+visuals.size()+"处，分批核对，未识别位置会明确列出，请对照原件";
            String name=(filename==null?"资料":filename).replace('\\','/');name=name.substring(name.lastIndexOf('/')+1).replaceAll("[\\p{Cntrl}]","");if(name.length()>120)name=name.substring(0,120);
            return new Material(fileId,name,extracted.mediaKind(),HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(body)),coverage,extracted.pageCount(),sources,images,visuals);
        }catch(IllegalArgumentException e){throw fail(e.getMessage(),400);}catch(IOException|java.security.NoSuchAlgorithmException e){throw fail("资料无法解析，请核对格式后重试",400);}
    }
    static String imageUrl(byte[] body)throws IOException{
        try(var input=ImageIO.createImageInputStream(new ByteArrayInputStream(body))){var readers=ImageIO.getImageReaders(input);if(!readers.hasNext())throw fail("图片无法读取，请转换为JPG或PNG",400);var reader=readers.next();try{reader.setInput(input);int width=reader.getWidth(0),height=reader.getHeight(0);if(width<1||height<1||(long)width*height>40_000_000L)throw fail("图片尺寸过大，请缩小后上传",400);int sample=Math.max(1,(int)Math.ceil(Math.max(width,height)/1600d));var params=reader.getDefaultReadParam();params.setSourceSubsampling(sample,sample,0,0);BufferedImage image=reader.read(0,params);var rgb=new BufferedImage(image.getWidth(),image.getHeight(),BufferedImage.TYPE_INT_RGB);var graphics=rgb.createGraphics();try{graphics.setColor(java.awt.Color.WHITE);graphics.fillRect(0,0,rgb.getWidth(),rgb.getHeight());graphics.drawImage(image,0,0,null);}finally{graphics.dispose();}return "data:image/jpeg;base64,"+Base64.getEncoder().encodeToString(boundedJpeg(rgb));}finally{reader.dispose();}}
    }

    /** Six JPEGs encode below 4MiB. A complex image is reduced explicitly rather than overflowing the gateway. */
    static byte[] boundedJpeg(BufferedImage image)throws IOException {
        for(int round=0;round<5;round++) {
            var writer=ImageIO.getImageWritersByFormatName("jpg").next();var out=new ByteArrayOutputStream();
            try(var target=ImageIO.createImageOutputStream(out)){
                writer.setOutput(target);var parameters=writer.getDefaultWriteParam();
                parameters.setCompressionMode(javax.imageio.ImageWriteParam.MODE_EXPLICIT);
                parameters.setCompressionQuality(Math.max(.35f,.85f-round*.12f));
                writer.write(null,new javax.imageio.IIOImage(image,null,null),parameters);
            }finally{writer.dispose();}
            if(out.size()<=512*1024)return out.toByteArray();
            int width=Math.max(160,image.getWidth()*3/4),height=Math.max(160,image.getHeight()*3/4);
            var next=new BufferedImage(width,height,BufferedImage.TYPE_INT_RGB);var graphics=next.createGraphics();
            try{graphics.drawImage(image,0,0,width,height,null);}finally{graphics.dispose();}image=next;
        }
        throw fail("图片编码后仍过大，请缩小或分批补充",400);
    }
}

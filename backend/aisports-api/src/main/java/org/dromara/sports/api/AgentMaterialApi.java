package org.dromara.sports.api;

import java.util.List;

/** Private source material for a visible agent conversation. Never returns a public object URL. */
public interface AgentMaterialApi {
    record Upload(String name, byte[] body) { }
    record Source(String location, String text) { }
    record Visual(int index, String location, String sha256, String kind, int afterBlock) {
        public Visual(int index,String location,String sha256,String kind){this(index,location,sha256,kind,0);}
    }
    record Material(String fileId, String name, String kind, String sha256, String coverage,
                    Integer pageCount, List<Source> sources, List<String> images, List<Visual> visuals) {
        public Material(String fileId, String name, String kind, String sha256, String coverage, Integer pageCount, List<Source> sources, List<String> images) { this(fileId,name,kind,sha256,coverage,pageCount,sources,images,List.of()); }
    }
    List<Material> retain(long owner, String tenant, List<Upload> uploads);
    Material read(long fileId, long owner, String tenant, String name);
    String image(long fileId, long owner, String tenant, int index);
    void discard(long fileId, long owner, String tenant);
}

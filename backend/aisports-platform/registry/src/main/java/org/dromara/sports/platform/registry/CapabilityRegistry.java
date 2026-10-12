package org.dromara.sports.platform.registry;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.platform.core.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import java.util.*;

/** Provider discovery is independent of table modules. An implemented provider still needs an open release. */
@Component
public class CapabilityRegistry {
    private final Map<String,CapabilityProvider> providers = new LinkedHashMap<>();
    private final Map<String,CapabilityDefinition> definitions = new LinkedHashMap<>();
    private final List<TableModule> modules;
    private final JdbcTemplate jdbc;
    private final ObjectMapper json;
    public CapabilityRegistry(List<CapabilityProvider> providers, List<TableModule> modules, JdbcTemplate jdbc, ObjectMapper json) {
        this.modules=modules; this.jdbc=jdbc; this.json=json;
        for (var provider:providers) for(var definition:provider.capabilities()) {
            if (this.definitions.putIfAbsent(definition.code(),definition)!=null) throw new IllegalStateException("Duplicate capability");
            this.providers.put(definition.code(),provider);
        }
    }
    public Collection<CapabilityDefinition> definitions() { return Collections.unmodifiableCollection(definitions.values()); }
    public CapabilityDefinition definition(String code) {
        var value=definitions.get(code); if(value==null) throw new ServiceException("该能力尚未提供",404); return value;
    }
    public CapabilityProvider provider(String code) { definition(code); return providers.get(code); }
    public boolean open(String code,String channel) {
        Integer count=jdbc.queryForObject("SELECT count(*) FROM asp_capability_activation a JOIN asp_capability_version v ON v.id=a.capability_version_id AND v.code=a.code WHERE a.code=? AND a.channel=? AND a.enabled AND v.status='published' AND v.source_hash=?",Integer.class,code,channel,fingerprint(definition(code)));
        return count!=null && count>0;
    }
    public String fingerprint(CapabilityDefinition d){var n=(com.fasterxml.jackson.databind.node.ObjectNode)json.valueToTree(d);for(String key:List.of("reads","writes","actorTypes")){var values=new TreeSet<String>();n.path(key).forEach(v->values.add(v.asText()));n.set(key,json.valueToTree(values));}var schema=n.path("inputSchema");if(schema.isObject()&&schema.has("required")){var required=new TreeSet<String>();schema.path("required").forEach(v->required.add(v.asText()));((com.fasterxml.jackson.databind.node.ObjectNode)schema).set("required",json.valueToTree(required));}return JsonFingerprint.hash(n);}
    public List<JsonNode> modules() {
        return modules.stream().map(m->{try{return json.readTree(m.metadataJson());}catch(Exception e){throw new IllegalStateException("Invalid generated metadata",e);}}).toList();
    }
}

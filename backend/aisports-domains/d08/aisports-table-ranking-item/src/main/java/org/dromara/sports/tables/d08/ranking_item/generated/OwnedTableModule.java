// GENERATED. Handwritten business actions belong outside generated/.
package org.dromara.sports.tables.d08.ranking_item;
import org.dromara.sports.platform.core.TableModule;
import org.springframework.stereotype.Component;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
@Component("table_asp_ranking_item")
public class OwnedTableModule implements TableModule {
    public String tableName() { return "asp_ranking_item"; }
    public String domain() { return "D08"; }
    public String metadataJson() {
        try (var stream = getClass().getResourceAsStream("/aisports/tables/asp_ranking_item.json")) {
            if (stream == null) throw new IllegalStateException("Missing table metadata");
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) { throw new IllegalStateException("Unreadable table metadata", e); }
    }
}

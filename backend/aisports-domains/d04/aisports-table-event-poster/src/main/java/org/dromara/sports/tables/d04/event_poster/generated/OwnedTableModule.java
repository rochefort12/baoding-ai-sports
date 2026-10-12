// GENERATED. Handwritten business actions belong outside generated/.
package org.dromara.sports.tables.d04.event_poster;
import org.dromara.sports.platform.core.TableModule;
import org.springframework.stereotype.Component;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
@Component("table_asp_event_poster")
public class OwnedTableModule implements TableModule {
    public String tableName() { return "asp_event_poster"; }
    public String domain() { return "D04"; }
    public String metadataJson() {
        try (var stream = getClass().getResourceAsStream("/aisports/tables/asp_event_poster.json")) {
            if (stream == null) throw new IllegalStateException("Missing table metadata");
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) { throw new IllegalStateException("Unreadable table metadata", e); }
    }
}

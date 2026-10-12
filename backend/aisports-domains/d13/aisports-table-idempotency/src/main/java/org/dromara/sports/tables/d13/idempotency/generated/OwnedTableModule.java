// GENERATED. Handwritten business actions belong outside generated/.
package org.dromara.sports.tables.d13.idempotency;
import org.dromara.sports.platform.core.TableModule;
import org.springframework.stereotype.Component;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
@Component("table_asp_idempotency")
public class OwnedTableModule implements TableModule {
    public String tableName() { return "asp_idempotency"; }
    public String domain() { return "D13"; }
    public String metadataJson() {
        try (var stream = getClass().getResourceAsStream("/aisports/tables/asp_idempotency.json")) {
            if (stream == null) throw new IllegalStateException("Missing table metadata");
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) { throw new IllegalStateException("Unreadable table metadata", e); }
    }
}

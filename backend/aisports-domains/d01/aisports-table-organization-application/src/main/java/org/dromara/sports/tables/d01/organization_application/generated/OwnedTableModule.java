// GENERATED. Handwritten business actions belong outside generated/.
package org.dromara.sports.tables.d01.organization_application;
import org.dromara.sports.platform.core.TableModule;
import org.springframework.stereotype.Component;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
@Component("table_asp_organization_application")
public class OwnedTableModule implements TableModule {
    public String tableName() { return "asp_organization_application"; }
    public String domain() { return "D01"; }
    public String metadataJson() {
        try (var stream = getClass().getResourceAsStream("/aisports/tables/asp_organization_application.json")) {
            if (stream == null) throw new IllegalStateException("Missing table metadata");
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) { throw new IllegalStateException("Unreadable table metadata", e); }
    }
}

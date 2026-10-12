// GENERATED. Handwritten business actions belong outside generated/.
package org.dromara.sports.tables.d09.lineup_member;
import org.dromara.sports.platform.core.TableModule;
import org.springframework.stereotype.Component;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
@Component("table_asp_lineup_member")
public class OwnedTableModule implements TableModule {
    public String tableName() { return "asp_lineup_member"; }
    public String domain() { return "D09"; }
    public String metadataJson() {
        try (var stream = getClass().getResourceAsStream("/aisports/tables/asp_lineup_member.json")) {
            if (stream == null) throw new IllegalStateException("Missing table metadata");
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) { throw new IllegalStateException("Unreadable table metadata", e); }
    }
}

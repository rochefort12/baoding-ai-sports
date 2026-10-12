package org.dromara.sports.platform.core;

/** One descriptor per owned table. Metadata is generated; opening a capability requires a separate release. */
public interface TableModule {
    String tableName();
    String domain();
    String metadataJson();
}

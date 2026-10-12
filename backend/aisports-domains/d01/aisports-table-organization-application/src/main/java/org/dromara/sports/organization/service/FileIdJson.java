package org.dromara.sports.organization.service;

import org.dromara.common.json.utils.JsonUtils;

import java.util.ArrayList;
import java.util.List;

final class FileIdJson {

    private FileIdJson() {
    }

    static String write(List<Long> ids) {
        return JsonUtils.toJsonString(new Document(ids == null ? List.of() : ids));
    }

    static List<Long> read(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        Document document = JsonUtils.parseObject(json, Document.class);
        if (document == null || document.fileIds() == null) {
            return List.of();
        }
        return new ArrayList<>(document.fileIds());
    }

    private record Document(List<Long> fileIds) {
    }
}

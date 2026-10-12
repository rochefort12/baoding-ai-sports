package org.dromara.sports.organization.service;

import org.dromara.common.json.utils.JsonUtils;
import org.dromara.sports.organization.OrganizationSlice;

import java.util.List;

final class GrantJson {

    private GrantJson() {
    }

    static String organize() {
        return JsonUtils.toJsonString(new Actions(List.of(OrganizationSlice.ACTION_ORGANIZE, OrganizationSlice.ACTION_PAYMENT)));
    }

    static boolean contains(String json, String action) {
        if (json == null || json.isBlank() || action == null) {
            return false;
        }
        try {
            Actions actions = JsonUtils.parseObject(json, Actions.class);
            return actions != null && actions.actions() != null && actions.actions().contains(action);
        } catch (RuntimeException exception) {
            return false;
        }
    }

    private record Actions(List<String> actions) {
    }
}

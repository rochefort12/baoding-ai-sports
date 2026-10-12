package org.dromara.sports.api;

import java.util.List;

/**
 * 注销前要同时看报名、队长和未结资金。身份模块不直接查这些表。
 */
public interface AccountClosureApi {

    List<String> blocks(Long accountId, Long personId);
}

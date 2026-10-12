package org.dromara.sports.registration.service;

import org.dromara.common.core.exception.ServiceException;
import java.util.List;
import java.util.HashSet;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/** Initial roster is a set of actual accounts; order changes cannot create a different booking request. */
final class TeamRosterSelection {
    private TeamRosterSelection() { }

    static List<Long> checked(List<Long> accounts, int min, int max) {
        if (accounts == null || accounts.stream().anyMatch(id -> id == null || id <= 0)) {
            throw new ServiceException("请选择有效队员");
        }
        if (new HashSet<>(accounts).size() != accounts.size()) throw new ServiceException("同一队员不能重复选择");
        if (accounts.size() < min || accounts.size() > max) throw new ServiceException("本项目需要 " + min + "—" + max + " 位参赛成员");
        return accounts.stream().sorted().toList();
    }

    static String digest(Long unit, Long team, List<Long> accounts) {
        try {
            String value = unit + ":" + team + ":" + accounts.stream().sorted().toList();
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
    }
}

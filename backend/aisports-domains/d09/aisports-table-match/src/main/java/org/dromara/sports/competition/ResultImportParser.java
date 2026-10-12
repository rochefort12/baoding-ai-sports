package org.dromara.sports.competition;

import org.dromara.common.core.exception.ServiceException;
import java.util.*;

/** Parses a whole batch before any write. Scores are A:B; one side suffices to derive the other outcome. */
public final class ResultImportParser {
    private ResultImportParser() { }
    public record Row(String code, String outcomeA, String outcomeB, String summary, String games) { }
    private record Side(String slot, String outcome, String summary, String games) { }
    public static List<Row> parse(String body) {
        if (body == null || body.length() > 100_000) throw new ServiceException("导入内容为空或过长");
        Map<String, Map<String, Side>> groups = new LinkedHashMap<>();
        int lineNumber = 0;
        for (String raw : body.split("\\R")) {
            lineNumber++;
            String line = raw.trim().replaceFirst("\\\\\\s*$", "").trim();
            if (line.isEmpty() || line.startsWith("matchCode,")) continue;
            String[] parts = line.split(",", -1);
            if (parts.length != 5) throw error(lineNumber, "需要场次编号、A/B、胜负、总比分、分局五列");
            String code = parts[0].trim(), slot = parts[1].trim().toUpperCase(Locale.ROOT), outcome = parts[2].trim().toLowerCase(Locale.ROOT);
            if (code.isEmpty() || code.length() > 100) throw error(lineNumber, "请填写有效场次编号");
            if (!Set.of("A", "B").contains(slot)) throw error(lineNumber, "位置只能是 A 或 B");
            if (!Set.of("win", "loss", "draw").contains(outcome)) throw error(lineNumber, "胜负只能是 win、loss 或 draw");
            Map<String, Side> sides = groups.computeIfAbsent(code, ignored -> new LinkedHashMap<>());
            if (sides.putIfAbsent(slot, new Side(slot, outcome, parts[3].trim(), parts[4].trim())) != null)
                throw error(lineNumber, "场次 " + code + " 的 " + slot + " 侧重复，请保留一行");
            if (groups.size() > 500) throw error(lineNumber, "一次最多导入 500 场");
        }
        if (groups.isEmpty()) throw new ServiceException("没有可导入的比赛结果");
        List<Row> rows = new ArrayList<>();
        for (var group : groups.entrySet()) {
            Side a = group.getValue().get("A"), b = group.getValue().get("B"), source = a == null ? b : a;
            String outcomeA = a == null ? opposite(b.outcome()) : a.outcome(), outcomeB = b == null ? opposite(a.outcome()) : b.outcome();
            CompetitionRules.requireComplementary(outcomeA, outcomeB);
            // Accept legacy B rows written from B's perspective when an explicit A row establishes orientation.
            if (a != null && b != null && (!sameOrReverse(a.summary(), b.summary()) || !sameOrReverse(a.games(), b.games())))
                throw new ServiceException("场次 " + group.getKey() + " 的双方比分不一致，请核对");
            rows.add(new Row(group.getKey(), outcomeA, outcomeB, source.summary(), source.games()));
        }
        return rows;
    }
    private static boolean sameOrReverse(String a, String b) {
        if (b.isEmpty() || a.equals(b)) return true;
        String[] scores = a.split("\\|", -1);
        List<String> reversed = new ArrayList<>();
        for (String score : scores) {
            String[] pair = score.split(":", -1);
            if (pair.length != 2) return false;
            reversed.add(pair[1] + ":" + pair[0]);
        }
        return String.join("|", reversed).equals(b);
    }
    private static String opposite(String value) { return "win".equals(value) ? "loss" : "loss".equals(value) ? "win" : "draw"; }
    private static ServiceException error(int line, String message) { return new ServiceException("第 " + line + " 行：" + message); }
}

package org.dromara.sports.platform.core;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.*;
import java.util.regex.Pattern;

/** Event placing is one continuing claim per registration; special awards keep their own lineage.
 * Pure rules shared by table actions. No database/entity dependency and no automatic ranking. */
public final class EventAwardLineage {
    private EventAwardLineage() {}
    private static final Pattern PLACE = Pattern.compile("^(第[一二三四五六七八九十百零0-9]+名(?:[-－].*)?|冠军|亚军|季军)$");
    public record Claim(long id, long registration, long person, String awardKey, String title, JsonNode source, String status) {}
    public static String kind(String title, JsonNode source) {
        String explicit = source.path("awardKind").asText();
        return Set.of("placing", "special").contains(explicit) ? explicit
            : PLACE.matcher(title == null ? "" : title.trim()).matches() ? "placing" : "special";
    }
    public static String key(Claim claim, Collection<Claim> all) {
        if (kind(claim, all).equals("placing")) return "placing:" + claim.registration();
        String root = claim.source().path("awardRootKey").asText();
        if (!root.isBlank()) return "special:" + claim.registration() + ":" + root;
        Claim cursor = ancestor(claim, all);
        return "special:" + claim.registration() + ":" + cursor.source().path("awardRootKey").asText(cursor.awardKey());
    }
    public static String kind(Claim claim, Collection<Claim> all) {
        if (Set.of("placing", "special").contains(claim.source().path("awardKind").asText()))
            return kind(claim.title(), claim.source());
        Claim original = ancestor(claim, all);
        return kind(original.title(), original.source());
    }
    private static Claim ancestor(Claim claim, Collection<Claim> all) {
        Claim cursor = claim;
        Set<Long> visited = new HashSet<>();
        while (visited.add(cursor.id())) {
            long previous = cursor.source().path("previousHonorId").asLong(0);
            final Claim next = cursor;
            Claim parent = all.stream().filter(c -> c.id() == previous && c.registration() == next.registration()
                && c.person() == next.person()).findFirst().orElse(null);
            if (parent == null) break;
            cursor = parent;
        }
        return cursor;
    }
    /** A newer suspended/revoked claim prevents an earlier verified version from resurfacing. */
    public static List<Claim> latest(Collection<Claim> claims) {
        Map<String, Claim> latest = new LinkedHashMap<>();
        for (Claim claim : claims) {
            String key = key(claim, claims) + ":person:" + claim.person();
            latest.merge(key, claim, (a, b) -> a.id() > b.id() ? a : b);
        }
        return new ArrayList<>(latest.values());
    }
    public static String fingerprint(JsonNode results) {
        List<String> parts = new ArrayList<>();
        for (JsonNode r : results) parts.add(r.path("matchId").asText() + ":" + r.path("resultId").asText() + ":" + r.path("revision").asText() + ":" + r.path("status").asText());
        Collections.sort(parts);
        try { return HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(String.join("|", parts).getBytes(java.nio.charset.StandardCharsets.UTF_8))); }
        catch (java.security.NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }
    public static boolean dependsOn(JsonNode source, long match, long unit, boolean participant) {
        if (source.path("basisScope").asText().equals("unit")) return source.path("unitId").asLong() == unit;
        if (source.has("basisResults")) {
            for (JsonNode result : source.path("basisResults")) if (result.path("matchId").asLong() == match) return true;
            return false;
        }
        // Legacy awards have no structured match evidence. Keep review conservative inside their project.
        return participant && source.path("unitId").asLong() == unit;
    }
}

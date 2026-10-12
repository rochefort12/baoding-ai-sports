package org.dromara.sports.platform.core;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;
@Tag("local") class JsonFingerprintTest {
 private final ObjectMapper json=new ObjectMapper();
 @Test void memberOrAmountChangeRequiresNewConfirmation()throws Exception {var first=json.readTree("{\"amount\":\"100.00\",\"members\":[\"1\",\"2\"]}");assertEquals(JsonFingerprint.hash(first),JsonFingerprint.hash(json.readTree("{\"members\":[\"1\",\"2\"],\"amount\":\"100.00\"}")));assertNotEquals(JsonFingerprint.hash(first),JsonFingerprint.hash(json.readTree("{\"amount\":\"101.00\",\"members\":[\"1\",\"2\"]}")));assertNotEquals(JsonFingerprint.hash(first),JsonFingerprint.hash(json.readTree("{\"amount\":\"100.00\",\"members\":[\"2\",\"1\"]}")));}
 @Test void quotedPropertyNamesCannotForgeObjectBoundaries()throws Exception {assertNotEquals(JsonFingerprint.hash(json.readTree("{\"a\\\":1,\\\"b\":2}")),JsonFingerprint.hash(json.readTree("{\"a\":1,\"b\":2}")));}
}

package org.dromara.sports.platform.core;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.TextNode;
import java.util.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
/** JSON object order cannot change a confirmation; array order and every value remain significant. */
public final class JsonFingerprint {
 private JsonFingerprint(){}
 public static String hash(JsonNode input){try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(canonical(input).getBytes(StandardCharsets.UTF_8)));}catch(Exception e){throw new IllegalStateException(e);}}
 private static String canonical(JsonNode n){if(n==null)return "null";if(n.isObject()){var keys=new TreeSet<String>();n.fieldNames().forEachRemaining(keys::add);var parts=new ArrayList<String>();for(var k:keys)parts.add(TextNode.valueOf(k).toString()+":"+canonical(n.get(k)));return "{"+String.join(",",parts)+"}";}if(n.isArray()){var parts=new ArrayList<String>();n.forEach(v->parts.add(canonical(v)));return "["+String.join(",",parts)+"]";}return n.toString();}
}

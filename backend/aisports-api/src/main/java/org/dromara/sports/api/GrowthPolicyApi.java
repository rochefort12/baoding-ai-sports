package org.dromara.sports.api;
import java.util.*;
/** Immutable published rules. An event uses the version published before its creation. */
public interface GrowthPolicyApi {
    Rule current(Long sport);
    Rule forEvent(Long sport,Long event);
    record Rule(String version,int checkinPoints,int finishPoints,int teamFinishPoints,List<Long> thresholds,List<String> rankNames,Map<String,Integer> personalTitles,Map<String,Integer> teamTitles) {
        public int rank(long points){int i=0;while(i+1<thresholds.size()&&points>=thresholds.get(i+1))i++;return i;}
    }
}

package org.dromara.sports.api;
import java.util.Optional;
public interface CompetitionTypeApi { Optional<Long> supported(Long sportId,String entryType,Integer min,Integer max); }

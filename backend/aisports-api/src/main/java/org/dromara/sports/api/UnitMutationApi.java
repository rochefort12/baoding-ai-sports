package org.dromara.sports.api;
import java.math.BigDecimal;
/** Complete unit + capacity + initial fee transaction; no table implementation crosses this boundary. */
public interface UnitMutationApi {
    Long create(Long event,String name,String entryType,int min,int max,int limit,String requestKey,boolean charged,BigDecimal amount,String mode,String instruction,Long qr);
}

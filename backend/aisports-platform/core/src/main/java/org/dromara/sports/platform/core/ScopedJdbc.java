package org.dromara.sports.platform.core;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import java.util.List;
import java.util.Map;

/** Parameterized SQL only. Modules must explicitly include actor/organization filters in their statements. */
@Component
@RequiredArgsConstructor
public class ScopedJdbc {
    private final JdbcTemplate jdbc;
    public List<Map<String,Object>> list(String sql, Object... args) { SqlScope.check(sql,false,false); return jdbc.queryForList(sql,args); }
    public Map<String,Object> one(String sql, Object... args) { var rows=list(sql,args); return rows.isEmpty()?null:rows.get(0); }
    public long count(String sql, Object... args) { SqlScope.check(sql,false,false); Long n=jdbc.queryForObject(sql,Long.class,args); return n==null?0:n; }
    public int update(String sql, Object... args) { SqlScope.check(sql,true,true); return jdbc.update(sql,args); }
    public void lock(String key) { jdbc.queryForObject("SELECT pg_advisory_xact_lock(hashtextextended(?, 0))",Object.class,key); }
}

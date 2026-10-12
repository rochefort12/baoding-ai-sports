package org.dromara.sports.platform.core;
import org.junit.jupiter.api.*;
import java.util.Set;
import static org.junit.jupiter.api.Assertions.*;
@Tag("local") class SqlScopeTest {
 @AfterEach void clear(){ActionContext.clear();}
 @Test void missingBoundaryCannotWrite(){assertThrows(RuntimeException.class,()->SqlScope.check("UPDATE asp_registration SET status='approved'",true,true));}
 @Test void readableTableIsNotAutomaticallyWritable(){ActionContext.bind(new ActionContext("fixture","platform",1L,null,"ui","fixture","hash",null,Set.of("asp_account"),Set.of("asp_team_room")));assertDoesNotThrow(()->SqlScope.check("SELECT id FROM asp_account",false,false));assertThrows(RuntimeException.class,()->SqlScope.check("UPDATE asp_account SET status='closed'",true,true));assertThrows(RuntimeException.class,()->SqlScope.check("INSERT INTO asp_payment(id) VALUES(1)",true,true));assertDoesNotThrow(()->SqlScope.check("UPDATE asp_team_room SET version=version+1",true,true));}
 @Test void joinScopeCannotBeExpandedByDeclaredWrite(){ActionContext.bind(new ActionContext("fixture","platform",1L,null,"ui","fixture","hash",null,Set.of("asp_account"),Set.of("asp_team_room")));assertThrows(RuntimeException.class,()->SqlScope.check("SELECT * FROM asp_account JOIN asp_person ON true",false,false));}
}

package org.dromara.sports.event.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.dromara.common.core.exception.ServiceException;
import org.dromara.sports.event.ai.SportsEventRunAiTaskService.ConfirmDraft;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import java.util.List;
import java.time.OffsetDateTime;
import static org.junit.jupiter.api.Assertions.*;

@Tag("local")
class AiDeclarationProposalTest {
    private final ObjectMapper json=new ObjectMapper();
    private final String source="自主评估运动适宜性，遵守裁判安排。";
    private ConfirmDraft draft(String text,Boolean ack,Integer version){return new ConfirmDraft("fixture","赛",null,null,null,null,null,null,null,"manual",null,List.of(),null,null,null,text,ack,version);}
    private String proposal(String status){return "{\"event\":{\"declarationText\":{\"value\":\""+source+"\",\"status\":\""+status+"\",\"sources\":[{\"kind\":\"document\",\"quote\":\""+source+"\"}]}}}";}
    @Test void humanSwitchIsExplicitAndBoundToTheSameSourceVersion(){
        assertDoesNotThrow(()->AiDeclarationProposal.requireMatch(json,proposal("filled"),draft(source,true,7),draft(source,false,null),7));
        assertDoesNotThrow(()->AiDeclarationProposal.requireMatch(json,proposal("filled"),draft(source,false,7),draft(source,false,null),7));
        assertThrows(ServiceException.class,()->AiDeclarationProposal.requireMatch(json,proposal("filled"),draft(source,null,7),draft(source,false,null),7));
        assertThrows(ServiceException.class,()->AiDeclarationProposal.requireMatch(json,proposal("filled"),draft(source,true,6),draft(source,false,null),7));
    }
    @Test void conflictAndEditedLegalTextCannotBeConfirmed(){
        assertThrows(ServiceException.class,()->AiDeclarationProposal.requireMatch(json,proposal("conflict"),draft(source,true,7),draft(source,false,null),7));
        assertThrows(ServiceException.class,()->AiDeclarationProposal.requireMatch(json,proposal("filled"),draft(source+"一切免责",true,7),draft(source,false,null),7));
        var ready=AiDeclarationProposal.readiness(json,proposal("conflict"),new AiDraftReadiness.Ready(true,List.of(),"可保存",OffsetDateTime.now().toString()));
        assertFalse(ready.canSaveDraft());assertEquals("DECLARATION_CONFLICT",ready.blockingIssues().get(0).code());
    }
    @Test void noSourceMeansNoInventedStatementOrAcknowledgement(){
        assertDoesNotThrow(()->AiDeclarationProposal.requireMatch(json,"{}",draft(null,false,null),draft(null,false,null),7));
        assertThrows(ServiceException.class,()->AiDeclarationProposal.requireMatch(json,"{}",draft(null,true,7),draft(null,false,null),7));
        assertThrows(ServiceException.class,()->AiDeclarationProposal.requireMatch(json,"{}",draft(source,true,7),draft(null,false,null),7));
    }
}

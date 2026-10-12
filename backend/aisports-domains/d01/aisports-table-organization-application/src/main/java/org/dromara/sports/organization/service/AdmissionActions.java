package org.dromara.sports.organization.service;
import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import org.dromara.sports.platform.core.*;
import org.springframework.stereotype.Service;
import java.util.*;
import static org.dromara.sports.platform.core.BusinessSupport.*;
@Service @RequiredArgsConstructor
public class AdmissionActions implements CapabilityProvider {
 private final OrganizationApplicationService applications;private final ScopedJdbc db;private final ObjectMapper json;
 private static final Set<String> READS=Set.of("asp_organization_application","asp_organization_application_version","asp_organization","asp_file","asp_account_tenant_principal","asp_staff_grant","asp_account");
 public List<CapabilityDefinition> capabilities(){var list=new ArrayList<CapabilityDefinition>();list.add(capability(json,"organization.mine","读取本人主办方入驻资料与补正进度","asp_organization_application",true,false,Set.of("platform"),"",READS,Set.of()));for(String code:List.of("organization.save","organization.submit")){var d=capability(json,code,code.endsWith("submit")?"本人核对后提交主办方入驻申请":"保存本人主办方入驻草稿","asp_organization_application",true,code.endsWith("submit"),Set.of("platform"),"",READS,Set.of("asp_organization_application","asp_organization_application_version"),"draftJson","expectedVersion?");((ObjectNode)d.inputSchema().path("properties").path("draftJson")).put("description","JSON对象文本：name主办方名称、contactName联系人、contactMethod联系方式、statement申请说明、fileIds本人已上传材料编号数组；不猜测附件编号。");list.add(d);}return list;}
 public JsonNode preview(String code,JsonNode in){var n=json.createObjectNode();n.set("application",json.valueToTree(applications.current()));var row=db.one("SELECT version FROM asp_organization_application WHERE applicant_account_id=?",account());n.put("version",row==null?0:number(row.get("version")));return n;}
 public JsonNode execute(String code,JsonNode in){if(code.equals("organization.mine"))return preview(code,in);long actor=account();db.lock("admission:"+actor);var old=db.one("SELECT version FROM asp_organization_application WHERE applicant_account_id=? FOR UPDATE",actor);if(old!=null&&(!in.has("expectedVersion")||number(old.get("version"))!=in.path("expectedVersion").asLong(-1)))throw fail("申请资料已变化，请重新读取后补充",409);OrganizationApplicationService.Draft draft;try{var parsed=json.readTree(text(in,"draftJson",10000));if(!parsed.isObject())throw new IllegalArgumentException();draft=json.treeToValue(parsed,OrganizationApplicationService.Draft.class);}catch(Exception e){throw fail("请补齐主办方名称、联系人、联系方式和申请说明",400);}var result=code.endsWith("submit")?applications.submit(draft):applications.save(draft);return reference(json,"applicationId",result.applicationId(),result.status());}
}

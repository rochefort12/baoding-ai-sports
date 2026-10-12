package org.dromara.sports.registration.service;
import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.RegistrationResponsibilityApi;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.dromara.common.core.exception.ServiceException;
import org.springframework.stereotype.Service;
@Service @RequiredArgsConstructor
public class RegistrationResponsibilityApiImpl implements RegistrationResponsibilityApi {
 private final ScopedJdbc db;
 public void requireTeamChange(Long team,Long person,boolean disband){String where=disband?"":" AND r.manager_account_id IN(SELECT id FROM asp_account WHERE person_id=?)";Object[] args=disband?new Object[]{team}:new Object[]{team,person};if(db.count("SELECT count(*) FROM asp_registration r JOIN asp_competition_unit u ON u.id=r.unit_id JOIN asp_event e ON e.id=u.event_id WHERE r.team_id=? AND e.closure_status<>'closed' AND (r.status IN('submitted','approved') OR r.roster_revision>0 OR EXISTS(SELECT 1 FROM asp_fee_obligation f WHERE f.registration_id=r.id AND f.status='open'))"+where,args)>0)throw new ServiceException(disband?"小队还有本场报名或资金责任，请先处理本场收尾再解散":"你仍负责该队未收尾的报名，请先在报名详情完成责任交接",409);}
}

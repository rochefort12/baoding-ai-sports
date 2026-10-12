package org.dromara.sports.registration.service;

import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.PlatformAccountApi;
import org.dromara.sports.api.RoomRegistrationApi;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.springframework.stereotype.Service;
import java.util.*;
import static org.dromara.sports.platform.core.BusinessSupport.*;

/** Creates the registration draft in the room action's transaction. Joining a room never signs a declaration. */
@Service @RequiredArgsConstructor
public class RoomRegistrationApiImpl implements RoomRegistrationApi {
    private final ScopedJdbc db;
    private final RegistrationService registrations;
    private final PlatformAccountApi accounts;
    @Override public Long prepare(Long roomId,String requestKey){
        long account=accounts.currentAccountId().orElseThrow(()->fail("请使用本人参赛账号登录",403));
        var room=db.one("SELECT * FROM asp_team_room WHERE id=? AND host_account_id=?",roomId,account);
        if(room==null)throw fail("请由房主准备报名",403);
        long unit=number(room.get("unit_id"));
        var roster=db.list("SELECT account_id,person_id FROM asp_team_room_member WHERE room_id=? AND status='active' ORDER BY joined_at",roomId);
        if(room.get("registration_id")!=null)return number(room.get("registration_id"));
        Long team=room.get("team_id")==null?null:number(room.get("team_id"));
        var draft=registrations.createDraft(unit,requestKey,team);long registration=draft.id();
        if(!Set.of("draft","rejected").contains(draft.status()))throw fail("该项目已有已提交报名，请返回报名详情",409);
        var saved=db.one("SELECT manager_account_id,tenant_id FROM asp_registration WHERE id=?",registration);
        if(saved==null||number(saved.get("manager_account_id"))!=account)throw fail("现有报名尚未交接给你",403);
        String tenant=saved.get("tenant_id").toString();
        var roomAccounts=roster.stream().map(m->number(m.get("account_id"))).toList();
        for(var member:db.list("SELECT account_id FROM asp_registration_member WHERE registration_id=? AND status<>'declined'",registration))if(!roomAccounts.contains(number(member.get("account_id"))))throw fail("已有报名名单与房间不同，请先在报名详情核对名单",409);
        for(var member:roster){long target=number(member.get("account_id"));if(db.count("SELECT count(*) FROM asp_registration_member WHERE registration_id=? AND account_id=? AND status<>'declined'",registration,target)>0)continue;
            if(target==account&&team!=null){registrations.addTeammate(registration,target);continue;}
            if(db.count("SELECT count(*) FROM asp_registration_member WHERE unit_id=? AND account_id=? AND occupying",unit,target)>0)throw fail("队员已报名这个项目，请先处理报名冲突",409);
            String token=UUID.randomUUID().toString().replace("-","");
            db.update("INSERT INTO asp_registration_member(id,tenant_id,registration_id,unit_id,account_id,status,self_member,invite_token,occupying) VALUES (?,?,?,?,?,'pending_confirmation',false,?,false)",nextId(),tenant,registration,unit,target,token);
        }
        for(var member:roster){long target=number(member.get("account_id"));if(target==account)continue;String key="room-entry:"+registration+":"+target;db.update("INSERT INTO asp_notification(id,tenant_id,recipient_account_id,business_type,business_id,business_revision,purpose,content,dedupe_key) VALUES (?,?,?,'registration',?,0,'member-confirmation',?::jsonb,?) ON CONFLICT (tenant_id,recipient_account_id,dedupe_key) DO NOTHING",nextId(),tenant,target,registration,"{\"title\":\"搭档已准备报名，等你确认\",\"body\":\"请本人核对参赛资料、声明和费用；准备状态不会代替你的报名确认。\",\"target\":\"/portal/registration?eventId="+db.one("SELECT event_id FROM asp_competition_unit WHERE id=?",unit).get("event_id")+"\"}",key);}
        return registration;
    }
}

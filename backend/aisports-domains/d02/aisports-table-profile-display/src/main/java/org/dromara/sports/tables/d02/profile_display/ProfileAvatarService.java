package org.dromara.sports.tables.d02.profile_display;

import lombok.RequiredArgsConstructor;
import org.dromara.sports.api.StoredObjectApi;
import org.dromara.sports.platform.core.ScopedJdbc;
import org.dromara.sports.platform.core.SportsAction;
import org.springframework.stereotype.Service;

import static org.dromara.sports.platform.core.BusinessSupport.*;

/** 头像与证件材料分开。共享队友只获必要展示，匿名读取仍服从名片公开开关。 */
@Service
@RequiredArgsConstructor
public class ProfileAvatarService {
    private final ScopedJdbc db;
    private final StoredObjectApi objects;

    @SportsAction(value="profile.avatar.upload", title="修改本人运动头像",
        reads={"asp_account","asp_profile_display","asp_file"}, writes={"asp_profile_display","asp_file"})
    public AvatarReceipt upload(byte[] body, long expectedVersion) {
        long actor = account();
        if (body == null || body.length == 0 || body.length > 5 * 1024 * 1024) throw fail("请选择不超过5MB的头像图片",400);
        if (db.count("SELECT count(*) FROM asp_account WHERE id=? AND status='active'",actor) != 1) throw fail("当前账号不可修改头像",403);
        db.lock("display:"+actor);
        var current = db.one("SELECT version FROM asp_profile_display WHERE account_id=?",actor);
        if ((current == null ? 0 : number(current.get("version"))) != expectedVersion) throw fail("运动名片已变化，请重新读取后上传",409);
        long file = objects.keepProfileAvatar(actor,body);
        db.update("INSERT INTO asp_profile_display(id,account_id,nickname,avatar_style,avatar_file_id,tagline,public_visible,sport_preferences) VALUES (?,?,'新来的球友','mint',?,'',false,'[]'::jsonb) ON CONFLICT(account_id) DO UPDATE SET avatar_file_id=excluded.avatar_file_id,version=asp_profile_display.version+1,update_time=CURRENT_TIMESTAMP",nextId(),actor,file);
        var saved = db.one("SELECT version FROM asp_profile_display WHERE account_id=?",actor);
        return new AvatarReceipt(Long.toString(file),number(saved.get("version")));
    }

    public StoredObjectApi.ImageBody image(long target, boolean anonymous) {
        var row = db.one("SELECT d.avatar_file_id,d.public_visible FROM asp_profile_display d JOIN asp_account a ON a.id=d.account_id WHERE d.account_id=? AND a.status='active'",target);
        if (row == null || row.get("avatar_file_id") == null) throw fail("尚未上传运动头像",404);
        if (!Boolean.TRUE.equals(row.get("public_visible"))) {
            if (anonymous) throw fail("运动名片未公开",404);
            long actor = account();
            if (actor != target && !necessaryTeammate(actor,target)) throw fail("头像仅向本人和当前队友展示",403);
        } else if (!anonymous) {
            // 已登录读取依旧只接受平台参赛身份，不能借工作账号扩大共享查询。
            account();
        }
        return objects.readProfileAvatar(number(row.get("avatar_file_id")),target);
    }

    private boolean necessaryTeammate(long actor,long target) {
        return db.count("SELECT count(*) FROM asp_team_room_member mine JOIN asp_team_room_member peer ON peer.room_id=mine.room_id WHERE mine.account_id=? AND peer.account_id=? AND mine.status='active' AND peer.status='active'",actor,target)>0
            || db.count("SELECT count(*) FROM asp_team_member mine JOIN asp_account a ON a.person_id=mine.person_id JOIN asp_team_member peer ON peer.team_id=mine.team_id JOIN asp_account b ON b.person_id=peer.person_id WHERE a.id=? AND b.id=? AND mine.status='active' AND peer.status='active'",actor,target)>0;
    }

    public record AvatarReceipt(String fileId,long version) { }
}

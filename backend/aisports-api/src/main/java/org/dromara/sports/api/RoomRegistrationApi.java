package org.dromara.sports.api;
/** Room intent is not a registration declaration; prepare creates only a draft and personal invitations. */
public interface RoomRegistrationApi {
    Long prepare(Long roomId,String requestKey);
}

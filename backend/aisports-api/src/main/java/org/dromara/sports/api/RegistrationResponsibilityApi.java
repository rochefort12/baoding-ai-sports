package org.dromara.sports.api;
/** A frozen registration outlives a team. Unfinished manager responsibilities require explicit handover. */
public interface RegistrationResponsibilityApi { void requireTeamChange(Long teamId,Long personId,boolean disband); }

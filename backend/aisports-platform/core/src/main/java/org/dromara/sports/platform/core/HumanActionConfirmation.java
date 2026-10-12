package org.dromara.sports.platform.core;
import com.fasterxml.jackson.databind.JsonNode;
/** Confirmation can only be issued under the current interactive human session. */
public interface HumanActionConfirmation { Long confirm(String code,JsonNode input); }

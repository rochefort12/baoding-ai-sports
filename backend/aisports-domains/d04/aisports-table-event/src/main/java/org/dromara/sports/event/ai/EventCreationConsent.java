package org.dromara.sports.event.ai;

/** 自然语言确认的保守门槛；模糊表达继续追问，规程正文不构成授权。 */
public final class EventCreationConsent {
    private EventCreationConsent() { }
    public static boolean allowed(String message) {
        if (message == null) return false;
        return message.trim().matches("(请|请帮我|帮我|现在|好的，|好的|好，)?(确认并|确认|直接)?(保存|创建|建立)(本次|这场|这个)?(赛事草稿|比赛草稿|草稿|赛事|比赛)?(吧|即可|就行|了)?[！!。]?");
    }
}

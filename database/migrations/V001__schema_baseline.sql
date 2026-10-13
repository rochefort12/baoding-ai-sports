-- 结构基线。空库执行完原先 V001 到 V041 之后的业务表结构。
-- 不包含框架表、菜单角色，也不包含运动项目和智能体目录。
-- 不回放旧库上的数据修补。以后结构变化另写新版本，不改这个文件。
-- 模型里尚未落到迁移的属性目录三表不在这里。

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.11 (Debian 17.11-1.pgdg12+2)
-- Dumped by pg_dump version 17.11 (Debian 17.11-1.pgdg12+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: asp_account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_account (
    id bigint NOT NULL,
    display_name character varying(100) NOT NULL,
    backend_user_id bigint,
    status character varying(32) NOT NULL,
    closed_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    person_id bigint,
    password_hash character varying(100),
    CONSTRAINT asp_account_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'restricted'::character varying, 'recovery'::character varying, 'closing'::character varying, 'closed'::character varying])::text[]))),
    CONSTRAINT asp_account_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_account; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_account IS '平台登录账号；现实运动者与后台员工账号独立；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_account.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_account.display_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.display_name IS '登录账号展示名';


--
-- Name: COLUMN asp_account.backend_user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.backend_user_id IS '可选后台 sys_user 关联；应用核验租户和登录归属';


--
-- Name: COLUMN asp_account.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.status IS '独立业务状态；合法值不等于业务已获批准：active restricted recovery closing closed';


--
-- Name: COLUMN asp_account.closed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.closed_at IS '账号服务停止时间；有时区业务时间';


--
-- Name: COLUMN asp_account.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_account.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_account.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_account.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_account.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_account.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_account.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.person_id IS '本人参赛档案；空表示尚未建档。一名账号最多一份。';


--
-- Name: COLUMN asp_account.password_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account.password_hash IS '登录密码散列。只供平台登录校验，不写入日志';


--
-- Name: asp_account_tenant_principal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_account_tenant_principal (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    sys_user_id bigint NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_account_tenant_principal_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT asp_account_tenant_principal_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_account_tenant_principal_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_account_tenant_principal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_account_tenant_principal IS '平台账号在一个租户里的若依用户映射。映射存在不等于可以进入组织';


--
-- Name: COLUMN asp_account_tenant_principal.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account_tenant_principal.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_account_tenant_principal.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account_tenant_principal.account_id IS '平台账号';


--
-- Name: COLUMN asp_account_tenant_principal.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account_tenant_principal.tenant_id IS '组织租户编号。由服务写入和查询，不作为租户拦截条件';


--
-- Name: COLUMN asp_account_tenant_principal.sys_user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account_tenant_principal.sys_user_id IS '该租户内的若依用户。不是平台自然人';


--
-- Name: COLUMN asp_account_tenant_principal.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account_tenant_principal.status IS '独立业务状态；合法值不等于业务已获批准：active revoked';


--
-- Name: COLUMN asp_account_tenant_principal.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account_tenant_principal.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_account_tenant_principal.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account_tenant_principal.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_account_tenant_principal.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account_tenant_principal.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_account_tenant_principal.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account_tenant_principal.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_account_tenant_principal.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account_tenant_principal.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_account_tenant_principal.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_account_tenant_principal.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_action_confirmation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_action_confirmation (
    id bigint NOT NULL,
    run_id bigint,
    actor_type character varying(32) NOT NULL,
    actor_id bigint NOT NULL,
    action_code character varying(160) NOT NULL,
    payload_hash character varying(64) NOT NULL,
    object_versions jsonb NOT NULL,
    status character varying(32) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    confirmed_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_action_confirmation_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'confirmed'::character varying, 'consumed'::character varying, 'expired'::character varying])::text[]))),
    CONSTRAINT asp_action_confirmation_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_action_confirmation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_action_confirmation IS '登录本人对特定能力、输入摘要和对象版本的一次确认';


--
-- Name: COLUMN asp_action_confirmation.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_action_confirmation.run_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.run_id IS '关联运行';


--
-- Name: COLUMN asp_action_confirmation.actor_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.actor_type IS '确认主体类型';


--
-- Name: COLUMN asp_action_confirmation.actor_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.actor_id IS '确认人编号';


--
-- Name: COLUMN asp_action_confirmation.action_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.action_code IS '动作';


--
-- Name: COLUMN asp_action_confirmation.payload_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.payload_hash IS '确认内容摘要';


--
-- Name: COLUMN asp_action_confirmation.object_versions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.object_versions IS '对象及预期版本；必须按版本校验结构';


--
-- Name: COLUMN asp_action_confirmation.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.status IS '独立业务状态；合法值不等于业务已获批准：pending confirmed consumed expired';


--
-- Name: COLUMN asp_action_confirmation.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.expires_at IS '有效期限；有时区业务时间';


--
-- Name: COLUMN asp_action_confirmation.confirmed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.confirmed_at IS '本人点击确认；有时区业务时间';


--
-- Name: COLUMN asp_action_confirmation.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_action_confirmation.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_action_confirmation.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_action_confirmation.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_action_confirmation.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_action_confirmation.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_confirmation.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_action_execution; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_action_execution (
    id bigint NOT NULL,
    action_code character varying(160) NOT NULL,
    actor_type character varying(32) NOT NULL,
    actor_id bigint NOT NULL,
    tenant_scope character varying(20),
    channel character varying(16) NOT NULL,
    request_key character varying(128) NOT NULL,
    payload_hash character varying(64) NOT NULL,
    status character varying(32) NOT NULL,
    result_reference jsonb NOT NULL,
    error_code character varying(64),
    run_id bigint,
    occurred_at timestamp with time zone NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_action_execution_status_check CHECK (((status)::text = ANY ((ARRAY['succeeded'::character varying, 'failed'::character varying, 'denied'::character varying])::text[]))),
    CONSTRAINT asp_action_execution_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_action_execution; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_action_execution IS '统一动作终态回执；成功与业务同事务，失败独立留痕，不存私有完整响应';


--
-- Name: COLUMN asp_action_execution.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_action_execution.action_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.action_code IS '动作编码';


--
-- Name: COLUMN asp_action_execution.actor_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.actor_type IS '真实主体类型';


--
-- Name: COLUMN asp_action_execution.actor_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.actor_id IS '主体编号';


--
-- Name: COLUMN asp_action_execution.tenant_scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.tenant_scope IS '服务器确定的组织范围';


--
-- Name: COLUMN asp_action_execution.channel; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.channel IS '调用渠道';


--
-- Name: COLUMN asp_action_execution.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.request_key IS '防重请求键';


--
-- Name: COLUMN asp_action_execution.payload_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.payload_hash IS '输入摘要';


--
-- Name: COLUMN asp_action_execution.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.status IS '独立业务状态；合法值不等于业务已获批准：succeeded failed denied';


--
-- Name: COLUMN asp_action_execution.result_reference; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.result_reference IS '结果对象和允许的状态摘要；必须按版本校验结构';


--
-- Name: COLUMN asp_action_execution.error_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.error_code IS '失败代码';


--
-- Name: COLUMN asp_action_execution.run_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.run_id IS '关联智能体运行';


--
-- Name: COLUMN asp_action_execution.occurred_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.occurred_at IS '执行结束；有时区业务时间';


--
-- Name: COLUMN asp_action_execution.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_action_execution.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_action_execution.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_action_execution.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_action_execution.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_action_execution.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_action_execution.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_advancement; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_advancement (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    result_version_id bigint NOT NULL,
    registration_id bigint NOT NULL,
    target_stage_id bigint NOT NULL,
    target_slot character varying(100) NOT NULL,
    status character varying(32) NOT NULL,
    basis jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_advancement_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'confirmed'::character varying, 'superseded'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT asp_advancement_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_advancement_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_advancement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_advancement IS '确认结果驱动晋级；重复确认不重复产生席位；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_advancement.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_advancement.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_advancement.result_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.result_version_id IS '上游已确认结果';


--
-- Name: COLUMN asp_advancement.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.registration_id IS '晋级报名单位';


--
-- Name: COLUMN asp_advancement.target_stage_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.target_stage_id IS '下一阶段';


--
-- Name: COLUMN asp_advancement.target_slot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.target_slot IS '下一阶段稳定席位';


--
-- Name: COLUMN asp_advancement.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.status IS '独立业务状态；合法值不等于业务已获批准：pending confirmed superseded revoked';


--
-- Name: COLUMN asp_advancement.basis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.basis IS '名次或成绩资格依据；必须按版本校验结构';


--
-- Name: COLUMN asp_advancement.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_advancement.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_advancement.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_advancement.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_advancement.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_advancement.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_advancement.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_agent; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_agent (
    id bigint NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(100) NOT NULL,
    layer character varying(32) NOT NULL,
    domain_scope character varying(32),
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_agent_layer_check CHECK (((layer)::text = ANY ((ARRAY['global'::character varying, 'domain'::character varying, 'function'::character varying])::text[]))),
    CONSTRAINT asp_agent_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'disabled'::character varying])::text[]))),
    CONSTRAINT asp_agent_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_agent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_agent IS '智能体定义，按平台、业务域和职能分层；没有原始SQL能力';


--
-- Name: COLUMN asp_agent.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_agent.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.code IS '稳定编码';


--
-- Name: COLUMN asp_agent.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.name IS '名称';


--
-- Name: COLUMN asp_agent.layer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.layer IS '独立业务状态；合法值不等于业务已获批准：global domain function';


--
-- Name: COLUMN asp_agent.domain_scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.domain_scope IS '体育业务域范围';


--
-- Name: COLUMN asp_agent.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.status IS '独立业务状态；合法值不等于业务已获批准：active disabled';


--
-- Name: COLUMN asp_agent.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_agent.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_agent.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_agent.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_agent.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_agent.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_agent_grant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_agent_grant (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    capability_code character varying(160) NOT NULL,
    scope jsonb NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_agent_grant_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT asp_agent_grant_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_agent_grant; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_agent_grant IS '智能体能力及委派上限；与委托人实时权限取交集';


--
-- Name: COLUMN asp_agent_grant.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_grant.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_agent_grant.agent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_grant.agent_id IS '智能体';


--
-- Name: COLUMN asp_agent_grant.capability_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_grant.capability_code IS '允许能力或delegate目标';


--
-- Name: COLUMN asp_agent_grant.scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_grant.scope IS '能力、组织和对象上限；必须按版本校验结构';


--
-- Name: COLUMN asp_agent_grant.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_grant.status IS '独立业务状态；合法值不等于业务已获批准：active revoked';


--
-- Name: COLUMN asp_agent_grant.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_grant.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_agent_grant.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_grant.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_agent_grant.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_grant.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_agent_grant.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_grant.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_agent_grant.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_grant.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_agent_grant.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_grant.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_agent_message; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_agent_message (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    role character varying(32) NOT NULL,
    content text NOT NULL,
    blocks jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_agent_message_role_check CHECK (((role)::text = ANY ((ARRAY['user'::character varying, 'assistant'::character varying])::text[]))),
    CONSTRAINT asp_agent_message_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_agent_message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_agent_message IS '本人可恢复的可见对话；用途受控，不向其他人共享';


--
-- Name: COLUMN asp_agent_message.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_message.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_agent_message.run_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_message.run_id IS '运行';


--
-- Name: COLUMN asp_agent_message.role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_message.role IS '独立业务状态；合法值不等于业务已获批准：user assistant';


--
-- Name: COLUMN asp_agent_message.content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_message.content IS '用户可见文本；不存密钥或隐藏思考';


--
-- Name: COLUMN asp_agent_message.blocks; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_message.blocks IS '经过校验的表单、确认、回执和跳转块；必须按版本校验结构';


--
-- Name: COLUMN asp_agent_message.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_message.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_agent_message.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_message.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_agent_message.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_message.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_agent_message.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_message.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_agent_message.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_message.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_agent_message.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_message.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_agent_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_agent_run (
    id bigint NOT NULL,
    agent_version_id bigint NOT NULL,
    actor_type character varying(32) NOT NULL,
    actor_id bigint NOT NULL,
    parent_run_id bigint,
    root_run_id bigint,
    scope jsonb NOT NULL,
    goal character varying(2000) NOT NULL,
    status character varying(32) NOT NULL,
    depth integer NOT NULL,
    tool_count integer NOT NULL,
    tokens_used integer NOT NULL,
    token_hash character varying(64) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    started_at timestamp with time zone NOT NULL,
    ended_at timestamp with time zone,
    stop_reason character varying(64),
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    tokens_reserved integer DEFAULT 0 NOT NULL,
    round_key character varying(64) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT asp_agent_run_depth_check CHECK ((depth >= 0)),
    CONSTRAINT asp_agent_run_status_runtime_check CHECK (((status)::text = ANY ((ARRAY['running'::character varying, 'waiting_children'::character varying, 'waiting_input'::character varying, 'waiting_confirmation'::character varying, 'completed'::character varying, 'failed'::character varying, 'stopped'::character varying])::text[]))),
    CONSTRAINT asp_agent_run_tokens_reserved_check CHECK ((tokens_reserved >= 0)),
    CONSTRAINT asp_agent_run_tokens_used_check CHECK ((tokens_used >= 0)),
    CONSTRAINT asp_agent_run_tool_count_check CHECK ((tool_count >= 0)),
    CONSTRAINT asp_agent_run_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_agent_run; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_agent_run IS '服务端签发的运行身份与进度；不保存密钥或隐藏思考';


--
-- Name: COLUMN asp_agent_run.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_agent_run.agent_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.agent_version_id IS '锁定版本';


--
-- Name: COLUMN asp_agent_run.actor_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.actor_type IS '委托人主体类型';


--
-- Name: COLUMN asp_agent_run.actor_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.actor_id IS '委托人编号';


--
-- Name: COLUMN asp_agent_run.parent_run_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.parent_run_id IS '父运行';


--
-- Name: COLUMN asp_agent_run.root_run_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.root_run_id IS '根运行';


--
-- Name: COLUMN asp_agent_run.scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.scope IS '服务器确定的对象和权限范围；必须按版本校验结构';


--
-- Name: COLUMN asp_agent_run.goal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.goal IS '用户可见目标';


--
-- Name: COLUMN asp_agent_run.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.status IS '独立业务状态；合法值不等于业务已获批准：running waiting_input waiting_confirmation completed failed stopped';


--
-- Name: COLUMN asp_agent_run.depth; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.depth IS '绝对委派深度';


--
-- Name: COLUMN asp_agent_run.tool_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.tool_count IS '已调用工具数';


--
-- Name: COLUMN asp_agent_run.tokens_used; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.tokens_used IS '供应商报告用量';


--
-- Name: COLUMN asp_agent_run.token_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.token_hash IS '运行令牌摘要，原令牌不入库';


--
-- Name: COLUMN asp_agent_run.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.expires_at IS '运行令牌截止；有时区业务时间';


--
-- Name: COLUMN asp_agent_run.started_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.started_at IS '开始；有时区业务时间';


--
-- Name: COLUMN asp_agent_run.ended_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.ended_at IS '结束；有时区业务时间';


--
-- Name: COLUMN asp_agent_run.stop_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.stop_reason IS '停止原因';


--
-- Name: COLUMN asp_agent_run.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_agent_run.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_agent_run.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_agent_run.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_agent_run.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_agent_run.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_agent_run.tokens_reserved; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_run.tokens_reserved IS 'Active model round reservation; root-run aggregate enforces the locked total budget';


--
-- Name: asp_agent_step; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_agent_step (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    sequence integer NOT NULL,
    kind character varying(32) NOT NULL,
    name character varying(160) NOT NULL,
    status character varying(32) NOT NULL,
    summary jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_agent_step_kind_check CHECK (((kind)::text = ANY ((ARRAY['model'::character varying, 'tool'::character varying, 'delegate'::character varying, 'confirmation'::character varying, 'control'::character varying])::text[]))),
    CONSTRAINT asp_agent_step_sequence_check CHECK ((sequence >= 0)),
    CONSTRAINT asp_agent_step_status_check CHECK (((status)::text = ANY ((ARRAY['started'::character varying, 'succeeded'::character varying, 'failed'::character varying, 'denied'::character varying])::text[]))),
    CONSTRAINT asp_agent_step_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_agent_step; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_agent_step IS '可见模型、工具和委派步骤摘要，不包含材料正文和隐藏思考';


--
-- Name: COLUMN asp_agent_step.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_agent_step.run_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.run_id IS '运行';


--
-- Name: COLUMN asp_agent_step.sequence; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.sequence IS '顺序';


--
-- Name: COLUMN asp_agent_step.kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.kind IS '独立业务状态；合法值不等于业务已获批准：model tool delegate confirmation control';


--
-- Name: COLUMN asp_agent_step.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.name IS '模型或能力名称';


--
-- Name: COLUMN asp_agent_step.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.status IS '独立业务状态；合法值不等于业务已获批准：started succeeded failed denied';


--
-- Name: COLUMN asp_agent_step.summary; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.summary IS '可见状态、来源引用与用量；必须按版本校验结构';


--
-- Name: COLUMN asp_agent_step.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_agent_step.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_agent_step.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_agent_step.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_agent_step.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_agent_step.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_step.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_agent_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_agent_version (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    revision integer NOT NULL,
    model_name character varying(80) NOT NULL,
    instruction text NOT NULL,
    budget jsonb NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    tool_catalog jsonb DEFAULT '{}'::jsonb NOT NULL,
    skill_catalog jsonb DEFAULT '{}'::jsonb NOT NULL,
    business_map jsonb DEFAULT '{}'::jsonb NOT NULL,
    playbook_hash character varying(64) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT asp_agent_version_business_map_object CHECK ((jsonb_typeof(business_map) = 'object'::text)),
    CONSTRAINT asp_agent_version_revision_check CHECK ((revision >= 0)),
    CONSTRAINT asp_agent_version_revision_check1 CHECK ((revision > 0)),
    CONSTRAINT asp_agent_version_skill_catalog_object CHECK ((jsonb_typeof(skill_catalog) = 'object'::text)),
    CONSTRAINT asp_agent_version_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying, 'retired'::character varying])::text[]))),
    CONSTRAINT asp_agent_version_tool_catalog_object CHECK ((jsonb_typeof(tool_catalog) = 'object'::text)),
    CONSTRAINT asp_agent_version_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_agent_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_agent_version IS '智能体提示词与模型的可追溯版本；只记录可见业务指引';


--
-- Name: COLUMN asp_agent_version.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_agent_version.agent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.agent_id IS '智能体';


--
-- Name: COLUMN asp_agent_version.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.revision IS '版本';


--
-- Name: COLUMN asp_agent_version.model_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.model_name IS '固定接口模型名';


--
-- Name: COLUMN asp_agent_version.instruction; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.instruction IS '可信平台提示词，不能由上传材料改写';


--
-- Name: COLUMN asp_agent_version.budget; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.budget IS '深度、调用和时间预算；必须按版本校验结构';


--
-- Name: COLUMN asp_agent_version.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.status IS '独立业务状态；合法值不等于业务已获批准：draft active retired';


--
-- Name: COLUMN asp_agent_version.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_agent_version.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_agent_version.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_agent_version.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_agent_version.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_agent_version.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_agent_version.tool_catalog; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.tool_catalog IS 'Versioned controlled MCP tools and invocation contracts; never grants permissions';


--
-- Name: COLUMN asp_agent_version.skill_catalog; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.skill_catalog IS 'Trusted platform skills, not model output or hidden thought';


--
-- Name: COLUMN asp_agent_version.business_map; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.business_map IS 'Versioned role flows and dependencies; availability is checked against live registry';


--
-- Name: COLUMN asp_agent_version.playbook_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_agent_version.playbook_hash IS 'SHA256 of canonical tools/skills/businessMap JSON bound to the agent revision';


--
-- Name: asp_ai_gateway_call; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_ai_gateway_call (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    task_id bigint NOT NULL,
    tool_name character varying(80) NOT NULL,
    phase character varying(32) NOT NULL,
    outcome character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_ai_gateway_call_outcome_check CHECK (((outcome)::text = ANY ((ARRAY['ok'::character varying, 'rejected'::character varying])::text[]))),
    CONSTRAINT asp_ai_gateway_call_phase_check CHECK (((phase)::text = ANY ((ARRAY['read'::character varying, 'apply'::character varying])::text[]))),
    CONSTRAINT asp_ai_gateway_call_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_ai_gateway_call_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_ai_gateway_call; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_ai_gateway_call IS 'AI 工具调用留痕。只记录工具名、阶段和成败，不记录参数、响应和原文';


--
-- Name: COLUMN asp_ai_gateway_call.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_ai_gateway_call.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_ai_gateway_call.task_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.task_id IS '所属提案';


--
-- Name: COLUMN asp_ai_gateway_call.tool_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.tool_name IS '工具名，与业务域工具说明一致';


--
-- Name: COLUMN asp_ai_gateway_call.phase; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.phase IS 'read 只发生在确认前；apply 只发生在用户确认之后：read apply';


--
-- Name: COLUMN asp_ai_gateway_call.outcome; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.outcome IS '工具是否按允许的方式完成：ok rejected';


--
-- Name: COLUMN asp_ai_gateway_call.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_ai_gateway_call.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_ai_gateway_call.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_ai_gateway_call.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_ai_gateway_call.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_ai_gateway_call.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_call.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_ai_gateway_task; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_ai_gateway_task (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    organization_id bigint NOT NULL,
    domain_code character varying(64) NOT NULL,
    status character varying(32) NOT NULL,
    source_name character varying(200) NOT NULL,
    source_media_type character varying(100) NOT NULL,
    source_sha256 character varying(64) NOT NULL,
    proposal jsonb NOT NULL,
    apply_request_key character varying(128),
    event_id bigint,
    confirmed_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_ai_gateway_task_check CHECK ((((status)::text <> 'confirmed'::text) OR ((event_id IS NOT NULL) AND (confirmed_at IS NOT NULL) AND (apply_request_key IS NOT NULL)))),
    CONSTRAINT asp_ai_gateway_task_check1 CHECK ((((status)::text <> 'applying'::text) OR (apply_request_key IS NOT NULL))),
    CONSTRAINT asp_ai_gateway_task_domain_code_check CHECK (((domain_code)::text ~ '^[a-z][a-z0-9-]{0,63}$'::text)),
    CONSTRAINT asp_ai_gateway_task_source_sha256_check CHECK (((source_sha256)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT asp_ai_gateway_task_status_check CHECK (((status)::text = ANY ((ARRAY['extracted'::character varying, 'applying'::character varying, 'confirmed'::character varying, 'discarded'::character varying])::text[]))),
    CONSTRAINT asp_ai_gateway_task_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_ai_gateway_task_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_ai_gateway_task; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_ai_gateway_task IS 'AI 办赛提案。确认前不是赛事。确认后只引用赛事服务已经创建的草稿。不保存上传原文、证件号和模型密钥';


--
-- Name: COLUMN asp_ai_gateway_task.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_ai_gateway_task.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_ai_gateway_task.organization_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.organization_id IS '提出提案的办赛组织';


--
-- Name: COLUMN asp_ai_gateway_task.domain_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.domain_code IS '业务域编码。各域自带提示词和工具说明，账本不解释域内含义';


--
-- Name: COLUMN asp_ai_gateway_task.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.status IS '提案状态。applying 表示正在生成草稿，同一请求键可以重试：extracted applying confirmed discarded';


--
-- Name: COLUMN asp_ai_gateway_task.source_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.source_name IS '上传文件名。不保存文件正文';


--
-- Name: COLUMN asp_ai_gateway_task.source_media_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.source_media_type IS '上传文件媒体类型';


--
-- Name: COLUMN asp_ai_gateway_task.source_sha256; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.source_sha256 IS '文件内容 SHA-256。用于识别同一份资料，不保存原文';


--
-- Name: COLUMN asp_ai_gateway_task.proposal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.proposal IS '待确认提案。只含赛事字段、竞赛项目、缺失项和短引用；必须按版本校验结构';


--
-- Name: COLUMN asp_ai_gateway_task.apply_request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.apply_request_key IS '生成草稿的幂等键。同一键重复提交不新建赛事';


--
-- Name: COLUMN asp_ai_gateway_task.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.event_id IS '已经生成的赛事草稿。确认前为空';


--
-- Name: COLUMN asp_ai_gateway_task.confirmed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.confirmed_at IS '办赛人员确认时间；有时区业务时间';


--
-- Name: COLUMN asp_ai_gateway_task.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_ai_gateway_task.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_ai_gateway_task.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_ai_gateway_task.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_ai_gateway_task.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_ai_gateway_task.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_gateway_task.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_ai_invocation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_ai_invocation (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    task_id bigint NOT NULL,
    kind character varying(16) NOT NULL,
    tool_name character varying(64),
    model_name character varying(80),
    status character varying(32) NOT NULL,
    attempt_no integer DEFAULT 0 NOT NULL,
    error_code character varying(64),
    summary jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_ai_invocation_attempt_no_check CHECK ((attempt_no >= 0)),
    CONSTRAINT asp_ai_invocation_kind_check CHECK (((kind)::text = ANY ((ARRAY['model'::character varying, 'tool'::character varying])::text[]))),
    CONSTRAINT asp_ai_invocation_status_check CHECK (((status)::text = ANY ((ARRAY['started'::character varying, 'succeeded'::character varying, 'failed'::character varying, 'refused'::character varying])::text[]))),
    CONSTRAINT asp_ai_invocation_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_ai_invocation_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_ai_invocation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_ai_invocation IS '模型或工具的一次调用。不保存密钥、登录令牌、资料正文和完整模型响应；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_ai_invocation.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_ai_invocation.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_ai_invocation.task_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.task_id IS '所属任务';


--
-- Name: COLUMN asp_ai_invocation.kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.kind IS 'model 或 tool';


--
-- Name: COLUMN asp_ai_invocation.tool_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.tool_name IS '工具名。模型调用可空';


--
-- Name: COLUMN asp_ai_invocation.model_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.model_name IS '实际请求的模型名。工具调用可空';


--
-- Name: COLUMN asp_ai_invocation.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.status IS '独立业务状态；合法值不等于业务已获批准：started succeeded failed refused';


--
-- Name: COLUMN asp_ai_invocation.attempt_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.attempt_no IS '对应任务上的第几次识别';


--
-- Name: COLUMN asp_ai_invocation.error_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.error_code IS '失败或拒绝代码';


--
-- Name: COLUMN asp_ai_invocation.summary; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.summary IS '耗时毫秒和是否降级。不存资料正文；必须按版本校验结构';


--
-- Name: COLUMN asp_ai_invocation.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_ai_invocation.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_ai_invocation.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_ai_invocation.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_ai_invocation.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_ai_invocation.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_invocation.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_ai_task; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_ai_task (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    scene character varying(64) NOT NULL,
    business_object character varying(32) NOT NULL,
    organization_id bigint NOT NULL,
    initiator_account_id bigint NOT NULL,
    status character varying(32) NOT NULL,
    bailian_consent boolean NOT NULL,
    extraction jsonb,
    proposal jsonb,
    error_code character varying(64),
    error_message character varying(500),
    attempt_count integer DEFAULT 0 NOT NULL,
    result_object_id bigint,
    confirm_key character varying(128),
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    provider_consent boolean DEFAULT false NOT NULL,
    provider_name character varying(64) DEFAULT 'legacy-bailian'::character varying NOT NULL,
    consent_version character varying(64) DEFAULT 'legacy'::character varying NOT NULL,
    CONSTRAINT asp_ai_task_attempt_count_check CHECK ((attempt_count >= 0)),
    CONSTRAINT asp_ai_task_status_check CHECK (((status)::text = ANY ((ARRAY['UPLOADED'::character varying, 'PROCESSING'::character varying, 'PENDING_CONFIRMATION'::character varying, 'CREATED'::character varying, 'FAILED'::character varying, 'ABANDONED'::character varying])::text[]))),
    CONSTRAINT asp_ai_task_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_ai_task_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_ai_actual_provider_consent CHECK (((bailian_consent = true) OR ((provider_consent = true) AND ((provider_name)::text = 'deepseek'::text))))
);


--
-- Name: TABLE asp_ai_task; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_ai_task IS '通用 AI 任务。按场景和业务对象记录资料、候选方案和最终业务对象，模型不直接写业务表；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_ai_task.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_ai_task.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_ai_task.scene; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.scene IS '场景编码。首个为 event.create_from_document';


--
-- Name: COLUMN asp_ai_task.business_object; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.business_object IS '业务对象类型。首个为 event';


--
-- Name: COLUMN asp_ai_task.organization_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.organization_id IS '发起任务的组织';


--
-- Name: COLUMN asp_ai_task.initiator_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.initiator_account_id IS '发起人平台账号。账号表无租户列，这里不建外键';


--
-- Name: COLUMN asp_ai_task.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.status IS '独立业务状态；合法值不等于业务已获批准：UPLOADED PROCESSING PENDING_CONFIRMATION CREATED FAILED ABANDONED';


--
-- Name: COLUMN asp_ai_task.bailian_consent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.bailian_consent IS '已同意把本次资料发给阿里云百炼';


--
-- Name: COLUMN asp_ai_task.extraction; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.extraction IS '本地解析出的原文块和位置。放弃任务后清空；必须按版本校验结构';


--
-- Name: COLUMN asp_ai_task.proposal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.proposal IS '候选方案、来源、缺失、冲突和建议。放弃任务后清空；必须按版本校验结构';


--
-- Name: COLUMN asp_ai_task.error_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.error_code IS '失败代码。可空';


--
-- Name: COLUMN asp_ai_task.error_message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.error_message IS '给操作者看的失败说明。不含密钥和堆栈';


--
-- Name: COLUMN asp_ai_task.attempt_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.attempt_count IS '已经执行的识别次数';


--
-- Name: COLUMN asp_ai_task.result_object_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.result_object_id IS '确认后写入的业务对象编号。可空，不建跨模块外键';


--
-- Name: COLUMN asp_ai_task.confirm_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.confirm_key IS '确认幂等键。同一任务成功后重复确认不再创建';


--
-- Name: COLUMN asp_ai_task.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_ai_task.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_ai_task.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_ai_task.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_ai_task.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_ai_task.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_ai_task_file; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_ai_task_file (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    task_id bigint NOT NULL,
    file_id bigint NOT NULL,
    sort_order integer NOT NULL,
    media_kind character varying(32) NOT NULL,
    original_name character varying(200),
    page_count integer,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_ai_task_file_media_kind_check CHECK (((media_kind)::text = ANY ((ARRAY['docx'::character varying, 'xlsx'::character varying, 'pdf-text'::character varying, 'pdf-scan'::character varying, 'jpeg'::character varying, 'png'::character varying, 'webp'::character varying])::text[]))),
    CONSTRAINT asp_ai_task_file_page_count_check CHECK ((page_count >= 0)),
    CONSTRAINT asp_ai_task_file_sort_order_check CHECK ((sort_order >= 0)),
    CONSTRAINT asp_ai_task_file_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_ai_task_file_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_ai_task_file; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_ai_task_file IS 'AI 任务附件引用。文件本体在对象存储，用途必须是 ai-source，不能借用收款码；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_ai_task_file.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_ai_task_file.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_ai_task_file.task_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.task_id IS '所属任务';


--
-- Name: COLUMN asp_ai_task_file.file_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.file_id IS 'asp_file 编号。文件表无租户列，这里不建外键';


--
-- Name: COLUMN asp_ai_task_file.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.sort_order IS '同一任务内从 0 开始的顺序';


--
-- Name: COLUMN asp_ai_task_file.media_kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.media_kind IS '嗅探后的类型：docx xlsx pdf-text pdf-scan jpeg png webp';


--
-- Name: COLUMN asp_ai_task_file.original_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.original_name IS '上传时的文件名，只用于展示';


--
-- Name: COLUMN asp_ai_task_file.page_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.page_count IS 'PDF 页数。其他类型为空';


--
-- Name: COLUMN asp_ai_task_file.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_ai_task_file.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_ai_task_file.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_ai_task_file.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_ai_task_file.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_ai_task_file.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ai_task_file.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_appeal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_appeal (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    match_id bigint,
    registration_id bigint NOT NULL,
    applicant_account_id bigint NOT NULL,
    result_version_id bigint,
    reason character varying(2000) NOT NULL,
    evidence jsonb NOT NULL,
    status character varying(32) NOT NULL,
    submitted_at timestamp with time zone NOT NULL,
    deadline_at timestamp with time zone NOT NULL,
    decision jsonb,
    fee_obligation_id bigint,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_appeal_check CHECK (((match_id IS NOT NULL) OR (result_version_id IS NULL))),
    CONSTRAINT asp_appeal_status_check CHECK (((status)::text = ANY ((ARRAY['submitted'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'reviewing'::character varying, 'decided'::character varying, 'withdrawn'::character varying])::text[]))),
    CONSTRAINT asp_appeal_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_appeal_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_appeal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_appeal IS '专业申诉与裁定；客服不能直接改赛果；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_appeal.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_appeal.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_appeal.match_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.match_id IS '比赛';


--
-- Name: COLUMN asp_appeal.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.registration_id IS '相关报名';


--
-- Name: COLUMN asp_appeal.applicant_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.applicant_account_id IS '获授权申请者';


--
-- Name: COLUMN asp_appeal.result_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.result_version_id IS '争议结果';


--
-- Name: COLUMN asp_appeal.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.reason IS '申诉理由';


--
-- Name: COLUMN asp_appeal.evidence; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.evidence IS '受控证据；必须按版本校验结构';


--
-- Name: COLUMN asp_appeal.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.status IS '独立业务状态；合法值不等于业务已获批准：submitted accepted rejected reviewing decided withdrawn';


--
-- Name: COLUMN asp_appeal.submitted_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.submitted_at IS '实际提交；有时区业务时间';


--
-- Name: COLUMN asp_appeal.deadline_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.deadline_at IS '规程期限；有时区业务时间';


--
-- Name: COLUMN asp_appeal.decision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.decision IS '专业裁定及后续晋级影响；必须按版本校验结构';


--
-- Name: COLUMN asp_appeal.fee_obligation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.fee_obligation_id IS '如规程要求申诉费，另行费用义务核验';


--
-- Name: COLUMN asp_appeal.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_appeal.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_appeal.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_appeal.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_appeal.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_appeal.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_appeal.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_audit_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_audit_event (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    actor_account_id bigint,
    action character varying(100) NOT NULL,
    object_type character varying(100) NOT NULL,
    object_id bigint,
    request_id character varying(128) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    summary jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_audit_event_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_audit_event_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_audit_event; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_audit_event IS '关键业务决定与资料访问审计；不写入原始敏感材料；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_audit_event.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_audit_event.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_audit_event.actor_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.actor_account_id IS '操作人';


--
-- Name: COLUMN asp_audit_event.action; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.action IS '业务或资料访问动作';


--
-- Name: COLUMN asp_audit_event.object_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.object_type IS '对象类型';


--
-- Name: COLUMN asp_audit_event.object_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.object_id IS '对象 ID';


--
-- Name: COLUMN asp_audit_event.request_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.request_id IS '调用追踪 ID';


--
-- Name: COLUMN asp_audit_event.occurred_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.occurred_at IS '发生时间；有时区业务时间';


--
-- Name: COLUMN asp_audit_event.summary; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.summary IS '理由、版本及允许的最小变化摘要；必须按版本校验结构';


--
-- Name: COLUMN asp_audit_event.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_audit_event.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_audit_event.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_audit_event.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_audit_event.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_audit_event.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_audit_event.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_capability_activation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_capability_activation (
    id bigint NOT NULL,
    code character varying(160) NOT NULL,
    capability_version_id bigint NOT NULL,
    channel character varying(32) NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_capability_activation_channel_check CHECK (((channel)::text = ANY ((ARRAY['ui'::character varying, 'agent'::character varying, 'system'::character varying])::text[]))),
    CONSTRAINT asp_capability_activation_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_capability_activation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_capability_activation IS '能力在人工、Agent和系统渠道的明确开放指针';


--
-- Name: COLUMN asp_capability_activation.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_activation.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_capability_activation.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_activation.code IS '能力编码';


--
-- Name: COLUMN asp_capability_activation.capability_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_activation.capability_version_id IS '已发布版本';


--
-- Name: COLUMN asp_capability_activation.channel; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_activation.channel IS '独立业务状态；合法值不等于业务已获批准：ui agent system';


--
-- Name: COLUMN asp_capability_activation.enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_activation.enabled IS '允许新调用';


--
-- Name: COLUMN asp_capability_activation.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_activation.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_capability_activation.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_activation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_capability_activation.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_activation.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_capability_activation.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_activation.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_capability_activation.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_activation.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_capability_activation.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_activation.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_capability_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_capability_version (
    id bigint NOT NULL,
    code character varying(160) NOT NULL,
    revision integer NOT NULL,
    definition jsonb NOT NULL,
    source_hash character varying(64) NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_capability_version_revision_check CHECK ((revision >= 0)),
    CONSTRAINT asp_capability_version_revision_check1 CHECK ((revision > 0)),
    CONSTRAINT asp_capability_version_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'tested'::character varying, 'published'::character varying, 'retired'::character varying])::text[]))),
    CONSTRAINT asp_capability_version_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_capability_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_capability_version IS '经过实现与测试的能力版本；描述不是授权';


--
-- Name: COLUMN asp_capability_version.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_capability_version.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.code IS '能力编码';


--
-- Name: COLUMN asp_capability_version.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.revision IS '版本';


--
-- Name: COLUMN asp_capability_version.definition; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.definition IS '参数、结果、读写范围、确认和权限；必须按版本校验结构';


--
-- Name: COLUMN asp_capability_version.source_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.source_hash IS '定义SHA256';


--
-- Name: COLUMN asp_capability_version.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.status IS '独立业务状态；合法值不等于业务已获批准：draft tested published retired';


--
-- Name: COLUMN asp_capability_version.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_capability_version.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_capability_version.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_capability_version.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_capability_version.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_capability_version.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capability_version.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_capacity_occupation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_capacity_occupation (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    pool_id bigint NOT NULL,
    subject_key character varying(128) NOT NULL,
    person_id bigint,
    status character varying(32) NOT NULL,
    expires_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_capacity_occupation_status_check CHECK (((status)::text = ANY ((ARRAY['held'::character varying, 'effective'::character varying, 'released'::character varying])::text[]))),
    CONSTRAINT asp_capacity_occupation_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_capacity_occupation_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_capacity_occupation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_capacity_occupation IS '容量唯一占用对象；同人兼项总人数只占一次；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_capacity_occupation.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_capacity_occupation.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_capacity_occupation.pool_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.pool_id IS '容量池';


--
-- Name: COLUMN asp_capacity_occupation.subject_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.subject_key IS 'person:<ID> 或 entry:<ID> 等稳定单位键';


--
-- Name: COLUMN asp_capacity_occupation.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.person_id IS '按人占用时对应身份';


--
-- Name: COLUMN asp_capacity_occupation.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.status IS '独立业务状态；合法值不等于业务已获批准：held effective released';


--
-- Name: COLUMN asp_capacity_occupation.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.expires_at IS '仅临时占用期限；有时区业务时间';


--
-- Name: COLUMN asp_capacity_occupation.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_capacity_occupation.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_capacity_occupation.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_capacity_occupation.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_capacity_occupation.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_capacity_occupation.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_occupation.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_capacity_pool; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_capacity_pool (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint NOT NULL,
    unit_id bigint,
    capacity_unit character varying(32) NOT NULL,
    dedupe_scope character varying(100) NOT NULL,
    limit_count integer NOT NULL,
    used_count integer NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_capacity_pool_check CHECK ((used_count <= limit_count)),
    CONSTRAINT asp_capacity_pool_limit_count_check CHECK ((limit_count >= 0)),
    CONSTRAINT asp_capacity_pool_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'suspended'::character varying, 'closed'::character varying])::text[]))),
    CONSTRAINT asp_capacity_pool_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_capacity_pool_used_count_check CHECK ((used_count >= 0)),
    CONSTRAINT asp_capacity_pool_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_asp_capacity_pool_unit CHECK (((capacity_unit)::text = ANY ((ARRAY['person'::character varying, 'pair'::character varying, 'team'::character varying, 'seat'::character varying, 'lane'::character varying, 'entry'::character varying])::text[])))
);


--
-- Name: TABLE asp_capacity_pool; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_capacity_pool IS '总人数或项目容量；单位和去重范围显式；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_capacity_pool.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_capacity_pool.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_capacity_pool.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.event_id IS '赛事';


--
-- Name: COLUMN asp_capacity_pool.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.unit_id IS '项目容量；总量可为空';


--
-- Name: COLUMN asp_capacity_pool.capacity_unit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.capacity_unit IS '容量单位。M1.4 报名使用 entry';


--
-- Name: COLUMN asp_capacity_pool.dedupe_scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.dedupe_scope IS '计数去重范围。M1.4 按 entry 整单计数';


--
-- Name: COLUMN asp_capacity_pool.limit_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.limit_count IS '上限';


--
-- Name: COLUMN asp_capacity_pool.used_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.used_count IS '当前有效及临时占用数；同事务维护';


--
-- Name: COLUMN asp_capacity_pool.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.status IS '独立业务状态；合法值不等于业务已获批准：active suspended closed';


--
-- Name: COLUMN asp_capacity_pool.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_capacity_pool.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_capacity_pool.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_capacity_pool.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_capacity_pool.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_capacity_pool.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_capacity_pool.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_change_case; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_change_case (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    object_type character varying(100) NOT NULL,
    object_id bigint NOT NULL,
    before_snapshot jsonb NOT NULL,
    after_snapshot jsonb NOT NULL,
    impact jsonb NOT NULL,
    status character varying(32) NOT NULL,
    reason character varying(2000) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_change_case_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'reviewing'::character varying, 'approved'::character varying, 'published'::character varying, 'coordinating'::character varying, 'completed'::character varying, 'rejected'::character varying])::text[]))),
    CONSTRAINT asp_change_case_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_change_case_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_change_case; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_change_case IS '重大变更旧新版本、影响及责任接续；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_change_case.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_change_case.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_change_case.object_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.object_type IS '赛事/名单/收费/结果等';


--
-- Name: COLUMN asp_change_case.object_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.object_id IS '业务对象';


--
-- Name: COLUMN asp_change_case.before_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.before_snapshot IS '原事实；必须按版本校验结构';


--
-- Name: COLUMN asp_change_case.after_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.after_snapshot IS '草案或已确认事实；必须按版本校验结构';


--
-- Name: COLUMN asp_change_case.impact; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.impact IS '受影响人员、资源、金额、晋级、证书及通知；必须按版本校验结构';


--
-- Name: COLUMN asp_change_case.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.status IS '独立业务状态；合法值不等于业务已获批准：draft reviewing approved published coordinating completed rejected';


--
-- Name: COLUMN asp_change_case.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.reason IS '变更依据';


--
-- Name: COLUMN asp_change_case.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_change_case.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_change_case.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_change_case.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_change_case.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_change_case.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_change_case.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_checkin; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_checkin (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint NOT NULL,
    person_id bigint NOT NULL,
    match_id bigint,
    check_type character varying(100) NOT NULL,
    status character varying(32) NOT NULL,
    verification jsonb NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    request_key character varying(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    unit_id bigint,
    CONSTRAINT asp_checkin_status_check CHECK (((status)::text = ANY ((ARRAY['confirmed'::character varying, 'corrected'::character varying, 'rejected'::character varying])::text[]))),
    CONSTRAINT asp_checkin_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_checkin_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_asp_checkin_unit_scope CHECK ((((check_type)::text <> 'unit'::text) OR ((unit_id IS NOT NULL) AND (match_id IS NULL))))
);


--
-- Name: TABLE asp_checkin; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_checkin IS '逐现实选手报到/检录；队长到场不代表全队；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_checkin.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_checkin.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_checkin.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.event_id IS '赛事';


--
-- Name: COLUMN asp_checkin.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.person_id IS '实际到场人';


--
-- Name: COLUMN asp_checkin.match_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.match_id IS '单场检录；赛事报到可为空';


--
-- Name: COLUMN asp_checkin.check_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.check_type IS 'unit 项目报到、event 历史赛事级报到、match 单场检录';


--
-- Name: COLUMN asp_checkin.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.status IS '独立业务状态；合法值不等于业务已获批准：confirmed corrected rejected';


--
-- Name: COLUMN asp_checkin.verification; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.verification IS '授权核验方式及必要材料；必须按版本校验结构';


--
-- Name: COLUMN asp_checkin.occurred_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.occurred_at IS '现场发生时间；有时区业务时间';


--
-- Name: COLUMN asp_checkin.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.request_key IS '扫描/离线补录幂等键';


--
-- Name: COLUMN asp_checkin.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_checkin.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_checkin.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_checkin.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_checkin.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_checkin.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_checkin.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_checkin.unit_id IS '赛事项目；旧赛事级记录项目未知，保留为空待核对';


--
-- Name: asp_collaboration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_collaboration (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint NOT NULL,
    organization_id bigint NOT NULL,
    partner_tenant_id character varying(20) NOT NULL,
    partner_organization_id bigint NOT NULL,
    display_role character varying(100) NOT NULL,
    authorized_scope jsonb NOT NULL,
    valid_from timestamp with time zone NOT NULL,
    valid_until timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_collaboration_check CHECK (((valid_until IS NULL) OR (valid_until > valid_from))),
    CONSTRAINT asp_collaboration_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_collaboration_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_collaboration; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_collaboration IS '多方办赛展示与业务授权分离；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_collaboration.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_collaboration.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_collaboration.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.event_id IS '主责组织赛事';


--
-- Name: COLUMN asp_collaboration.organization_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.organization_id IS '授权发出组织；同租户';


--
-- Name: COLUMN asp_collaboration.partner_tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.partner_tenant_id IS '合作组织所在租户；跨租户访问需独立授权';


--
-- Name: COLUMN asp_collaboration.partner_organization_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.partner_organization_id IS '合作主体 ID；跨租户 API 核验';


--
-- Name: COLUMN asp_collaboration.display_role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.display_role IS '主办/承办/协办展示身份';


--
-- Name: COLUMN asp_collaboration.authorized_scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.authorized_scope IS '明确可见赛事、动作、材料；必须按版本校验结构';


--
-- Name: COLUMN asp_collaboration.valid_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.valid_from IS '合作生效；有时区业务时间';


--
-- Name: COLUMN asp_collaboration.valid_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.valid_until IS '合作终止；有时区业务时间';


--
-- Name: COLUMN asp_collaboration.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_collaboration.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_collaboration.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_collaboration.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_collaboration.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_collaboration.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_collaboration.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_competition_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_competition_type (
    id bigint NOT NULL,
    sport_id bigint NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(100) NOT NULL,
    entry_type character varying(32) NOT NULL,
    min_members integer NOT NULL,
    max_members integer NOT NULL,
    capability_status character varying(32) NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_competition_type_capability_status_check CHECK (((capability_status)::text = ANY ((ARRAY['catalog'::character varying, 'registration'::character varying, 'manual'::character varying, 'automatic'::character varying, 'verified'::character varying])::text[]))),
    CONSTRAINT asp_competition_type_check CHECK ((max_members >= min_members)),
    CONSTRAINT asp_competition_type_entry_type_check CHECK (((entry_type)::text = ANY ((ARRAY['individual'::character varying, 'pair'::character varying, 'team'::character varying])::text[]))),
    CONSTRAINT asp_competition_type_max_members_check CHECK ((max_members >= 0)),
    CONSTRAINT asp_competition_type_min_members_check CHECK ((min_members >= 0)),
    CONSTRAINT asp_competition_type_min_members_check1 CHECK ((min_members > 0)),
    CONSTRAINT asp_competition_type_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'disabled'::character varying])::text[]))),
    CONSTRAINT asp_competition_type_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_competition_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_competition_type IS '运动下的比赛类型；人数和报名形式用于办赛、房间和报名的共同约束';


--
-- Name: COLUMN asp_competition_type.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_competition_type.sport_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.sport_id IS '所属运动';


--
-- Name: COLUMN asp_competition_type.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.code IS '稳定类型编码';


--
-- Name: COLUMN asp_competition_type.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.name IS '比赛类型名称';


--
-- Name: COLUMN asp_competition_type.entry_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.entry_type IS '独立业务状态；合法值不等于业务已获批准：individual pair team';


--
-- Name: COLUMN asp_competition_type.min_members; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.min_members IS '最低参赛人数';


--
-- Name: COLUMN asp_competition_type.max_members; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.max_members IS '最高参赛人数';


--
-- Name: COLUMN asp_competition_type.capability_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.capability_status IS '独立业务状态；合法值不等于业务已获批准：catalog registration manual automatic verified';


--
-- Name: COLUMN asp_competition_type.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.status IS '独立业务状态；合法值不等于业务已获批准：active disabled';


--
-- Name: COLUMN asp_competition_type.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_competition_type.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_competition_type.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_competition_type.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_competition_type.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_competition_type.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_type.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_competition_unit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_competition_unit (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint NOT NULL,
    sport_id bigint NOT NULL,
    name character varying(200) NOT NULL,
    entry_type character varying(32) NOT NULL,
    min_members integer NOT NULL,
    max_members integer NOT NULL,
    birth_from date,
    birth_until date,
    age_reference_date date,
    status character varying(32) NOT NULL,
    current_rule_id bigint,
    current_fee_policy_id bigint,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    competition_type_id bigint,
    CONSTRAINT asp_competition_unit_check CHECK ((max_members >= min_members)),
    CONSTRAINT asp_competition_unit_check1 CHECK (((birth_until IS NULL) OR (birth_from IS NULL) OR (birth_until >= birth_from))),
    CONSTRAINT asp_competition_unit_entry_type_check CHECK (((entry_type)::text = ANY ((ARRAY['individual'::character varying, 'pair'::character varying, 'team'::character varying])::text[]))),
    CONSTRAINT asp_competition_unit_max_members_check CHECK ((max_members >= 0)),
    CONSTRAINT asp_competition_unit_min_members_check CHECK ((min_members > 0)),
    CONSTRAINT asp_competition_unit_min_members_check1 CHECK ((min_members >= 0)),
    CONSTRAINT asp_competition_unit_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'open'::character varying, 'suspended'::character varying, 'closed'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT asp_competition_unit_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_competition_unit_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_competition_unit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_competition_unit IS '报名坐标；运动、玩法、组别和参赛单位；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_competition_unit.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_competition_unit.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_competition_unit.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.event_id IS '赛事';


--
-- Name: COLUMN asp_competition_unit.sport_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.sport_id IS '运动及变体';


--
-- Name: COLUMN asp_competition_unit.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.name IS '项目组别名称';


--
-- Name: COLUMN asp_competition_unit.entry_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.entry_type IS '独立业务状态；合法值不等于业务已获批准：individual pair team';


--
-- Name: COLUMN asp_competition_unit.min_members; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.min_members IS '最低成员人数';


--
-- Name: COLUMN asp_competition_unit.max_members; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.max_members IS '最高名单人数';


--
-- Name: COLUMN asp_competition_unit.birth_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.birth_from IS '允许出生日期下界，含边界';


--
-- Name: COLUMN asp_competition_unit.birth_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.birth_until IS '允许出生日期上界，含边界';


--
-- Name: COLUMN asp_competition_unit.age_reference_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.age_reference_date IS '年龄规程基准日';


--
-- Name: COLUMN asp_competition_unit.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.status IS '独立业务状态；合法值不等于业务已获批准：draft open suspended closed cancelled';


--
-- Name: COLUMN asp_competition_unit.current_rule_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.current_rule_id IS '当前确认规则版本；应用核对单元归属';


--
-- Name: COLUMN asp_competition_unit.current_fee_policy_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.current_fee_policy_id IS '当前费用版本；应用核对归属';


--
-- Name: COLUMN asp_competition_unit.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_competition_unit.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_competition_unit.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_competition_unit.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_competition_unit.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_competition_unit.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_competition_unit.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_complaint; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_complaint (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    applicant_account_id bigint NOT NULL,
    object_type character varying(100) NOT NULL,
    object_id bigint NOT NULL,
    request character varying(2000) NOT NULL,
    evidence jsonb NOT NULL,
    status character varying(32) NOT NULL,
    owner_id bigint,
    resolution jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_complaint_status_check CHECK (((status)::text = ANY ((ARRAY['submitted'::character varying, 'accepted'::character varying, 'investigating'::character varying, 'resolved'::character varying, 'rejected'::character varying, 'appealed'::character varying])::text[]))),
    CONSTRAINT asp_complaint_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_complaint_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_complaint; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_complaint IS '平台投诉、反馈及分派；专业结果争议移交申诉；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_complaint.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_complaint.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_complaint.applicant_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.applicant_account_id IS '投诉人';


--
-- Name: COLUMN asp_complaint.object_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.object_type IS '组织/赛事/队伍/付款/资料';


--
-- Name: COLUMN asp_complaint.object_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.object_id IS '关联对象';


--
-- Name: COLUMN asp_complaint.request; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.request IS '诉求';


--
-- Name: COLUMN asp_complaint.evidence; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.evidence IS '最小披露证据；必须按版本校验结构';


--
-- Name: COLUMN asp_complaint.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.status IS '独立业务状态；合法值不等于业务已获批准：submitted accepted investigating resolved rejected appealed';


--
-- Name: COLUMN asp_complaint.owner_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.owner_id IS '处理责任人';


--
-- Name: COLUMN asp_complaint.resolution; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.resolution IS '处理及告知；必须按版本校验结构';


--
-- Name: COLUMN asp_complaint.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_complaint.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_complaint.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_complaint.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_complaint.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_complaint.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_complaint_message; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_complaint_message (
    id bigint NOT NULL,
    complaint_id bigint NOT NULL,
    actor_type character varying(32) NOT NULL,
    actor_id bigint NOT NULL,
    action character varying(32) NOT NULL,
    message character varying(2000) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_complaint_message_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_complaint_message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_complaint_message IS '投诉回复、处理与重新打开的追加记录；只向获授权当事方展示';


--
-- Name: COLUMN asp_complaint_message.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_complaint_message.complaint_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.complaint_id IS '投诉';


--
-- Name: COLUMN asp_complaint_message.actor_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.actor_type IS '本人、主办方或政府角色';


--
-- Name: COLUMN asp_complaint_message.actor_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.actor_id IS '处理主体';


--
-- Name: COLUMN asp_complaint_message.action; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.action IS '回复、转交、关闭或重开';


--
-- Name: COLUMN asp_complaint_message.message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.message IS '可见回复与处理依据';


--
-- Name: COLUMN asp_complaint_message.occurred_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.occurred_at IS '发生时间；有时区业务时间';


--
-- Name: COLUMN asp_complaint_message.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_complaint_message.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_complaint_message.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_complaint_message.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_complaint_message.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_complaint_message.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_complaint_message.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_conflict_case; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_conflict_case (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    trigger_type character varying(100) NOT NULL,
    trigger_id bigint NOT NULL,
    affected_refs jsonb NOT NULL,
    severity character varying(32) NOT NULL,
    status character varying(32) NOT NULL,
    resolution jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_conflict_case_severity_check CHECK (((severity)::text = ANY ((ARRAY['soft'::character varying, 'hard'::character varying])::text[]))),
    CONSTRAINT asp_conflict_case_status_check CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'coordinating'::character varying, 'resolved'::character varying, 'rejected'::character varying])::text[]))),
    CONSTRAINT asp_conflict_case_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_conflict_case_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_conflict_case; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_conflict_case IS '冲突发现与协调证据；通知已读不等于解决；来源：母版 D07；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_conflict_case.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_conflict_case.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_conflict_case.trigger_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.trigger_type IS '提交/换人/改期/编排等';


--
-- Name: COLUMN asp_conflict_case.trigger_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.trigger_id IS '触发业务 ID';


--
-- Name: COLUMN asp_conflict_case.affected_refs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.affected_refs IS '受影响来源及授权摘要；必须按版本校验结构';


--
-- Name: COLUMN asp_conflict_case.severity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.severity IS '独立业务状态；合法值不等于业务已获批准：soft hard';


--
-- Name: COLUMN asp_conflict_case.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.status IS '独立业务状态；合法值不等于业务已获批准：open coordinating resolved rejected';


--
-- Name: COLUMN asp_conflict_case.resolution; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.resolution IS '选择方案与授权依据；必须按版本校验结构';


--
-- Name: COLUMN asp_conflict_case.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_conflict_case.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_conflict_case.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_conflict_case.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_conflict_case.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_conflict_case.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_conflict_case.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_consent; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_consent (
    id bigint NOT NULL,
    person_id bigint NOT NULL,
    actor_account_id bigint NOT NULL,
    purpose character varying(100) NOT NULL,
    document_version character varying(100) NOT NULL,
    scope jsonb NOT NULL,
    accepted_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    evidence_hash character varying(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_consent_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_consent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_consent IS '具体行为的告知与同意证据；不以一个勾选代替所有用途；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_consent.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_consent.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.person_id IS '涉及参赛人';


--
-- Name: COLUMN asp_consent.actor_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.actor_account_id IS '本人或合法监护办理人';


--
-- Name: COLUMN asp_consent.purpose; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.purpose IS '明确处理用途';


--
-- Name: COLUMN asp_consent.document_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.document_version IS '告知材料版本';


--
-- Name: COLUMN asp_consent.scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.scope IS '行为和资料范围；必须按版本校验结构';


--
-- Name: COLUMN asp_consent.accepted_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.accepted_at IS '确认时间；有时区业务时间';


--
-- Name: COLUMN asp_consent.revoked_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.revoked_at IS '撤回时间；有时区业务时间';


--
-- Name: COLUMN asp_consent.evidence_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.evidence_hash IS '确认内容摘要';


--
-- Name: COLUMN asp_consent.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_consent.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_consent.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_consent.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_consent.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_consent.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_consent.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_data_request; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_data_request (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    person_id bigint NOT NULL,
    request_type character varying(100) NOT NULL,
    scope jsonb NOT NULL,
    status character varying(32) NOT NULL,
    resolution jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_data_request_status_check CHECK (((status)::text = ANY ((ARRAY['submitted'::character varying, 'verifying'::character varying, 'approved'::character varying, 'rejected'::character varying, 'processing'::character varying, 'completed'::character varying])::text[]))),
    CONSTRAINT asp_data_request_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_data_request; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_data_request IS '个人资料查询、更正、撤回、注销及删除请求；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_data_request.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_data_request.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.account_id IS '请求人';


--
-- Name: COLUMN asp_data_request.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.person_id IS '资料对象';


--
-- Name: COLUMN asp_data_request.request_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.request_type IS '明确权利请求类型';


--
-- Name: COLUMN asp_data_request.scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.scope IS '范围和授权；必须按版本校验结构';


--
-- Name: COLUMN asp_data_request.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.status IS '独立业务状态；合法值不等于业务已获批准：submitted verifying approved rejected processing completed';


--
-- Name: COLUMN asp_data_request.resolution; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.resolution IS '公开下架、必要留存及未完义务接续；必须按版本校验结构';


--
-- Name: COLUMN asp_data_request.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_data_request.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_data_request.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_data_request.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_data_request.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_data_request.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_data_request.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_declaration_ack; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_declaration_ack (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    registration_member_id bigint NOT NULL,
    account_id bigint NOT NULL,
    event_id bigint NOT NULL,
    content_digest character varying(64) NOT NULL,
    acknowledged_at timestamp with time zone NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_declaration_ack_content_digest_check CHECK ((length((content_digest)::text) = 64)),
    CONSTRAINT asp_declaration_ack_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_declaration_ack_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_declaration_ack; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_declaration_ack IS '成员本人对当时参赛声明的点击确认。队长不能代确认；来源V026';


--
-- Name: COLUMN asp_declaration_ack.content_digest; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_declaration_ack.content_digest IS '确认时声明文字和文件的摘要。声明变化后需重新确认';


--
-- Name: COLUMN asp_declaration_ack.acknowledged_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_declaration_ack.acknowledged_at IS '本人点击确认的时间';


--
-- Name: asp_draw_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_draw_run (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    stage_id bigint NOT NULL,
    rule_version_id bigint NOT NULL,
    revision integer NOT NULL,
    input_snapshot jsonb NOT NULL,
    random_seed character varying(200) NOT NULL,
    output_snapshot jsonb NOT NULL,
    status character varying(32) NOT NULL,
    reason character varying(1000) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_draw_run_revision_check CHECK ((revision >= 0)),
    CONSTRAINT asp_draw_run_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'confirmed'::character varying, 'superseded'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT asp_draw_run_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_draw_run_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_draw_run; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_draw_run IS '抽签运行与可复核输入；不反复随机选择有利结果；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_draw_run.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_draw_run.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_draw_run.stage_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.stage_id IS '阶段';


--
-- Name: COLUMN asp_draw_run.rule_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.rule_version_id IS '规则版本';


--
-- Name: COLUMN asp_draw_run.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.revision IS '抽签版本';


--
-- Name: COLUMN asp_draw_run.input_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.input_snapshot IS '有效名单版本、种子、轮空与回避依据；必须按版本校验结构';


--
-- Name: COLUMN asp_draw_run.random_seed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.random_seed IS '复核随机来源及种子';


--
-- Name: COLUMN asp_draw_run.output_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.output_snapshot IS '签位及约束检查；必须按版本校验结构';


--
-- Name: COLUMN asp_draw_run.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.status IS '独立业务状态；合法值不等于业务已获批准：draft confirmed superseded failed';


--
-- Name: COLUMN asp_draw_run.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.reason IS '运行或重抽依据';


--
-- Name: COLUMN asp_draw_run.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_draw_run.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_draw_run.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_draw_run.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_draw_run.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_draw_run.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_draw_run.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_entry_field_value; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_entry_field_value (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    registration_member_id bigint NOT NULL,
    event_field_id bigint NOT NULL,
    value_text character varying(1000) NOT NULL,
    label_snapshot character varying(100) NOT NULL,
    type_snapshot character varying(16) NOT NULL,
    options_snapshot jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_entry_field_value_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_entry_field_value_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_entry_field_value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_entry_field_value IS '报名成员对赛事字段的填写。提交时保留当时的名称、类型和选项；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_entry_field_value.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_entry_field_value.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_entry_field_value.registration_member_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.registration_member_id IS '填写人';


--
-- Name: COLUMN asp_entry_field_value.event_field_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.event_field_id IS '当时选用的字段';


--
-- Name: COLUMN asp_entry_field_value.value_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.value_text IS '填写值';


--
-- Name: COLUMN asp_entry_field_value.label_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.label_snapshot IS '提交时的字段名称';


--
-- Name: COLUMN asp_entry_field_value.type_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.type_snapshot IS '提交时的类型';


--
-- Name: COLUMN asp_entry_field_value.options_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.options_snapshot IS '提交时的枚举选项；必须按版本校验结构';


--
-- Name: COLUMN asp_entry_field_value.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_entry_field_value.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_entry_field_value.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_entry_field_value.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_entry_field_value.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_entry_field_value.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_entry_field_value.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_event (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    organization_id bigint NOT NULL,
    name character varying(200),
    series_id bigint,
    starts_at timestamp with time zone,
    ends_at timestamp with time zone,
    registration_opens_at timestamp with time zone,
    registration_closes_at timestamp with time zone,
    status character varying(32) NOT NULL,
    registration_status character varying(32) NOT NULL,
    payment_status character varying(32) NOT NULL,
    visibility character varying(32) NOT NULL,
    published_revision integer NOT NULL,
    contact_snapshot jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    location character varying(200),
    project_name character varying(200),
    fee_description character varying(1000),
    cancel_reason character varying(1000),
    sport_code character varying(32) DEFAULT 'badminton'::character varying NOT NULL,
    publication_status character varying(32) DEFAULT 'draft'::character varying NOT NULL,
    holding_status character varying(32) DEFAULT 'normal'::character varying NOT NULL,
    registration_review character varying(16) DEFAULT 'manual'::character varying NOT NULL,
    registration_review_locked boolean DEFAULT false NOT NULL,
    banner_file_id bigint,
    rules_text character varying(4000),
    rules_file_id bigint,
    notice_text character varying(4000),
    notice_file_id bigint,
    declaration_text character varying(4000),
    declaration_file_id bigint,
    route_text character varying(4000),
    route_file_id bigint,
    declaration_ack_required boolean DEFAULT false NOT NULL,
    closure_status character varying(32) DEFAULT 'open'::character varying NOT NULL,
    operations_materials jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT asp_event_check CHECK (((ends_at IS NULL) OR (starts_at IS NULL) OR (ends_at > starts_at))),
    CONSTRAINT asp_event_check1 CHECK (((registration_closes_at IS NULL) OR (registration_opens_at IS NULL) OR (registration_closes_at > registration_opens_at))),
    CONSTRAINT asp_event_closure_status_check CHECK (((closure_status)::text = ANY ((ARRAY['open'::character varying, 'wrap_up'::character varying, 'closed'::character varying])::text[]))),
    CONSTRAINT asp_event_operations_materials_object CHECK ((jsonb_typeof(operations_materials) = 'object'::text)),
    CONSTRAINT asp_event_payment_status_check CHECK (((payment_status)::text = ANY ((ARRAY['disabled'::character varying, 'enabled'::character varying, 'suspended'::character varying])::text[]))),
    CONSTRAINT asp_event_published_revision_check CHECK ((published_revision >= 0)),
    CONSTRAINT asp_event_registration_status_check CHECK (((registration_status)::text = ANY ((ARRAY['closed'::character varying, 'scheduled'::character varying, 'open'::character varying, 'suspended'::character varying, 'ended'::character varying])::text[]))),
    CONSTRAINT asp_event_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'pending'::character varying, 'published'::character varying, 'postponed'::character varying, 'cancelled'::character varying, 'completed'::character varying, 'archived'::character varying])::text[]))),
    CONSTRAINT asp_event_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_event_version_check CHECK ((version >= 0)),
    CONSTRAINT asp_event_visibility_check CHECK (((visibility)::text = ANY ((ARRAY['private'::character varying, 'public'::character varying])::text[]))),
    CONSTRAINT ck_asp_event_holding_status CHECK (((holding_status)::text = ANY ((ARRAY['normal'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT ck_asp_event_publication_status CHECK (((publication_status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'offline'::character varying])::text[]))),
    CONSTRAINT ck_asp_event_registration_before_start CHECK (((registration_closes_at IS NULL) OR (starts_at IS NULL) OR (registration_closes_at <= starts_at))),
    CONSTRAINT ck_asp_event_registration_review CHECK (((registration_review)::text = ANY ((ARRAY['manual'::character varying, 'none'::character varying])::text[]))),
    CONSTRAINT ck_asp_event_sport_code CHECK (((sport_code)::text = 'badminton'::text))
);


--
-- Name: TABLE asp_event; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_event IS '赛事容器。M1.3 的发布和举办状态分开，时间阶段按北京时间计算';


--
-- Name: COLUMN asp_event.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_event.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_event.organization_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.organization_id IS '主责组织';


--
-- Name: COLUMN asp_event.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.name IS '赛事名称。草稿可空，发布时必填';


--
-- Name: COLUMN asp_event.series_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.series_id IS '系列/联赛业务关联；后续系列服务核验';


--
-- Name: COLUMN asp_event.starts_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.starts_at IS '赛事总窗口开始；有时区业务时间';


--
-- Name: COLUMN asp_event.ends_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.ends_at IS '赛事总窗口结束；有时区业务时间';


--
-- Name: COLUMN asp_event.registration_opens_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.registration_opens_at IS '报名开始。报名是否接受以报名流程为准，时间记在赛事上';


--
-- Name: COLUMN asp_event.registration_closes_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.registration_closes_at IS '报名结束。报名是否接受以报名流程为准，时间记在赛事上';


--
-- Name: COLUMN asp_event.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.status IS '独立业务状态；合法值不等于业务已获批准：draft pending published postponed cancelled completed archived';


--
-- Name: COLUMN asp_event.registration_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.registration_status IS '独立业务状态；合法值不等于业务已获批准：closed scheduled open suspended ended';


--
-- Name: COLUMN asp_event.payment_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.payment_status IS '独立业务状态；合法值不等于业务已获批准：disabled enabled suspended';


--
-- Name: COLUMN asp_event.visibility; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.visibility IS '旧可见性列。M1.3 公开与否不看它';


--
-- Name: COLUMN asp_event.published_revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.published_revision IS '当前发布版本；0 为未发布';


--
-- Name: COLUMN asp_event.contact_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.contact_snapshot IS '履约联系及外部准入状态；必须按版本校验结构';


--
-- Name: COLUMN asp_event.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_event.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_event.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_event.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_event.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_event.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_event.location; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.location IS '比赛地点。公开文字，不引用场馆';


--
-- Name: COLUMN asp_event.project_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.project_name IS '赛事项目。公开文字，不建竞赛单元';


--
-- Name: COLUMN asp_event.fee_description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.fee_description IS '收费方式或收费说明。公开文字，不产生付款';


--
-- Name: COLUMN asp_event.cancel_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.cancel_reason IS '取消原因。可空，有内容时出现在公开详情';


--
-- Name: COLUMN asp_event.sport_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.sport_code IS '运动编码。本期只能是 badminton';


--
-- Name: COLUMN asp_event.publication_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.publication_status IS '发布状态：draft published offline。已发布不能直接改公开信息';


--
-- Name: COLUMN asp_event.holding_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.holding_status IS '举办状态：normal cancelled。取消不等于下架，已结束不能取消';


--
-- Name: COLUMN asp_event.registration_review; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.registration_review IS '报名资格审核：manual 人工审核，none 无需审核。与赛事发布审批无关';


--
-- Name: COLUMN asp_event.registration_review_locked; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.registration_review_locked IS '首笔正式提交后锁定审核方式。全部撤回也不解锁';


--
-- Name: COLUMN asp_event.banner_file_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.banner_file_id IS '宣传图文件编号。可空，不建外键';


--
-- Name: COLUMN asp_event.rules_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.rules_text IS '竞赛规程文字。可与图片同时存在';


--
-- Name: COLUMN asp_event.rules_file_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.rules_file_id IS '竞赛规程图片文件编号。可空，不建外键';


--
-- Name: COLUMN asp_event.notice_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.notice_text IS '报名须知文字。可与图片同时存在';


--
-- Name: COLUMN asp_event.notice_file_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.notice_file_id IS '报名须知图片文件编号。可空，不建外键';


--
-- Name: COLUMN asp_event.declaration_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.declaration_text IS '参赛声明文字。可与图片同时存在';


--
-- Name: COLUMN asp_event.declaration_file_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.declaration_file_id IS '参赛声明图片文件编号。可空，不建外键';


--
-- Name: COLUMN asp_event.route_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.route_text IS '比赛地点或路线说明。地图嵌入不在本期';


--
-- Name: COLUMN asp_event.route_file_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.route_file_id IS '比赛地点或路线图片文件编号。可空，不建外键';


--
-- Name: COLUMN asp_event.declaration_ack_required; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.declaration_ack_required IS '参赛声明是否必须由成员本人点击确认。不是证件核验，也不是电子签章；来源V026';


--
-- Name: COLUMN asp_event.operations_materials; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event.operations_materials IS 'Private plan/script/announcement/promotion drafts; independent revisions, actual origin and up to ten prior revisions; no automatic external publication';


--
-- Name: asp_event_command; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_event_command (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint NOT NULL,
    action character varying(32) NOT NULL,
    request_key character varying(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_event_command_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_event_command_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_event_command; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_event_command IS '赛事写操作幂等。同一租户、同一动作、同一请求键只生效一次';


--
-- Name: COLUMN asp_event_command.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_command.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_event_command.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_command.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_event_command.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_command.event_id IS '已经处理过的赛事';


--
-- Name: COLUMN asp_event_command.action; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_command.action IS '动作。本期只有 publish';


--
-- Name: COLUMN asp_event_command.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_command.request_key IS '客户端幂等键';


--
-- Name: COLUMN asp_event_command.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_command.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_event_command.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_command.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_event_command.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_command.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_event_command.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_command.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_event_command.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_command.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_event_command.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_command.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_event_field; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_event_field (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint NOT NULL,
    org_field_id bigint NOT NULL,
    required boolean DEFAULT false NOT NULL,
    sort_order integer NOT NULL,
    note character varying(500),
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_event_field_sort_order_check CHECK ((sort_order >= 0)),
    CONSTRAINT asp_event_field_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_event_field_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_event_field; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_event_field IS '一场赛事选用的组织字段。一期全赛事同一套，首笔正式提交后不再改；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_event_field.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_event_field.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_event_field.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.event_id IS '赛事';


--
-- Name: COLUMN asp_event_field.org_field_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.org_field_id IS '组织字段';


--
-- Name: COLUMN asp_event_field.required; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.required IS 'true 为本人必须填写';


--
-- Name: COLUMN asp_event_field.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.sort_order IS '显示顺序';


--
-- Name: COLUMN asp_event_field.note; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.note IS '给参赛者的说明';


--
-- Name: COLUMN asp_event_field.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_event_field.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_event_field.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_event_field.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_event_field.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_event_field.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_field.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_event_payment_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_event_payment_config (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint NOT NULL,
    settings jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_event_payment_config_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_event_payment_config_version_check CHECK ((version >= 0)),
    CONSTRAINT asp_event_payment_settings_contract_check CHECK (((jsonb_typeof(settings) = 'object'::text) AND (settings ? 'schemaVersion'::text) AND ((settings ->> 'schemaVersion'::text) = '1'::text) AND (settings ? 'channels'::text) AND (jsonb_typeof((settings -> 'channels'::text)) = 'array'::text)))
);


--
-- Name: TABLE asp_event_payment_config; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_event_payment_config IS '赛事统一收款指引，承办方资金授权维护；首次正式提交后锁定。金额仍按项目，指引不是到账；来源：母版 D06；资金授权、文件用途及租户校验、渠道结构及必填、与首笔正式提交串行；提交时指引及二维码文件编号复制到义务快照，旧版收费仍按原版本读取。';


--
-- Name: COLUMN asp_event_payment_config.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_payment_config.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_event_payment_config.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_payment_config.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_event_payment_config.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_payment_config.event_id IS '所属赛事；同租户唯一，应用校验组织归属';


--
-- Name: COLUMN asp_event_payment_config.settings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_payment_config.settings IS 'v1含channels及instruction；wechat/alipay/custom_qr引用payment-qr文件，bank含受保护账户，offline含办理指引。不得公开或发送模型；必须按版本校验结构';


--
-- Name: COLUMN asp_event_payment_config.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_payment_config.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_event_payment_config.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_payment_config.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_event_payment_config.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_payment_config.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_event_payment_config.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_payment_config.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_event_payment_config.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_payment_config.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_event_payment_config.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_payment_config.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_event_poster; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_event_poster (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint NOT NULL,
    channel_name character varying(40) NOT NULL,
    format character varying(32) NOT NULL,
    source_code character varying(16) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    copy_headline character varying(80) DEFAULT ''::character varying NOT NULL,
    copy_invitation character varying(300) DEFAULT ''::character varying NOT NULL,
    copy_body character varying(2000) DEFAULT ''::character varying NOT NULL,
    fact_digest character varying(64) DEFAULT ''::character varying NOT NULL,
    link_path character varying(240) DEFAULT ''::character varying NOT NULL,
    visual_file_id bigint,
    visual_subject_digest character varying(64) DEFAULT ''::character varying NOT NULL,
    visual_request_digest character varying(64) DEFAULT ''::character varying NOT NULL,
    visual_style character varying(24) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT asp_event_poster_format_check CHECK (((format)::text = ANY ((ARRAY['wechat_group'::character varying, 'moments'::character varying, 'a4'::character varying])::text[]))),
    CONSTRAINT asp_event_poster_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_event_poster_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_event_poster_visual_style CHECK (((visual_style)::text = ANY ((ARRAY[''::character varying, 'competitive'::character varying, 'junior'::character varying, 'community'::character varying])::text[])))
);


--
-- Name: TABLE asp_event_poster; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_event_poster IS '已发布赛事的一份宣传资料。来源编号只汇总打开次数，不关联账号；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_event_poster.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_event_poster.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_event_poster.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.event_id IS '赛事';


--
-- Name: COLUMN asp_event_poster.channel_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.channel_name IS '承办方填写的渠道名称';


--
-- Name: COLUMN asp_event_poster.format; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.format IS '资料版式：wechat_group moments a4';


--
-- Name: COLUMN asp_event_poster.source_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.source_code IS '公开链接上的来源编号。不包含个人信息';


--
-- Name: COLUMN asp_event_poster.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_event_poster.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_event_poster.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_event_poster.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_event_poster.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_event_poster.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_event_poster.copy_headline; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.copy_headline IS '模型写的标题。金额和日期由页面按赛事事实另画';


--
-- Name: COLUMN asp_event_poster.copy_invitation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.copy_invitation IS '模型写的邀请句';


--
-- Name: COLUMN asp_event_poster.copy_body; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.copy_body IS '群消息正文或朋友圈短句。海报行可为空';


--
-- Name: COLUMN asp_event_poster.fact_digest; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.fact_digest IS '生成时的赛事事实摘要。对不上当前赛事则材料过期';


--
-- Name: COLUMN asp_event_poster.link_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.link_path IS '已发布时的公开路径，含来源编号。未发布为空';


--
-- Name: COLUMN asp_event_poster.visual_file_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.visual_file_id IS '模型生成的无字宣传主视觉，复用event-banner图片用途及组织隔离，不替换赛事封面；来源V025';


--
-- Name: COLUMN asp_event_poster.visual_subject_digest; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.visual_subject_digest IS '生成时名称与运动项目摘要，变化后主视觉不可复用；来源V025';


--
-- Name: COLUMN asp_event_poster.visual_request_digest; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.visual_request_digest IS '名称项目受众关键词风格摘要，相同请求复用不重复生图；来源V025';


--
-- Name: COLUMN asp_event_poster.visual_style; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster.visual_style IS '主视觉风格competitive junior community，未生成为空；来源V025';


--
-- Name: asp_event_poster_stat; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_event_poster_stat (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    poster_id bigint NOT NULL,
    stat_date date NOT NULL,
    hit_count integer NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_event_poster_stat_hit_count_check CHECK ((hit_count >= 0)),
    CONSTRAINT asp_event_poster_stat_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_event_poster_stat_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_event_poster_stat; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_event_poster_stat IS '宣传资料按日打开次数。不记录账号、地址或浏览器标识；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_event_poster_stat.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster_stat.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_event_poster_stat.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster_stat.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_event_poster_stat.poster_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster_stat.poster_id IS '宣传资料';


--
-- Name: COLUMN asp_event_poster_stat.stat_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster_stat.stat_date IS '统计日。按上海时区的日期累计';


--
-- Name: COLUMN asp_event_poster_stat.hit_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster_stat.hit_count IS '当日打开次数';


--
-- Name: COLUMN asp_event_poster_stat.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster_stat.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_event_poster_stat.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster_stat.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_event_poster_stat.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster_stat.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_event_poster_stat.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster_stat.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_event_poster_stat.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster_stat.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_event_poster_stat.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_poster_stat.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_event_revision; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_event_revision (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint NOT NULL,
    revision integer NOT NULL,
    snapshot jsonb NOT NULL,
    reason character varying(1000) NOT NULL,
    published_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_event_revision_revision_check CHECK ((revision > 0)),
    CONSTRAINT asp_event_revision_revision_check1 CHECK ((revision >= 0)),
    CONSTRAINT asp_event_revision_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_event_revision_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_event_revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_event_revision IS '赛事对外承诺版本和重大变更说明；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_event_revision.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_event_revision.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_event_revision.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.event_id IS '赛事';


--
-- Name: COLUMN asp_event_revision.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.revision IS '发布版本';


--
-- Name: COLUMN asp_event_revision.snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.snapshot IS '结构、规程、责任、资源与费用公开快照；必须按版本校验结构';


--
-- Name: COLUMN asp_event_revision.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.reason IS '变更依据';


--
-- Name: COLUMN asp_event_revision.published_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.published_at IS '发布生效；有时区业务时间';


--
-- Name: COLUMN asp_event_revision.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_event_revision.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_event_revision.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_event_revision.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_event_revision.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_event_revision.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_event_revision.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_execution_command; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_execution_command (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    action character varying(32) NOT NULL,
    request_key character varying(128) NOT NULL,
    payload_hash character varying(64) NOT NULL,
    subject_type character varying(32) NOT NULL,
    subject_id bigint NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_execution_command_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_execution_command_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_execution_command; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_execution_command IS '报到、录分和发奖的请求幂等。不替代赛事一个人一次报到，也不替代一场一条结果';


--
-- Name: COLUMN asp_execution_command.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_execution_command.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_execution_command.action; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.action IS '动作。checkin match result result_finalize result_import award';


--
-- Name: COLUMN asp_execution_command.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.request_key IS '客户端幂等键';


--
-- Name: COLUMN asp_execution_command.payload_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.payload_hash IS '请求内容摘要。相同键不同摘要视为冲突';


--
-- Name: COLUMN asp_execution_command.subject_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.subject_type IS '指向的事实类型';


--
-- Name: COLUMN asp_execution_command.subject_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.subject_id IS '已经生效的业务事实编号';


--
-- Name: COLUMN asp_execution_command.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_execution_command.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_execution_command.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_execution_command.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_execution_command.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_execution_command.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_execution_command.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_fee_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_fee_item (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    obligation_id bigint NOT NULL,
    person_id bigint,
    service_code character varying(100) NOT NULL,
    quantity numeric(12,4) NOT NULL,
    unit character varying(100) NOT NULL,
    unit_price numeric(18,2) NOT NULL,
    discount_amount numeric(18,2) NOT NULL,
    amount numeric(18,2) NOT NULL,
    basis jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_fee_item_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT asp_fee_item_discount_amount_check CHECK ((discount_amount >= (0)::numeric)),
    CONSTRAINT asp_fee_item_quantity_check CHECK ((quantity > (0)::numeric)),
    CONSTRAINT asp_fee_item_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_fee_item_unit_price_check CHECK ((unit_price >= (0)::numeric)),
    CONSTRAINT asp_fee_item_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_fee_item; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_fee_item IS '应收服务、选手及项目明细；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_fee_item.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_fee_item.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_fee_item.obligation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.obligation_id IS '义务';


--
-- Name: COLUMN asp_fee_item.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.person_id IS '按人计价对应选手';


--
-- Name: COLUMN asp_fee_item.service_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.service_code IS '收费项目';


--
-- Name: COLUMN asp_fee_item.quantity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.quantity IS '数量与计价单位';


--
-- Name: COLUMN asp_fee_item.unit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.unit IS '计价单位';


--
-- Name: COLUMN asp_fee_item.unit_price; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.unit_price IS '单价；人民币元，不能用浮点';


--
-- Name: COLUMN asp_fee_item.discount_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.discount_amount IS '优惠；人民币元，不能用浮点';


--
-- Name: COLUMN asp_fee_item.amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.amount IS '最终明细金额；人民币元，不能用浮点';


--
-- Name: COLUMN asp_fee_item.basis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.basis IS '计价顺序与优惠依据；必须按版本校验结构';


--
-- Name: COLUMN asp_fee_item.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_fee_item.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_fee_item.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_fee_item.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_fee_item.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_fee_item.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_item.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_fee_obligation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_fee_obligation (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    registration_id bigint NOT NULL,
    fee_policy_id bigint NOT NULL,
    total_amount numeric(18,2) NOT NULL,
    currency character varying(3) NOT NULL,
    status character varying(32) NOT NULL,
    quote_snapshot jsonb NOT NULL,
    request_key character varying(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    declared_at timestamp with time zone,
    CONSTRAINT asp_fee_obligation_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_fee_obligation_total_amount_check CHECK ((total_amount >= (0)::numeric)),
    CONSTRAINT asp_fee_obligation_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_asp_fee_obligation_status CHECK (((status)::text = ANY ((ARRAY['not_required'::character varying, 'open'::character varying, 'settled'::character varying, 'void'::character varying])::text[])))
);


--
-- Name: TABLE asp_fee_obligation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_fee_obligation IS '确认应收义务；免费赛事无需虚构到账；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_fee_obligation.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_fee_obligation.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_fee_obligation.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.registration_id IS '报名';


--
-- Name: COLUMN asp_fee_obligation.fee_policy_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.fee_policy_id IS '费用版本';


--
-- Name: COLUMN asp_fee_obligation.total_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.total_amount IS '确认总额；人民币元，不能用浮点';


--
-- Name: COLUMN asp_fee_obligation.currency; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.currency IS '币种 CNY；其他币种需另行确认';


--
-- Name: COLUMN asp_fee_obligation.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.status IS 'not_required open settled void';


--
-- Name: COLUMN asp_fee_obligation.quote_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.quote_snapshot IS '当次提交的整单金额、方式和说明；统一收款含paymentSettings渠道及二维码文件编号快照，账户仅授权付款用途可见，不随配置改变；必须按版本校验结构';


--
-- Name: COLUMN asp_fee_obligation.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.request_key IS '义务幂等键。不复用报名请求键';


--
-- Name: COLUMN asp_fee_obligation.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_fee_obligation.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_fee_obligation.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_fee_obligation.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_fee_obligation.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_fee_obligation.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_fee_obligation.declared_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_obligation.declared_at IS '参赛者点击模拟付款完成的时间。不是到账确认；有时区业务时间';


--
-- Name: asp_fee_policy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_fee_policy (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    unit_id bigint NOT NULL,
    revision integer NOT NULL,
    pricing_unit character varying(32) NOT NULL,
    pricing_rules jsonb NOT NULL,
    payer_modes jsonb NOT NULL,
    collection_paths jsonb NOT NULL,
    refund_terms jsonb NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    amount numeric(18,2),
    payment_mode character varying(32),
    pay_instruction character varying(1000),
    qr_file_id bigint,
    CONSTRAINT asp_fee_policy_payment_mode_allowed_check CHECK (((payment_mode IS NULL) OR ((payment_mode)::text = ANY ((ARRAY['free'::character varying, 'offline'::character varying, 'organizer_qr'::character varying, 'event'::character varying])::text[])))),
    CONSTRAINT asp_fee_policy_revision_check CHECK ((revision > 0)),
    CONSTRAINT asp_fee_policy_revision_check1 CHECK ((revision >= 0)),
    CONSTRAINT asp_fee_policy_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_fee_policy_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_asp_fee_policy_active CHECK ((((status)::text <> 'active'::text) OR ((amount IS NOT NULL) AND (payment_mode IS NOT NULL) AND ((((payment_mode)::text = 'free'::text) AND (amount = (0)::numeric)) OR (((payment_mode)::text <> 'free'::text) AND (amount > (0)::numeric)))))),
    CONSTRAINT ck_asp_fee_policy_amount CHECK (((amount IS NULL) OR (amount >= (0)::numeric))),
    CONSTRAINT ck_asp_fee_policy_pricing_unit CHECK (((pricing_unit)::text = ANY ((ARRAY['free'::character varying, 'person'::character varying, 'pair'::character varying, 'team'::character varying, 'project'::character varying, 'combination'::character varying, 'entry'::character varying])::text[]))),
    CONSTRAINT ck_asp_fee_policy_status CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying, 'retired'::character varying])::text[])))
);


--
-- Name: TABLE asp_fee_policy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_fee_policy IS '赛事费用条款版本；路径、计价、承担方式相互独立；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_fee_policy.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_fee_policy.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_fee_policy.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.unit_id IS '适用单元';


--
-- Name: COLUMN asp_fee_policy.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.revision IS '费用版本';


--
-- Name: COLUMN asp_fee_policy.pricing_unit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.pricing_unit IS '独立业务状态；合法值不等于业务已获批准：free person pair team project combination';


--
-- Name: COLUMN asp_fee_policy.pricing_rules; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.pricing_rules IS '已确认计价和优惠顺序；必须按版本校验结构';


--
-- Name: COLUMN asp_fee_policy.payer_modes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.payer_modes IS '统一/成员/代付/混合允许范围；必须按版本校验结构';


--
-- Name: COLUMN asp_fee_policy.collection_paths; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.collection_paths IS '实际接收主体、二维码/线下/可信渠道及准入；必须按版本校验结构';


--
-- Name: COLUMN asp_fee_policy.refund_terms; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.refund_terms IS '退赛、部分失败、取消、服务费及渠道费责任；必须按版本校验结构';


--
-- Name: COLUMN asp_fee_policy.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.status IS 'draft active retired';


--
-- Name: COLUMN asp_fee_policy.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_fee_policy.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_fee_policy.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_fee_policy.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_fee_policy.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_fee_policy.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_fee_policy.amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.amount IS '整单固定金额。免费为 0。草稿可空';


--
-- Name: COLUMN asp_fee_policy.payment_mode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.payment_mode IS 'free免费；event赛事统一渠道；offline/organizer_qr保留旧收费及历史付款依据。草稿可空';


--
-- Name: COLUMN asp_fee_policy.pay_instruction; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.pay_instruction IS '线下说明或收款二维码说明';


--
-- Name: COLUMN asp_fee_policy.qr_file_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_policy.qr_file_id IS '承办方收款二维码文件编号。可空，不建外键';


--
-- Name: asp_fee_share; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_fee_share (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    obligation_id bigint NOT NULL,
    account_id bigint NOT NULL,
    person_id bigint,
    amount numeric(18,2) NOT NULL,
    status character varying(32) NOT NULL,
    accepted_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_fee_share_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT asp_fee_share_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT asp_fee_share_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_fee_share_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_fee_share; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_fee_share IS '经确认的承担者及代付范围；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_fee_share.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_fee_share.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_fee_share.obligation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.obligation_id IS '费用义务';


--
-- Name: COLUMN asp_fee_share.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.account_id IS '承担账号';


--
-- Name: COLUMN asp_fee_share.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.person_id IS '对应选手';


--
-- Name: COLUMN asp_fee_share.amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.amount IS '承担金额；人民币元，不能用浮点';


--
-- Name: COLUMN asp_fee_share.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.status IS '独立业务状态；合法值不等于业务已获批准：pending accepted cancelled';


--
-- Name: COLUMN asp_fee_share.accepted_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.accepted_at IS '分担确认；有时区业务时间';


--
-- Name: COLUMN asp_fee_share.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_fee_share.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_fee_share.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_fee_share.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_fee_share.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_fee_share.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_fee_share.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_file; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_file (
    id bigint NOT NULL,
    owner_account_id bigint NOT NULL,
    owning_tenant_id character varying(20),
    object_key character varying(500) NOT NULL,
    sha256 character varying(64) NOT NULL,
    purpose character varying(200) NOT NULL,
    sensitivity character varying(32) NOT NULL,
    retain_until timestamp with time zone,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_file_sensitivity_check CHECK (((sensitivity)::text = ANY ((ARRAY['public'::character varying, 'ordinary'::character varying, 'identity'::character varying, 'guardian'::character varying, 'health'::character varying, 'finance'::character varying, 'result'::character varying])::text[]))),
    CONSTRAINT asp_file_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'restricted'::character varying, 'expired'::character varying, 'deleted'::character varying])::text[]))),
    CONSTRAINT asp_file_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_file; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_file IS '共享文件元数据；无永久公开凭据，访问由用途授权；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_file.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_file.owner_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.owner_account_id IS '上传及权利主体';


--
-- Name: COLUMN asp_file.owning_tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.owning_tenant_id IS '组织资料归属租户；个人资料可为空';


--
-- Name: COLUMN asp_file.object_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.object_key IS '存储键；不能直接形成无鉴权 URL';


--
-- Name: COLUMN asp_file.sha256; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.sha256 IS '内容摘要';


--
-- Name: COLUMN asp_file.purpose; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.purpose IS '必要用途';


--
-- Name: COLUMN asp_file.sensitivity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.sensitivity IS '独立业务状态；合法值不等于业务已获批准：public ordinary identity guardian health finance result';


--
-- Name: COLUMN asp_file.retain_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.retain_until IS '保留政策截止；有时区业务时间';


--
-- Name: COLUMN asp_file.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.status IS '独立业务状态；合法值不等于业务已获批准：active restricted expired deleted';


--
-- Name: COLUMN asp_file.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_file.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_file.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_file.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_file.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_file.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_file.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_governance_grant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_governance_grant (
    id bigint NOT NULL,
    sys_user_id bigint NOT NULL,
    organization_id bigint NOT NULL,
    permissions jsonb NOT NULL,
    status character varying(32) NOT NULL,
    valid_until timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_governance_grant_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT asp_governance_grant_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_governance_grant; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_governance_grant IS '政府后台账号对指定主办方的管理范围；不能由模型或普通经办人自授';


--
-- Name: COLUMN asp_governance_grant.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_governance_grant.sys_user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.sys_user_id IS '政府若依用户编号';


--
-- Name: COLUMN asp_governance_grant.organization_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.organization_id IS '指定主办方';


--
-- Name: COLUMN asp_governance_grant.permissions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.permissions IS '准入、资格管理、汇总和投诉权限；必须按版本校验结构';


--
-- Name: COLUMN asp_governance_grant.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.status IS '独立业务状态；合法值不等于业务已获批准：active revoked';


--
-- Name: COLUMN asp_governance_grant.valid_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.valid_until IS '授权截止；有时区业务时间';


--
-- Name: COLUMN asp_governance_grant.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_governance_grant.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_governance_grant.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_governance_grant.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_governance_grant.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_governance_grant.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_governance_grant.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_growth_policy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_growth_policy (
    id bigint NOT NULL,
    sport_id bigint NOT NULL,
    code character varying(64) NOT NULL,
    revision integer NOT NULL,
    rules jsonb NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_growth_policy_revision_check CHECK ((revision >= 0)),
    CONSTRAINT asp_growth_policy_revision_check1 CHECK ((revision > 0)),
    CONSTRAINT asp_growth_policy_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying, 'superseded'::character varying])::text[]))),
    CONSTRAINT asp_growth_policy_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_growth_policy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_growth_policy IS '版本化成长规则；段位不是官方竞技实力评级';


--
-- Name: COLUMN asp_growth_policy.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_growth_policy.sport_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.sport_id IS '所属运动';


--
-- Name: COLUMN asp_growth_policy.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.code IS '规则编码';


--
-- Name: COLUMN asp_growth_policy.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.revision IS '规则版本';


--
-- Name: COLUMN asp_growth_policy.rules; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.rules IS '版本化段位门槛、奖励及称号阈值；兼容历史七、八级及当前九级；新星基础级，王者9600、传奇19200为默认门槛，可另发版本调整';


--
-- Name: COLUMN asp_growth_policy.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.status IS '独立业务状态；合法值不等于业务已获批准：draft active superseded';


--
-- Name: COLUMN asp_growth_policy.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_growth_policy.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_growth_policy.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_growth_policy.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_growth_policy.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_growth_policy.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_policy.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_growth_profile; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_growth_profile (
    id bigint NOT NULL,
    owner_type character varying(32) NOT NULL,
    owner_id bigint NOT NULL,
    sport_id bigint NOT NULL,
    points integer NOT NULL,
    checkin_count integer NOT NULL,
    finish_count integer NOT NULL,
    policy_version character varying(64) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_growth_profile_checkin_count_check CHECK ((checkin_count >= 0)),
    CONSTRAINT asp_growth_profile_finish_count_check CHECK ((finish_count >= 0)),
    CONSTRAINT asp_growth_profile_owner_type_check CHECK (((owner_type)::text = ANY ((ARRAY['person'::character varying, 'team'::character varying])::text[]))),
    CONSTRAINT asp_growth_profile_points_check CHECK ((points >= 0)),
    CONSTRAINT asp_growth_profile_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_growth_profile; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_growth_profile IS '由可追溯成长事实汇总的个人或队伍运动成长；可重建，不是原始事实';


--
-- Name: COLUMN asp_growth_profile.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_growth_profile.owner_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.owner_type IS '独立业务状态；合法值不等于业务已获批准：person team';


--
-- Name: COLUMN asp_growth_profile.owner_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.owner_id IS '本人档案或长期队伍编号';


--
-- Name: COLUMN asp_growth_profile.sport_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.sport_id IS '运动';


--
-- Name: COLUMN asp_growth_profile.points; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.points IS '当前有效成长分';


--
-- Name: COLUMN asp_growth_profile.checkin_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.checkin_count IS '真实报到赛事数';


--
-- Name: COLUMN asp_growth_profile.finish_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.finish_count IS '有效完赛赛事数';


--
-- Name: COLUMN asp_growth_profile.policy_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.policy_version IS '汇总使用规则版本';


--
-- Name: COLUMN asp_growth_profile.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_growth_profile.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_growth_profile.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_growth_profile.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_growth_profile.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_growth_profile.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_profile.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_growth_record; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_growth_record (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    person_id bigint,
    team_id bigint,
    policy_version character varying(100) NOT NULL,
    achievement character varying(100) NOT NULL,
    source jsonb NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    sport_id bigint,
    event_id bigint,
    milestone character varying(64),
    points_delta integer DEFAULT 0 NOT NULL,
    source_key character varying(160),
    CONSTRAINT asp_growth_record_check CHECK (((person_id IS NOT NULL) <> (team_id IS NOT NULL))),
    CONSTRAINT asp_growth_record_status_check CHECK (((status)::text = ANY ((ARRAY['effective'::character varying, 'disputed'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT asp_growth_record_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_growth_record_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_growth_record; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_growth_record IS '非竞技成长事实；规则有来源，防止刷空赛事；来源：母版 D10；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_growth_record.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_growth_record.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_growth_record.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.person_id IS '个人';


--
-- Name: COLUMN asp_growth_record.team_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.team_id IS '队伍';


--
-- Name: COLUMN asp_growth_record.policy_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.policy_version IS '成长规则版本';


--
-- Name: COLUMN asp_growth_record.achievement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.achievement IS '参与/完赛/志愿等经确认行为';


--
-- Name: COLUMN asp_growth_record.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.source IS '原业务事实及范围；必须按版本校验结构';


--
-- Name: COLUMN asp_growth_record.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.status IS '独立业务状态；合法值不等于业务已获批准：effective disputed revoked';


--
-- Name: COLUMN asp_growth_record.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_growth_record.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_growth_record.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_growth_record.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_growth_record.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_growth_record.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_growth_record.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_honor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_honor (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint,
    person_id bigint,
    team_id bigint,
    category character varying(32) NOT NULL,
    title character varying(200) NOT NULL,
    source jsonb NOT NULL,
    status character varying(32) NOT NULL,
    awarded_at timestamp with time zone NOT NULL,
    display_until timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    registration_id bigint,
    award_key character varying(64),
    sport_id bigint,
    title_code character varying(64),
    applicant_account_id bigint,
    certification_status character varying(32),
    certification_details jsonb DEFAULT '{}'::jsonb NOT NULL,
    verified_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    certification_history jsonb DEFAULT '[]'::jsonb NOT NULL,
    certification_public boolean DEFAULT false NOT NULL,
    certification_worn boolean DEFAULT false NOT NULL,
    CONSTRAINT asp_honor_category_check CHECK (((category)::text = ANY ((ARRAY['official'::character varying, 'event'::character varying, 'achievement'::character varying, 'self_reported'::character varying])::text[]))),
    CONSTRAINT asp_honor_certification_shape CHECK (((jsonb_typeof(certification_details) = 'object'::text) AND (jsonb_typeof(verified_snapshot) = 'object'::text) AND (jsonb_typeof(certification_history) = 'array'::text) AND ((certification_status IS NULL) OR (((certification_status)::text = ANY ((ARRAY['draft'::character varying, 'submitted'::character varying, 'correction'::character varying, 'approved'::character varying, 'rejected'::character varying, 'revoked'::character varying])::text[])) AND (applicant_account_id IS NOT NULL) AND (person_id IS NOT NULL) AND (team_id IS NULL) AND ((category)::text = 'self_reported'::text) AND (sport_id IS NOT NULL) AND ((((certification_status)::text = 'approved'::text) AND ((status)::text = 'verified'::text) AND (verified_snapshot <> '{}'::jsonb)) OR (((certification_status)::text = 'revoked'::text) AND ((status)::text = 'revoked'::text)) OR (((certification_status)::text = ANY ((ARRAY['draft'::character varying, 'submitted'::character varying, 'correction'::character varying, 'rejected'::character varying])::text[])) AND ((status)::text = 'pending'::text))))) AND ((NOT certification_worn) OR (((certification_status)::text = 'approved'::text) AND ((status)::text = 'verified'::text))) AND ((NOT certification_public) OR (((certification_status)::text = 'approved'::text) AND ((status)::text = 'verified'::text))))),
    CONSTRAINT asp_honor_check CHECK (((person_id IS NOT NULL) <> (team_id IS NOT NULL))),
    CONSTRAINT asp_honor_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'verified'::character varying, 'suspended'::character varying, 'revised'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT asp_honor_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_honor_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_honor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_honor IS '分级荣誉及来源；当前佩戴不替代历史获得记录；来源：母版 D10；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_honor.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_honor.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_honor.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.event_id IS '来源赛事';


--
-- Name: COLUMN asp_honor.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.person_id IS '个人获得者';


--
-- Name: COLUMN asp_honor.team_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.team_id IS '队伍获得者';


--
-- Name: COLUMN asp_honor.category; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.category IS '独立业务状态；合法值不等于业务已获批准：official event achievement self_reported';


--
-- Name: COLUMN asp_honor.title; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.title IS '含项目、届次、层级和范围的名称';


--
-- Name: COLUMN asp_honor.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.source IS '授予或公布主体、证据和实际获奖成员快照；必须按版本校验结构';


--
-- Name: COLUMN asp_honor.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.status IS '独立业务状态；合法值不等于业务已获批准：pending verified suspended revised revoked';


--
-- Name: COLUMN asp_honor.awarded_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.awarded_at IS '获得时间；有时区业务时间';


--
-- Name: COLUMN asp_honor.display_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.display_until IS '当前展示期限；有时区业务时间';


--
-- Name: COLUMN asp_honor.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_honor.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_honor.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_honor.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_honor.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_honor.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_honor.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.registration_id IS '获奖报名。同一 award_key 的个人证明行属于这一条报名获奖事实';


--
-- Name: COLUMN asp_honor.award_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.award_key IS '同一条报名获奖事实的编号。双打和团体的多行个人证明共用';


--
-- Name: COLUMN asp_honor.applicant_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.applicant_account_id IS 'Authenticated owner of an external honor application; NULL for existing event/growth honors';


--
-- Name: COLUMN asp_honor.certification_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.certification_status IS 'draft/submitted/correction/approved/rejected/revoked, NULL for historical non-certification honors';


--
-- Name: COLUMN asp_honor.certification_details; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.certification_details IS 'Typed applicant claim and private honor-proof file IDs; never publicly returned';


--
-- Name: COLUMN asp_honor.verified_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.verified_snapshot IS 'Reviewer-confirmed year/event/sport/place/issuer/results source; title is server-derived, no growth award';


--
-- Name: COLUMN asp_honor.certification_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.certification_history IS 'Append-only submission, correction and decision snapshots; owner/reviewer access only';


--
-- Name: COLUMN asp_honor.certification_public; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.certification_public IS 'Owner consent for approved facts; also requires public profile consent';


--
-- Name: COLUMN asp_honor.certification_worn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_honor.certification_worn IS 'Only approved verified honors can be worn, one per person/sport';


--
-- Name: asp_idempotency; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_idempotency (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    account_id bigint NOT NULL,
    operation character varying(100) NOT NULL,
    request_key character varying(128) NOT NULL,
    payload_hash character varying(128) NOT NULL,
    status character varying(32) NOT NULL,
    result_reference jsonb,
    expires_at timestamp with time zone NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_idempotency_status_check CHECK (((status)::text = ANY ((ARRAY['processing'::character varying, 'completed'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT asp_idempotency_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_idempotency_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_idempotency; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_idempotency IS '请求去重及不确定响应恢复；不得只靠页面按钮防重；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_idempotency.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_idempotency.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_idempotency.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.account_id IS '调用者';


--
-- Name: COLUMN asp_idempotency.operation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.operation IS '动作';


--
-- Name: COLUMN asp_idempotency.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.request_key IS '客户端重试键';


--
-- Name: COLUMN asp_idempotency.payload_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.payload_hash IS '输入摘要；同键不同输入拒绝';


--
-- Name: COLUMN asp_idempotency.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.status IS '独立业务状态；合法值不等于业务已获批准：processing completed failed';


--
-- Name: COLUMN asp_idempotency.result_reference; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.result_reference IS '原业务结果引用；不存敏感完整响应；必须按版本校验结构';


--
-- Name: COLUMN asp_idempotency.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.expires_at IS '去重记录保留截止；有时区业务时间';


--
-- Name: COLUMN asp_idempotency.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_idempotency.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_idempotency.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_idempotency.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_idempotency.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_idempotency.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_idempotency.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_lineup_member; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_lineup_member (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    match_entry_id bigint NOT NULL,
    roster_member_id bigint NOT NULL,
    role character varying(32) NOT NULL,
    "position" integer,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_lineup_member_position_check CHECK (("position" >= 0)),
    CONSTRAINT asp_lineup_member_role_check CHECK (((role)::text = ANY ((ARRAY['starter'::character varying, 'substitute'::character varying])::text[]))),
    CONSTRAINT asp_lineup_member_status_check CHECK (((status)::text = ANY ((ARRAY['planned'::character varying, 'confirmed'::character varying, 'replaced'::character varying, 'appeared'::character varying])::text[]))),
    CONSTRAINT asp_lineup_member_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_lineup_member_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_lineup_member; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_lineup_member IS '单场阵容及实际出场；不能从当前队伍直接拉人上场；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_lineup_member.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_lineup_member.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_lineup_member.match_entry_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.match_entry_id IS '场次参赛单位';


--
-- Name: COLUMN asp_lineup_member.roster_member_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.roster_member_id IS '冻结赛事名单成员';


--
-- Name: COLUMN asp_lineup_member.role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.role IS '独立业务状态；合法值不等于业务已获批准：starter substitute';


--
-- Name: COLUMN asp_lineup_member."position"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member."position" IS '规程要求顺序';


--
-- Name: COLUMN asp_lineup_member.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.status IS '独立业务状态；合法值不等于业务已获批准：planned confirmed replaced appeared';


--
-- Name: COLUMN asp_lineup_member.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_lineup_member.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_lineup_member.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_lineup_member.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_lineup_member.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_lineup_member.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_lineup_member.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_login_identity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_login_identity (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    channel character varying(100) NOT NULL,
    subject_hash character varying(128) NOT NULL,
    subject_cipher character varying(1000),
    valid_from timestamp with time zone NOT NULL,
    valid_until timestamp with time zone,
    verification_source character varying(100) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_login_identity_check CHECK (((valid_until IS NULL) OR (valid_until > valid_from))),
    CONSTRAINT asp_login_identity_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_login_identity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_login_identity IS '账号渠道绑定和解绑历史；手机号回收不直接转移历史档案；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_login_identity.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_login_identity.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.account_id IS '绑定平台账号';


--
-- Name: COLUMN asp_login_identity.channel; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.channel IS 'phone/wechat/其他登录渠道';


--
-- Name: COLUMN asp_login_identity.subject_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.subject_hash IS '渠道标识带密钥摘要；不得明文公开';


--
-- Name: COLUMN asp_login_identity.subject_cipher; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.subject_cipher IS '需要恢复时的加密标识';


--
-- Name: COLUMN asp_login_identity.valid_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.valid_from IS '绑定生效；有时区业务时间';


--
-- Name: COLUMN asp_login_identity.valid_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.valid_until IS '绑定结束；有时区业务时间';


--
-- Name: COLUMN asp_login_identity.verification_source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.verification_source IS '核验依据及方式';


--
-- Name: COLUMN asp_login_identity.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_login_identity.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_login_identity.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_login_identity.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_login_identity.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_login_identity.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_login_identity.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_match; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_match (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    stage_id bigint NOT NULL,
    schedule_run_id bigint,
    code character varying(100) NOT NULL,
    round_number integer NOT NULL,
    resource_id bigint,
    scheduled_start timestamp with time zone,
    scheduled_end timestamp with time zone,
    actual_start timestamp with time zone,
    actual_end timestamp with time zone,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    court_name character varying(80),
    CONSTRAINT asp_match_check CHECK (((scheduled_end IS NULL) OR (scheduled_start IS NULL) OR (scheduled_end > scheduled_start))),
    CONSTRAINT asp_match_check1 CHECK (((actual_end IS NULL) OR (actual_start IS NULL) OR (actual_end >= actual_start))),
    CONSTRAINT asp_match_round_number_check CHECK ((round_number >= 0)),
    CONSTRAINT asp_match_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'checkin'::character varying, 'running'::character varying, 'completed'::character varying, 'abandoned'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT asp_match_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_match_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_match; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_match IS '稳定比赛身份；时间变更不改场次身份；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_match.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_match.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_match.stage_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.stage_id IS '阶段';


--
-- Name: COLUMN asp_match.schedule_run_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.schedule_run_id IS '当前排程版本';


--
-- Name: COLUMN asp_match.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.code IS '阶段内稳定比赛编号';


--
-- Name: COLUMN asp_match.round_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.round_number IS '轮次';


--
-- Name: COLUMN asp_match.resource_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.resource_id IS '安排资源';


--
-- Name: COLUMN asp_match.scheduled_start; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.scheduled_start IS '预计开始；有时区业务时间';


--
-- Name: COLUMN asp_match.scheduled_end; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.scheduled_end IS '预计结束；有时区业务时间';


--
-- Name: COLUMN asp_match.actual_start; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.actual_start IS '实际开始；有时区业务时间';


--
-- Name: COLUMN asp_match.actual_end; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.actual_end IS '实际结束；有时区业务时间';


--
-- Name: COLUMN asp_match.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.status IS '独立业务状态；合法值不等于业务已获批准：draft published checkin running completed abandoned cancelled';


--
-- Name: COLUMN asp_match.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_match.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_match.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_match.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_match.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_match.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_match_entry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_match_entry (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    match_id bigint NOT NULL,
    registration_id bigint,
    roster_version_id bigint,
    slot character varying(100) NOT NULL,
    qualification_source jsonb NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_match_entry_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'confirmed'::character varying, 'withdrawn'::character varying, 'disqualified'::character varying])::text[]))),
    CONSTRAINT asp_match_entry_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_match_entry_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_match_entry; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_match_entry IS '对阵或计时评分参赛集合；未来晋级席位可待定；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_match_entry.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_match_entry.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_match_entry.match_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.match_id IS '场次';


--
-- Name: COLUMN asp_match_entry.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.registration_id IS '参赛报名；尚未晋级可为空';


--
-- Name: COLUMN asp_match_entry.roster_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.roster_version_id IS '本场名单依据';


--
-- Name: COLUMN asp_match_entry.slot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.slot IS '对阵位置/道次/试次等';


--
-- Name: COLUMN asp_match_entry.qualification_source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.qualification_source IS '已确认报名或条件晋级路径；必须按版本校验结构';


--
-- Name: COLUMN asp_match_entry.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.status IS '独立业务状态；合法值不等于业务已获批准：pending confirmed withdrawn disqualified';


--
-- Name: COLUMN asp_match_entry.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_match_entry.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_match_entry.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_match_entry.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_match_entry.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_match_entry.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_match_entry.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_matching_offer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_matching_offer (
    id bigint NOT NULL,
    unit_id bigint NOT NULL,
    room_id bigint,
    status character varying(32) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_matching_offer_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'declined'::character varying, 'expired'::character varying])::text[]))),
    CONSTRAINT asp_matching_offer_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_matching_offer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_matching_offer IS '匹配确认邀请；每名成员本人接受，120秒确认席位与正式报名名额分开';


--
-- Name: COLUMN asp_matching_offer.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_matching_offer.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer.unit_id IS '报名项目';


--
-- Name: COLUMN asp_matching_offer.room_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer.room_id IS '现有或接受后创建的房间';


--
-- Name: COLUMN asp_matching_offer.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer.status IS '独立业务状态；合法值不等于业务已获批准：pending accepted declined expired';


--
-- Name: COLUMN asp_matching_offer.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer.expires_at IS '确认期限；有时区业务时间';


--
-- Name: COLUMN asp_matching_offer.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_matching_offer.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_matching_offer.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_matching_offer.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_matching_offer.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_matching_offer.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_matching_offer_member; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_matching_offer_member (
    id bigint NOT NULL,
    offer_id bigint NOT NULL,
    account_id bigint NOT NULL,
    request_id bigint,
    status character varying(32) NOT NULL,
    answered_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_matching_offer_member_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'declined'::character varying])::text[]))),
    CONSTRAINT asp_matching_offer_member_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_matching_offer_member; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_matching_offer_member IS '匹配邀请的一名接收者；全部接受后才加入房间';


--
-- Name: COLUMN asp_matching_offer_member.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_matching_offer_member.offer_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.offer_id IS '邀请';


--
-- Name: COLUMN asp_matching_offer_member.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.account_id IS '接收人';


--
-- Name: COLUMN asp_matching_offer_member.request_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.request_id IS '来源排队';


--
-- Name: COLUMN asp_matching_offer_member.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.status IS '独立业务状态；合法值不等于业务已获批准：pending accepted declined';


--
-- Name: COLUMN asp_matching_offer_member.answered_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.answered_at IS '本人回答时间；有时区业务时间';


--
-- Name: COLUMN asp_matching_offer_member.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_matching_offer_member.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_matching_offer_member.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_matching_offer_member.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_matching_offer_member.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_matching_offer_member.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_offer_member.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_matching_request; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_matching_request (
    id bigint NOT NULL,
    unit_id bigint NOT NULL,
    account_id bigint NOT NULL,
    room_id bigint,
    preferences jsonb NOT NULL,
    status character varying(32) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_matching_request_status_check CHECK (((status)::text = ANY ((ARRAY['waiting'::character varying, 'offered'::character varying, 'accepted'::character varying, 'cancelled'::character varying, 'expired'::character varying])::text[]))),
    CONSTRAINT asp_matching_request_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_matching_request; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_matching_request IS '自动匹配排队意向；不占赛事正式报名名额';


--
-- Name: COLUMN asp_matching_request.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_matching_request.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.unit_id IS '同一报名项目';


--
-- Name: COLUMN asp_matching_request.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.account_id IS '排队本人';


--
-- Name: COLUMN asp_matching_request.room_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.room_id IS '补充现有房间；个人匹配可空';


--
-- Name: COLUMN asp_matching_request.preferences; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.preferences IS '本人选择的时间等偏好；必须按版本校验结构';


--
-- Name: COLUMN asp_matching_request.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.status IS '独立业务状态；合法值不等于业务已获批准：waiting offered accepted cancelled expired';


--
-- Name: COLUMN asp_matching_request.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.expires_at IS '意向截止；有时区业务时间';


--
-- Name: COLUMN asp_matching_request.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_matching_request.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_matching_request.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_matching_request.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_matching_request.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_matching_request.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_matching_request.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_material_requirement; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_material_requirement (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    rule_version_id bigint NOT NULL,
    code character varying(100) NOT NULL,
    purpose character varying(500) NOT NULL,
    sensitivity character varying(32) NOT NULL,
    gates jsonb NOT NULL,
    retention_days integer,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_material_requirement_retention_days_check CHECK ((retention_days >= 0)),
    CONSTRAINT asp_material_requirement_sensitivity_check CHECK (((sensitivity)::text = ANY ((ARRAY['ordinary'::character varying, 'identity'::character varying, 'guardian'::character varying, 'health'::character varying, 'finance'::character varying])::text[]))),
    CONSTRAINT asp_material_requirement_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_material_requirement_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_material_requirement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_material_requirement IS '赛事材料、用途与各阶段前置；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_material_requirement.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_material_requirement.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_material_requirement.rule_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.rule_version_id IS '规则版本';


--
-- Name: COLUMN asp_material_requirement.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.code IS '材料编码';


--
-- Name: COLUMN asp_material_requirement.purpose; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.purpose IS '资料使用用途';


--
-- Name: COLUMN asp_material_requirement.sensitivity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.sensitivity IS '独立业务状态；合法值不等于业务已获批准：ordinary identity guardian health finance';


--
-- Name: COLUMN asp_material_requirement.gates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.gates IS '占位/审核/检录/公开分别的前置及确认；必须按版本校验结构';


--
-- Name: COLUMN asp_material_requirement.retention_days; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.retention_days IS '保留期限；0 须按政策明确解释';


--
-- Name: COLUMN asp_material_requirement.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_material_requirement.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_material_requirement.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_material_requirement.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_material_requirement.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_material_requirement.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_requirement.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_material_submission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_material_submission (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    registration_id bigint NOT NULL,
    roster_member_id bigint,
    requirement_id bigint NOT NULL,
    file_id bigint NOT NULL,
    revision integer NOT NULL,
    status character varying(32) NOT NULL,
    valid_until timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_material_submission_revision_check CHECK ((revision >= 0)),
    CONSTRAINT asp_material_submission_status_check CHECK (((status)::text = ANY ((ARRAY['submitted'::character varying, 'correction'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'expired'::character varying])::text[]))),
    CONSTRAINT asp_material_submission_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_material_submission_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_material_submission; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_material_submission IS '报名材料提交版本、核验与现场验证分离；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_material_submission.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_material_submission.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_material_submission.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.registration_id IS '报名';


--
-- Name: COLUMN asp_material_submission.roster_member_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.roster_member_id IS '相关成员';


--
-- Name: COLUMN asp_material_submission.requirement_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.requirement_id IS '规程要求';


--
-- Name: COLUMN asp_material_submission.file_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.file_id IS '受控材料';


--
-- Name: COLUMN asp_material_submission.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.revision IS '提交版本';


--
-- Name: COLUMN asp_material_submission.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.status IS '独立业务状态；合法值不等于业务已获批准：submitted correction accepted rejected expired';


--
-- Name: COLUMN asp_material_submission.valid_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.valid_until IS '材料有效截止；有时区业务时间';


--
-- Name: COLUMN asp_material_submission.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_material_submission.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_material_submission.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_material_submission.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_material_submission.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_material_submission.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_material_submission.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_migration_batch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_migration_batch (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    source_system character varying(100) NOT NULL,
    source_version character varying(100) NOT NULL,
    authorization_snapshot jsonb NOT NULL,
    reconciliation jsonb NOT NULL,
    status character varying(32) NOT NULL,
    cutover_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_migration_batch_status_check CHECK (((status)::text = ANY ((ARRAY['importing'::character varying, 'checking'::character varying, 'verified'::character varying, 'blocked'::character varying, 'cutover'::character varying, 'rolled_back'::character varying])::text[]))),
    CONSTRAINT asp_migration_batch_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_migration_batch_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_migration_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_migration_batch IS '旧系统来源、授权及数量金额差异核对；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_migration_batch.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_migration_batch.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_migration_batch.source_system; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.source_system IS '来源系统';


--
-- Name: COLUMN asp_migration_batch.source_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.source_version IS '导出及切换版本';


--
-- Name: COLUMN asp_migration_batch.authorization_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.authorization_snapshot IS '迁移范围及接收责任；必须按版本校验结构';


--
-- Name: COLUMN asp_migration_batch.reconciliation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.reconciliation IS '身份、名单、金额、退款、赛程及结果汇总；必须按版本校验结构';


--
-- Name: COLUMN asp_migration_batch.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.status IS '独立业务状态；合法值不等于业务已获批准：importing checking verified blocked cutover rolled_back';


--
-- Name: COLUMN asp_migration_batch.cutover_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.cutover_at IS '唯一生效切换时间；有时区业务时间';


--
-- Name: COLUMN asp_migration_batch.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_migration_batch.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_migration_batch.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_migration_batch.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_migration_batch.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_migration_batch.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_batch.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_migration_mapping; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_migration_mapping (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    batch_id bigint NOT NULL,
    object_type character varying(100) NOT NULL,
    source_key character varying(200) NOT NULL,
    target_id bigint,
    status character varying(32) NOT NULL,
    difference jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_migration_mapping_status_check CHECK (((status)::text = ANY ((ARRAY['matched'::character varying, 'missing'::character varying, 'conflict'::character varying, 'reconciled'::character varying])::text[]))),
    CONSTRAINT asp_migration_mapping_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_migration_mapping_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_migration_mapping; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_migration_mapping IS '旧新记录映射、差异及未完责任；不虚构调平；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_migration_mapping.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_migration_mapping.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_migration_mapping.batch_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.batch_id IS '迁移批次';


--
-- Name: COLUMN asp_migration_mapping.object_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.object_type IS '业务对象类型';


--
-- Name: COLUMN asp_migration_mapping.source_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.source_key IS '旧系统稳定键';


--
-- Name: COLUMN asp_migration_mapping.target_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.target_id IS '新对象 ID';


--
-- Name: COLUMN asp_migration_mapping.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.status IS '独立业务状态；合法值不等于业务已获批准：matched missing conflict reconciled';


--
-- Name: COLUMN asp_migration_mapping.difference; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.difference IS '来源、差异和处理人；必须按版本校验结构';


--
-- Name: COLUMN asp_migration_mapping.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_migration_mapping.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_migration_mapping.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_migration_mapping.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_migration_mapping.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_migration_mapping.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_migration_mapping.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_notification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_notification (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    recipient_account_id bigint NOT NULL,
    business_type character varying(100) NOT NULL,
    business_id bigint NOT NULL,
    business_revision integer NOT NULL,
    purpose character varying(100) NOT NULL,
    content jsonb NOT NULL,
    dedupe_key character varying(200) NOT NULL,
    read_at timestamp with time zone,
    confirmed_at timestamp with time zone,
    response jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_notification_business_revision_check CHECK ((business_revision >= 0)),
    CONSTRAINT asp_notification_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_notification_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_notification; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_notification IS '业务通知内容版本及对象；不可夹带未授权营销；来源：母版 D11；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_notification.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_notification.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_notification.recipient_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.recipient_account_id IS '目标账号';


--
-- Name: COLUMN asp_notification.business_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.business_type IS '来源业务类型';


--
-- Name: COLUMN asp_notification.business_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.business_id IS '来源业务对象';


--
-- Name: COLUMN asp_notification.business_revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.business_revision IS '来源版本';


--
-- Name: COLUMN asp_notification.purpose; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.purpose IS '必要服务或经同意营销';


--
-- Name: COLUMN asp_notification.content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.content IS '允许告知范围；必须按版本校验结构';


--
-- Name: COLUMN asp_notification.dedupe_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.dedupe_key IS '重复处理防重键';


--
-- Name: COLUMN asp_notification.read_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.read_at IS '已读；有时区业务时间';


--
-- Name: COLUMN asp_notification.confirmed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.confirmed_at IS '用户作出决定；有时区业务时间';


--
-- Name: COLUMN asp_notification.response; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.response IS '接受/协调/退赛等业务决定；必须按版本校验结构';


--
-- Name: COLUMN asp_notification.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_notification.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_notification.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_notification.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_notification.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_notification.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_notification_delivery; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_notification_delivery (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    notification_id bigint NOT NULL,
    channel character varying(100) NOT NULL,
    attempt integer NOT NULL,
    status character varying(32) NOT NULL,
    channel_reference character varying(200),
    sent_at timestamp with time zone,
    delivered_at timestamp with time zone,
    failure_reason character varying(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_notification_delivery_attempt_check CHECK ((attempt >= 0)),
    CONSTRAINT asp_notification_delivery_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'sent'::character varying, 'delivered'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT asp_notification_delivery_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_notification_delivery_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_notification_delivery; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_notification_delivery IS '逐渠道发送和送达结果；失败需责任人跟进；来源：母版 D11；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_notification_delivery.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_notification_delivery.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_notification_delivery.notification_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.notification_id IS '通知';


--
-- Name: COLUMN asp_notification_delivery.channel; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.channel IS '站内/短信/小程序等';


--
-- Name: COLUMN asp_notification_delivery.attempt; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.attempt IS '尝试次数';


--
-- Name: COLUMN asp_notification_delivery.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.status IS '独立业务状态；合法值不等于业务已获批准：pending sent delivered failed';


--
-- Name: COLUMN asp_notification_delivery.channel_reference; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.channel_reference IS '渠道回执';


--
-- Name: COLUMN asp_notification_delivery.sent_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.sent_at IS '发送；有时区业务时间';


--
-- Name: COLUMN asp_notification_delivery.delivered_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.delivered_at IS '送达；有时区业务时间';


--
-- Name: COLUMN asp_notification_delivery.failure_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.failure_reason IS '失败原因';


--
-- Name: COLUMN asp_notification_delivery.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_notification_delivery.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_notification_delivery.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_notification_delivery.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_notification_delivery.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_notification_delivery.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_notification_delivery.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_occupation_reference; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_occupation_reference (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    occupation_id bigint NOT NULL,
    registration_id bigint NOT NULL,
    status character varying(32) NOT NULL,
    released_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_occupation_reference_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'released'::character varying])::text[]))),
    CONSTRAINT asp_occupation_reference_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_occupation_reference_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_occupation_reference; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_occupation_reference IS '报名到容量占用的引用；取消最后引用才释放去重人数；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_occupation_reference.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_occupation_reference.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_occupation_reference.occupation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.occupation_id IS '共享占用';


--
-- Name: COLUMN asp_occupation_reference.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.registration_id IS '使用占用的报名';


--
-- Name: COLUMN asp_occupation_reference.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.status IS '独立业务状态；合法值不等于业务已获批准：active released';


--
-- Name: COLUMN asp_occupation_reference.released_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.released_at IS '解除引用；有时区业务时间';


--
-- Name: COLUMN asp_occupation_reference.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_occupation_reference.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_occupation_reference.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_occupation_reference.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_occupation_reference.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_occupation_reference.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_occupation_reference.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_official_assignment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_official_assignment (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    match_id bigint NOT NULL,
    person_id bigint NOT NULL,
    role character varying(100) NOT NULL,
    status character varying(32) NOT NULL,
    basis jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_official_assignment_status_check CHECK (((status)::text = ANY ((ARRAY['proposed'::character varying, 'accepted'::character varying, 'replaced'::character varying, 'completed'::character varying])::text[]))),
    CONSTRAINT asp_official_assignment_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_official_assignment_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_official_assignment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_official_assignment IS '裁判、记录员及结果确认人员到场次的授权任务；来源：母版 D09；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_official_assignment.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_official_assignment.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_official_assignment.match_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.match_id IS '场次';


--
-- Name: COLUMN asp_official_assignment.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.person_id IS '现实执行人员';


--
-- Name: COLUMN asp_official_assignment.role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.role IS '录入/确认/发布等';


--
-- Name: COLUMN asp_official_assignment.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.status IS '独立业务状态；合法值不等于业务已获批准：proposed accepted replaced completed';


--
-- Name: COLUMN asp_official_assignment.basis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.basis IS '职责与专业资格来源；必须按版本校验结构';


--
-- Name: COLUMN asp_official_assignment.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_official_assignment.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_official_assignment.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_official_assignment.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_official_assignment.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_official_assignment.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_official_assignment.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_org_field; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_org_field (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    organization_id bigint NOT NULL,
    code character varying(64) NOT NULL,
    label character varying(100) NOT NULL,
    value_type character varying(32) NOT NULL,
    options jsonb NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_org_field_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'stopped'::character varying])::text[]))),
    CONSTRAINT asp_org_field_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_org_field_value_type_check CHECK (((value_type)::text = ANY ((ARRAY['text'::character varying, 'number'::character varying, 'date'::character varying, 'enum'::character varying])::text[]))),
    CONSTRAINT asp_org_field_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_org_field; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_org_field IS '组织自有的参赛采集字段。未选用可停用；选用后不改类型和选项含义；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_org_field.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_org_field.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_org_field.organization_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.organization_id IS '维护这个目录的组织';


--
-- Name: COLUMN asp_org_field.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.code IS '组织内稳定编码';


--
-- Name: COLUMN asp_org_field.label; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.label IS '显示名称';


--
-- Name: COLUMN asp_org_field.value_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.value_type IS '独立业务状态；合法值不等于业务已获批准：text number date enum';


--
-- Name: COLUMN asp_org_field.options; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.options IS '单选枚举的选项。其他类型为空数组；必须按版本校验结构';


--
-- Name: COLUMN asp_org_field.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.status IS '独立业务状态；合法值不等于业务已获批准：active stopped';


--
-- Name: COLUMN asp_org_field.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_org_field.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_org_field.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_org_field.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_org_field.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_org_field.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_org_field.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_organization; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_organization (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    name character varying(200) NOT NULL,
    subject_type character varying(100),
    subject_hash character varying(128),
    status character varying(32) NOT NULL,
    contact_cipher character varying(1000),
    current_qualification_id bigint,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_organization_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'pending'::character varying, 'correction'::character varying, 'certified'::character varying, 'expired'::character varying, 'restricted'::character varying])::text[]))),
    CONSTRAINT asp_organization_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_organization_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_organization; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_organization IS '承办责任主体与租户映射。本期只在办赛申请通过后创建；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_organization.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_organization.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_organization.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.name IS '主体名称';


--
-- Name: COLUMN asp_organization.subject_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.subject_type IS '企业/学校/协会/俱乐部等。本期办赛申请不采集，可空';


--
-- Name: COLUMN asp_organization.subject_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.subject_hash IS '主体标识受控摘要。空摘要不互相占用';


--
-- Name: COLUMN asp_organization.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.status IS '独立业务状态；合法值不等于业务已获批准：draft pending correction certified expired restricted';


--
-- Name: COLUMN asp_organization.contact_cipher; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.contact_cipher IS '必要联系资料加密值';


--
-- Name: COLUMN asp_organization.current_qualification_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.current_qualification_id IS '当前适用资质版本；服务核验归属';


--
-- Name: COLUMN asp_organization.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_organization.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_organization.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_organization.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_organization.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_organization.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_organization_application; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_organization_application (
    id bigint NOT NULL,
    applicant_account_id bigint NOT NULL,
    status character varying(32) NOT NULL,
    name character varying(200),
    contact_name character varying(100),
    contact_cipher character varying(1000),
    statement character varying(1000),
    file_ids jsonb,
    organization_id bigint,
    organization_tenant_id character varying(20),
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    assigned_reviewer_id bigint,
    CONSTRAINT asp_organization_application_check CHECK ((((status)::text <> 'approved'::text) OR ((organization_id IS NOT NULL) AND (organization_tenant_id IS NOT NULL)))),
    CONSTRAINT asp_organization_application_organization_tenant_id_check CHECK (((organization_tenant_id IS NULL) OR (length((organization_tenant_id)::text) > 0))),
    CONSTRAINT asp_organization_application_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'pending'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[]))),
    CONSTRAINT asp_organization_application_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_organization_application; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_organization_application IS '办赛申请。平台级数据，没有业务租户。审核只决定是否开放办赛，不表示主体已验真';


--
-- Name: COLUMN asp_organization_application.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_organization_application.applicant_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.applicant_account_id IS '申请人。本期一人一份';


--
-- Name: COLUMN asp_organization_application.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.status IS 'draft pending approved rejected';


--
-- Name: COLUMN asp_organization_application.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.name IS '组织名称。草稿可空，提交必填';


--
-- Name: COLUMN asp_organization_application.contact_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.contact_name IS '联系人。可以和登录用户不同。草稿可空，提交必填';


--
-- Name: COLUMN asp_organization_application.contact_cipher; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.contact_cipher IS '联系方式加密值。不要求是手机号，不发送短信';


--
-- Name: COLUMN asp_organization_application.statement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.statement IS '申请说明';


--
-- Name: COLUMN asp_organization_application.file_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.file_ids IS '当前稿附件编号。结构为 fileIds 数组';


--
-- Name: COLUMN asp_organization_application.organization_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.organization_id IS '通过后写入的组织编号。组织属于租户，这里不建外键';


--
-- Name: COLUMN asp_organization_application.organization_tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.organization_tenant_id IS '通过后的组织租户编号';


--
-- Name: COLUMN asp_organization_application.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_organization_application.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_organization_application.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_organization_application.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_organization_application.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_organization_application.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_organization_application.assigned_reviewer_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application.assigned_reviewer_id IS '指定政府审核经办人，普通岗位只能处理明确分配给本人的申请';


--
-- Name: asp_organization_application_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_organization_application_version (
    id bigint NOT NULL,
    application_id bigint NOT NULL,
    revision integer NOT NULL,
    name character varying(200) NOT NULL,
    contact_name character varying(100) NOT NULL,
    contact_cipher character varying(1000) NOT NULL,
    statement character varying(1000),
    file_ids jsonb NOT NULL,
    status character varying(32) NOT NULL,
    reviewer_id bigint,
    review_reason character varying(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_organization_application_version_revision_check CHECK ((revision > 0)),
    CONSTRAINT asp_organization_application_version_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[]))),
    CONSTRAINT asp_organization_application_version_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_organization_application_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_organization_application_version IS '办赛申请每次提交时冻结的内容和附件。拒绝后的旧版不改';


--
-- Name: COLUMN asp_organization_application_version.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_organization_application_version.application_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.application_id IS '申请';


--
-- Name: COLUMN asp_organization_application_version.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.revision IS '从 1 开始的提交版本';


--
-- Name: COLUMN asp_organization_application_version.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.name IS '该版组织名称';


--
-- Name: COLUMN asp_organization_application_version.contact_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.contact_name IS '该版联系人';


--
-- Name: COLUMN asp_organization_application_version.contact_cipher; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.contact_cipher IS '该版联系方式加密值';


--
-- Name: COLUMN asp_organization_application_version.statement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.statement IS '该版申请说明';


--
-- Name: COLUMN asp_organization_application_version.file_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.file_ids IS '该版附件编号。结构为 fileIds 数组';


--
-- Name: COLUMN asp_organization_application_version.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.status IS '独立业务状态；合法值不等于业务已获批准：pending approved rejected';


--
-- Name: COLUMN asp_organization_application_version.reviewer_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.reviewer_id IS '审核人后台用户编号。只有超级管理员';


--
-- Name: COLUMN asp_organization_application_version.review_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.review_reason IS '拒绝理由。通过时可空';


--
-- Name: COLUMN asp_organization_application_version.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_organization_application_version.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_organization_application_version.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_organization_application_version.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_organization_application_version.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_organization_application_version.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_organization_application_version.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_outbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_outbox (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_key character varying(128) NOT NULL,
    aggregate_type character varying(100) NOT NULL,
    aggregate_id bigint NOT NULL,
    aggregate_revision integer NOT NULL,
    event_type character varying(100) NOT NULL,
    payload jsonb NOT NULL,
    status character varying(32) NOT NULL,
    attempts integer NOT NULL,
    next_attempt_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_outbox_aggregate_revision_check CHECK ((aggregate_revision >= 0)),
    CONSTRAINT asp_outbox_attempts_check CHECK ((attempts >= 0)),
    CONSTRAINT asp_outbox_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'delivered'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT asp_outbox_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_outbox_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_outbox; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_outbox IS '本地事务提交的跨模块通知/事件；消费必须幂等；来源：母版 D13；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_outbox.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_outbox.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_outbox.event_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.event_key IS '稳定事件去重 ID';


--
-- Name: COLUMN asp_outbox.aggregate_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.aggregate_type IS '来源聚合';


--
-- Name: COLUMN asp_outbox.aggregate_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.aggregate_id IS '来源 ID';


--
-- Name: COLUMN asp_outbox.aggregate_revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.aggregate_revision IS '来源业务版本';


--
-- Name: COLUMN asp_outbox.event_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.event_type IS '版本化事件名';


--
-- Name: COLUMN asp_outbox.payload; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.payload IS '最小必要跨模块契约；必须按版本校验结构';


--
-- Name: COLUMN asp_outbox.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.status IS '独立业务状态；合法值不等于业务已获批准：pending processing delivered failed';


--
-- Name: COLUMN asp_outbox.attempts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.attempts IS '尝试数';


--
-- Name: COLUMN asp_outbox.next_attempt_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.next_attempt_at IS '下次尝试；有时区业务时间';


--
-- Name: COLUMN asp_outbox.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_outbox.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_outbox.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_outbox.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_outbox.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_outbox.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_outbox.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_payment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_payment (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    payer_account_id bigint,
    payee_subject character varying(200) NOT NULL,
    transaction_id character varying(200),
    amount numeric(18,2) NOT NULL,
    currency character varying(3) NOT NULL,
    status character varying(32) NOT NULL,
    evidence jsonb NOT NULL,
    occurred_at timestamp with time zone,
    confirmed_at timestamp with time zone,
    request_key character varying(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    payer_name character varying(200),
    payer_presence character varying(32) NOT NULL,
    payment_mode character varying(32) NOT NULL,
    confirmation_source character varying(32) NOT NULL,
    CONSTRAINT asp_payment_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT asp_payment_payment_mode_allowed_check CHECK (((payment_mode)::text = ANY ((ARRAY['free'::character varying, 'offline'::character varying, 'organizer_qr'::character varying, 'event'::character varying])::text[]))),
    CONSTRAINT asp_payment_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_payment_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_asp_payment_payer_presence CHECK (((payer_presence)::text = ANY ((ARRAY['known'::character varying, 'external'::character varying, 'unavailable'::character varying])::text[]))),
    CONSTRAINT ck_asp_payment_source CHECK (((confirmation_source)::text = ANY ((ARRAY['manual'::character varying, 'callback'::character varying])::text[]))),
    CONSTRAINT ck_asp_payment_status CHECK (((status)::text = ANY ((ARRAY['confirmed'::character varying, 'reversed'::character varying])::text[])))
);


--
-- Name: TABLE asp_payment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_payment IS '已经确认的到账事实。未付款时不插入。冲正不是退款';


--
-- Name: COLUMN asp_payment.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_payment.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_payment.payer_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.payer_account_id IS '付款人平台账号。不是平台账号时为空';


--
-- Name: COLUMN asp_payment.payee_subject; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.payee_subject IS '真实接收主体';


--
-- Name: COLUMN asp_payment.transaction_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.transaction_id IS '渠道或人工核对业务号';


--
-- Name: COLUMN asp_payment.amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.amount IS '实际金额；人民币元，不能用浮点';


--
-- Name: COLUMN asp_payment.currency; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.currency IS '币种';


--
-- Name: COLUMN asp_payment.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.status IS 'confirmed reversed。冲正不是退款';


--
-- Name: COLUMN asp_payment.evidence; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.evidence IS '渠道确认及核对依据；敏感信息受控；必须按版本校验结构';


--
-- Name: COLUMN asp_payment.occurred_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.occurred_at IS '实际发生；有时区业务时间';


--
-- Name: COLUMN asp_payment.confirmed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.confirmed_at IS '平台核实；有时区业务时间';


--
-- Name: COLUMN asp_payment.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.request_key IS '发起幂等键';


--
-- Name: COLUMN asp_payment.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_payment.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_payment.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_payment.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_payment.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_payment.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_payment.payer_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.payer_name IS '实际付款人名称。外部付款人用它';


--
-- Name: COLUMN asp_payment.payer_presence; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.payer_presence IS '独立业务状态；合法值不等于业务已获批准：known external unavailable';


--
-- Name: COLUMN asp_payment.payment_mode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.payment_mode IS '付款义务的收费路径，不表示实际到账：free offline organizer_qr event';


--
-- Name: COLUMN asp_payment.confirmation_source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment.confirmation_source IS '独立业务状态；合法值不等于业务已获批准：manual callback';


--
-- Name: asp_payment_action; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_payment_action (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    payment_id bigint NOT NULL,
    obligation_id bigint NOT NULL,
    status character varying(32) NOT NULL,
    note character varying(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_payment_action_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'closed_no_refund'::character varying, 'refunded'::character varying])::text[]))),
    CONSTRAINT asp_payment_action_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_payment_action_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_payment_action; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_payment_action IS '已付款报名失效后的资金后续。平台不发起退款';


--
-- Name: COLUMN asp_payment_action.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_payment_action.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_payment_action.payment_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.payment_id IS '已确认的付款';


--
-- Name: COLUMN asp_payment_action.obligation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.obligation_id IS '当时的义务';


--
-- Name: COLUMN asp_payment_action.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.status IS '独立业务状态；合法值不等于业务已获批准：pending closed_no_refund refunded';


--
-- Name: COLUMN asp_payment_action.note; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.note IS '承办方说明';


--
-- Name: COLUMN asp_payment_action.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_payment_action.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_payment_action.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_payment_action.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_payment_action.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_payment_action.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_action.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_payment_allocation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_payment_allocation (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    payment_id bigint NOT NULL,
    obligation_id bigint NOT NULL,
    share_id bigint,
    amount numeric(18,2) NOT NULL,
    status character varying(32) NOT NULL,
    request_key character varying(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_payment_allocation_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT asp_payment_allocation_amount_check1 CHECK ((amount >= (0)::numeric)),
    CONSTRAINT asp_payment_allocation_status_check CHECK (((status)::text = ANY ((ARRAY['effective'::character varying, 'reversed'::character varying])::text[]))),
    CONSTRAINT asp_payment_allocation_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_payment_allocation_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_payment_allocation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_payment_allocation IS '付款到义务与分担的映射；支持多笔实收，超额需资金收尾，不新增资格；来源：母版 D06；事务锁定付款和义务，累计有效分配不能超过确认收款；实际超额保留原款并人工收尾，分担须属于义务。';


--
-- Name: COLUMN asp_payment_allocation.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_payment_allocation.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_payment_allocation.payment_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.payment_id IS '实际付款';


--
-- Name: COLUMN asp_payment_allocation.obligation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.obligation_id IS '覆盖义务';


--
-- Name: COLUMN asp_payment_allocation.share_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.share_id IS '对应分担';


--
-- Name: COLUMN asp_payment_allocation.amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.amount IS '有效分配金额；人民币元，不能用浮点';


--
-- Name: COLUMN asp_payment_allocation.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.status IS '独立业务状态；合法值不等于业务已获批准：effective reversed';


--
-- Name: COLUMN asp_payment_allocation.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.request_key IS '分配幂等键';


--
-- Name: COLUMN asp_payment_allocation.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_payment_allocation.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_payment_allocation.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_payment_allocation.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_payment_allocation.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_payment_allocation.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_allocation.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_payment_exception; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_payment_exception (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    payment_id bigint,
    exception_type character varying(100) NOT NULL,
    status character varying(32) NOT NULL,
    owner_id bigint,
    resolution jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    obligation_id bigint,
    external_reference character varying(200),
    reported_amount numeric(18,2),
    CONSTRAINT asp_payment_exception_status_check CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'investigating'::character varying, 'resolved'::character varying, 'disputed'::character varying])::text[]))),
    CONSTRAINT asp_payment_exception_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_payment_exception_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_asp_payment_exception_amount CHECK (((reported_amount IS NULL) OR (reported_amount >= (0)::numeric))),
    CONSTRAINT ck_asp_payment_exception_target CHECK (((payment_id IS NOT NULL) OR (obligation_id IS NOT NULL)))
);


--
-- Name: TABLE asp_payment_exception; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_payment_exception IS '少付、多付、迟到款、重复款及无法定位款的处理队列；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_payment_exception.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_payment_exception.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_payment_exception.payment_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.payment_id IS '付款事实';


--
-- Name: COLUMN asp_payment_exception.exception_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.exception_type IS '明确资金异常类型';


--
-- Name: COLUMN asp_payment_exception.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.status IS '独立业务状态；合法值不等于业务已获批准：open investigating resolved disputed';


--
-- Name: COLUMN asp_payment_exception.owner_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.owner_id IS '实际处理责任人';


--
-- Name: COLUMN asp_payment_exception.resolution; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.resolution IS '核对和处置证据；必须按版本校验结构';


--
-- Name: COLUMN asp_payment_exception.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_payment_exception.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_payment_exception.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_payment_exception.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_payment_exception.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_payment_exception.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_payment_exception.obligation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.obligation_id IS '相关义务';


--
-- Name: COLUMN asp_payment_exception.external_reference; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.external_reference IS '外部单号';


--
-- Name: COLUMN asp_payment_exception.reported_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_payment_exception.reported_amount IS '申报金额';


--
-- Name: asp_person; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_person (
    id bigint NOT NULL,
    display_name character varying(100),
    birth_date date NOT NULL,
    gender character varying(32) NOT NULL,
    identity_hash character varying(128),
    identity_cipher character varying(1000),
    verification_status character varying(32) NOT NULL,
    status character varying(32) NOT NULL,
    merged_into_id bigint,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    legal_name character varying(100) NOT NULL,
    id_doc_type character varying(32),
    mobile character varying(20) NOT NULL,
    city character varying(100),
    address_detail character varying(200),
    blood_type character varying(32),
    clothing_size character varying(32),
    emergency_contact_name character varying(100),
    emergency_contact_phone character varying(20),
    CONSTRAINT asp_person_blood_type_check CHECK (((blood_type IS NULL) OR ((blood_type)::text = ANY ((ARRAY['A'::character varying, 'B'::character varying, 'AB'::character varying, 'O'::character varying, 'unknown'::character varying])::text[])))),
    CONSTRAINT asp_person_check CHECK (((merged_into_id IS NULL) OR (merged_into_id <> id))),
    CONSTRAINT asp_person_clothing_size_check CHECK (((clothing_size IS NULL) OR ((clothing_size)::text = ANY ((ARRAY['XS'::character varying, 'S'::character varying, 'M'::character varying, 'L'::character varying, 'XL'::character varying, 'XXL'::character varying, 'XXXL'::character varying])::text[])))),
    CONSTRAINT asp_person_emergency_phone_check CHECK (((emergency_contact_phone IS NULL) OR ((emergency_contact_phone)::text ~ '^1[3-9][0-9]{9}$'::text))),
    CONSTRAINT asp_person_gender_check CHECK (((gender)::text = ANY ((ARRAY['male'::character varying, 'female'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT asp_person_id_doc_type_check CHECK (((id_doc_type IS NULL) OR ((id_doc_type)::text = ANY ((ARRAY['id_card'::character varying, 'passport'::character varying, 'hmt_pass'::character varying, 'other'::character varying])::text[])))),
    CONSTRAINT asp_person_id_pair_check CHECK ((((id_doc_type IS NULL) = (identity_hash IS NULL)) AND ((identity_hash IS NULL) = (identity_cipher IS NULL)))),
    CONSTRAINT asp_person_mobile_check CHECK (((mobile)::text ~ '^1[3-9][0-9]{9}$'::text)),
    CONSTRAINT asp_person_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'restricted'::character varying, 'merged'::character varying, 'archived'::character varying])::text[]))),
    CONSTRAINT asp_person_verification_status_check CHECK (((verification_status)::text = ANY ((ARRAY['unverified'::character varying, 'pending'::character varying, 'verified'::character varying, 'disputed'::character varying])::text[]))),
    CONSTRAINT asp_person_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_person; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_person IS '稳定现实参赛人；个人资料更正不改写报名快照；来源：母版 D02；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_person.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_person.display_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.display_name IS '活动展示名；空则对外使用真实姓名';


--
-- Name: COLUMN asp_person.birth_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.birth_date IS '出生日期；必填。年龄按赛事自己的基准日判断';


--
-- Name: COLUMN asp_person.gender; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.gender IS '分组用性别；必填：male female other';


--
-- Name: COLUMN asp_person.identity_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.identity_hash IS '证件号码带密钥摘要；未填证件时为空';


--
-- Name: COLUMN asp_person.identity_cipher; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.identity_cipher IS '证件号码加密值；未填证件时为空';


--
-- Name: COLUMN asp_person.verification_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.verification_status IS '独立业务状态；合法值不等于业务已获批准：unverified pending verified disputed';


--
-- Name: COLUMN asp_person.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.status IS '独立业务状态；合法值不等于业务已获批准：active restricted merged archived';


--
-- Name: COLUMN asp_person.merged_into_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.merged_into_id IS '经批准合并目标；必须先核对业务影响';


--
-- Name: COLUMN asp_person.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_person.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_person.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_person.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_person.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_person.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_person.legal_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.legal_name IS '真实姓名；必填';


--
-- Name: COLUMN asp_person.id_doc_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.id_doc_type IS '证件类型：id_card passport hmt_pass other；可空';


--
-- Name: COLUMN asp_person.mobile; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.mobile IS '联系手机；必填。现在手工填写，以后可从已验证登录号带入。公开页不展示';


--
-- Name: COLUMN asp_person.city; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.city IS '所在城市；通用资料，可空';


--
-- Name: COLUMN asp_person.address_detail; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.address_detail IS '详细地址；通用资料，可空';


--
-- Name: COLUMN asp_person.blood_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.blood_type IS '血型：A B AB O unknown；通用资料，可空，不公开';


--
-- Name: COLUMN asp_person.clothing_size; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.clothing_size IS '衣服尺码：XS S M L XL XXL XXXL；通用资料，可空';


--
-- Name: COLUMN asp_person.emergency_contact_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.emergency_contact_name IS '紧急联系人；通用资料，可空';


--
-- Name: COLUMN asp_person.emergency_contact_phone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_person.emergency_contact_phone IS '紧急联系号码；通用资料，可空，不公开';


--
-- Name: asp_profile_display; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_profile_display (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    nickname character varying(40) NOT NULL,
    avatar_file_id bigint,
    avatar_style character varying(32) NOT NULL,
    tagline character varying(160),
    public_visible boolean DEFAULT false NOT NULL,
    sport_preferences jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_profile_display_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_profile_display; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_profile_display IS '公开运动名片与真实参赛档案分开；未选择公开时只向本人及必要队友展示';


--
-- Name: COLUMN asp_profile_display.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_profile_display.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.account_id IS '本人账号';


--
-- Name: COLUMN asp_profile_display.nickname; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.nickname IS '展示昵称，不回退真实姓名';


--
-- Name: COLUMN asp_profile_display.avatar_file_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.avatar_file_id IS '头像文件编号；用途受控';


--
-- Name: COLUMN asp_profile_display.avatar_style; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.avatar_style IS '内置头像样式';


--
-- Name: COLUMN asp_profile_display.tagline; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.tagline IS '运动签名';


--
-- Name: COLUMN asp_profile_display.public_visible; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.public_visible IS '本人选择对外公开';


--
-- Name: COLUMN asp_profile_display.sport_preferences; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.sport_preferences IS '偏好运动编号；不代表资格或实力；必须按版本校验结构';


--
-- Name: COLUMN asp_profile_display.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_profile_display.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_profile_display.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_profile_display.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_profile_display.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_profile_display.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_profile_display.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_qualification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_qualification (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    organization_id bigint NOT NULL,
    revision integer NOT NULL,
    proof_snapshot jsonb NOT NULL,
    business_scope jsonb NOT NULL,
    status character varying(32) NOT NULL,
    valid_from timestamp with time zone,
    valid_until timestamp with time zone,
    reviewer_id bigint,
    review_reason character varying(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_qualification_check CHECK (((valid_until IS NULL) OR (valid_from IS NULL) OR (valid_until > valid_from))),
    CONSTRAINT asp_qualification_revision_check CHECK ((revision > 0)),
    CONSTRAINT asp_qualification_revision_check1 CHECK ((revision >= 0)),
    CONSTRAINT asp_qualification_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'pending'::character varying, 'correction'::character varying, 'approved'::character varying, 'rejected'::character varying, 'expired'::character varying, 'restricted'::character varying])::text[]))),
    CONSTRAINT asp_qualification_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_qualification_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_qualification; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_qualification IS '组织资质申请及审核版本；失效不删除未完责任；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_qualification.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_qualification.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_qualification.organization_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.organization_id IS '申请主体';


--
-- Name: COLUMN asp_qualification.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.revision IS '申请版本';


--
-- Name: COLUMN asp_qualification.proof_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.proof_snapshot IS '审核时材料与经办授权；必须按版本校验结构';


--
-- Name: COLUMN asp_qualification.business_scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.business_scope IS '可办业务范围；必须按版本校验结构';


--
-- Name: COLUMN asp_qualification.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.status IS '独立业务状态；合法值不等于业务已获批准：draft pending correction approved rejected expired restricted';


--
-- Name: COLUMN asp_qualification.valid_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.valid_from IS '有效开始；有时区业务时间';


--
-- Name: COLUMN asp_qualification.valid_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.valid_until IS '有效截止；有时区业务时间';


--
-- Name: COLUMN asp_qualification.reviewer_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.reviewer_id IS '平台审核人后台账号';


--
-- Name: COLUMN asp_qualification.review_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.review_reason IS '结论依据';


--
-- Name: COLUMN asp_qualification.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_qualification.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_qualification.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_qualification.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_qualification.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_qualification.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_qualification_review; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_qualification_review (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    registration_id bigint NOT NULL,
    roster_member_id bigint,
    decision character varying(32) NOT NULL,
    basis jsonb NOT NULL,
    reviewer_id bigint,
    reviewed_at timestamp with time zone NOT NULL,
    reason character varying(1000) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_qualification_review_decision_check CHECK (((decision)::text = ANY ((ARRAY['supplement'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[]))),
    CONSTRAINT asp_qualification_review_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_qualification_review_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_qualification_review; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_qualification_review IS '逐成员/整单审核记录；材料与到账不互相替代；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_qualification_review.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_qualification_review.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_qualification_review.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.registration_id IS '报名';


--
-- Name: COLUMN asp_qualification_review.roster_member_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.roster_member_id IS '审核成员；整单可为空';


--
-- Name: COLUMN asp_qualification_review.decision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.decision IS '独立业务状态；合法值不等于业务已获批准：supplement approved rejected';


--
-- Name: COLUMN asp_qualification_review.basis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.basis IS '所见名单/材料/费用及规则版本；必须按版本校验结构';


--
-- Name: COLUMN asp_qualification_review.reviewer_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.reviewer_id IS '审核后台账号。无需审核的自动通过为空，不伪造人工审核人';


--
-- Name: COLUMN asp_qualification_review.reviewed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.reviewed_at IS '确认时间；有时区业务时间';


--
-- Name: COLUMN asp_qualification_review.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.reason IS '具体结论依据';


--
-- Name: COLUMN asp_qualification_review.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_qualification_review.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_qualification_review.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_qualification_review.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_qualification_review.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_qualification_review.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_qualification_review.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_ranking_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_ranking_item (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    ranking_run_id bigint NOT NULL,
    registration_id bigint NOT NULL,
    rank integer NOT NULL,
    comparison_values jsonb NOT NULL,
    explanation character varying(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_ranking_item_rank_check CHECK ((rank > 0)),
    CONSTRAINT asp_ranking_item_rank_check1 CHECK ((rank >= 0)),
    CONSTRAINT asp_ranking_item_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_ranking_item_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_ranking_item; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_ranking_item IS '有范围的个人或参赛单位名次；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_ranking_item.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_ranking_item.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_ranking_item.ranking_run_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.ranking_run_id IS '排名运行';


--
-- Name: COLUMN asp_ranking_item.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.registration_id IS '参赛单位';


--
-- Name: COLUMN asp_ranking_item.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.rank IS '允许并列的名次';


--
-- Name: COLUMN asp_ranking_item.comparison_values; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.comparison_values IS '独立复算需要的原值和单位；必须按版本校验结构';


--
-- Name: COLUMN asp_ranking_item.explanation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.explanation IS '并列/取消/规则说明';


--
-- Name: COLUMN asp_ranking_item.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_ranking_item.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_ranking_item.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_ranking_item.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_ranking_item.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_ranking_item.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_item.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_ranking_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_ranking_run (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    unit_id bigint NOT NULL,
    rule_version_id bigint NOT NULL,
    revision integer NOT NULL,
    input_results jsonb NOT NULL,
    comparison_rules jsonb NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_ranking_run_revision_check CHECK ((revision >= 0)),
    CONSTRAINT asp_ranking_run_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'confirmed'::character varying, 'published'::character varying, 'superseded'::character varying])::text[]))),
    CONSTRAINT asp_ranking_run_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_ranking_run_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_ranking_run; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_ranking_run IS '排名计算输入与同分规则版本；可独立复算；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_ranking_run.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_ranking_run.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_ranking_run.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.unit_id IS '统计单元';


--
-- Name: COLUMN asp_ranking_run.rule_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.rule_version_id IS '排名规则';


--
-- Name: COLUMN asp_ranking_run.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.revision IS '排名版本';


--
-- Name: COLUMN asp_ranking_run.input_results; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.input_results IS '有效原始结果引用与处罚；必须按版本校验结构';


--
-- Name: COLUMN asp_ranking_run.comparison_rules; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.comparison_rules IS '比较顺序、范围和并列；必须按版本校验结构';


--
-- Name: COLUMN asp_ranking_run.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.status IS '独立业务状态；合法值不等于业务已获批准：draft confirmed published superseded';


--
-- Name: COLUMN asp_ranking_run.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_ranking_run.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_ranking_run.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_ranking_run.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_ranking_run.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_ranking_run.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_ranking_run.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_recruitment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_recruitment (
    id bigint NOT NULL,
    room_id bigint NOT NULL,
    creator_account_id bigint NOT NULL,
    message character varying(500) NOT NULL,
    status character varying(32) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_recruitment_status_check CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'filled'::character varying, 'closed'::character varying])::text[]))),
    CONSTRAINT asp_recruitment_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_recruitment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_recruitment IS '缺员招募；只展示受控运动名片，不公开私有联系与材料';


--
-- Name: COLUMN asp_recruitment.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_recruitment.room_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.room_id IS '招募房间';


--
-- Name: COLUMN asp_recruitment.creator_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.creator_account_id IS '发布人';


--
-- Name: COLUMN asp_recruitment.message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.message IS '招募介绍';


--
-- Name: COLUMN asp_recruitment.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.status IS '独立业务状态；合法值不等于业务已获批准：open filled closed';


--
-- Name: COLUMN asp_recruitment.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.expires_at IS '招募截止；有时区业务时间';


--
-- Name: COLUMN asp_recruitment.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_recruitment.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_recruitment.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_recruitment.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_recruitment.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_recruitment.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_recruitment.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_refund; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_refund (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    payment_id bigint NOT NULL,
    allocation_id bigint,
    withdrawal_id bigint,
    applicant_account_id bigint,
    requested_amount numeric(18,2) NOT NULL,
    approved_amount numeric(18,2),
    completed_amount numeric(18,2),
    status character varying(32) NOT NULL,
    channel_reference character varying(200),
    reason character varying(1000) NOT NULL,
    request_key character varying(128) NOT NULL,
    completed_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    recipient_name character varying(200),
    recipient_basis character varying(1000),
    CONSTRAINT asp_refund_approved_amount_check CHECK ((approved_amount >= (0)::numeric)),
    CONSTRAINT asp_refund_check CHECK (((approved_amount IS NULL) OR (approved_amount <= requested_amount))),
    CONSTRAINT asp_refund_check1 CHECK (((completed_amount IS NULL) OR ((approved_amount IS NOT NULL) AND (completed_amount <= approved_amount)))),
    CONSTRAINT asp_refund_completed_amount_check CHECK ((completed_amount >= (0)::numeric)),
    CONSTRAINT asp_refund_requested_amount_check CHECK ((requested_amount >= (0)::numeric)),
    CONSTRAINT asp_refund_status_check CHECK (((status)::text = ANY ((ARRAY['requested'::character varying, 'approved'::character varying, 'rejected'::character varying, 'executing'::character varying, 'completed'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT asp_refund_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_refund_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_refund; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_refund IS '已经发生的退款事实。不是平台发起的退款申请';


--
-- Name: COLUMN asp_refund.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_refund.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_refund.payment_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.payment_id IS '原实际付款';


--
-- Name: COLUMN asp_refund.allocation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.allocation_id IS '被退服务分配';


--
-- Name: COLUMN asp_refund.withdrawal_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.withdrawal_id IS '相关退赛';


--
-- Name: COLUMN asp_refund.applicant_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.applicant_account_id IS '申请者';


--
-- Name: COLUMN asp_refund.requested_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.requested_amount IS '申请金额；人民币元，不能用浮点';


--
-- Name: COLUMN asp_refund.approved_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.approved_amount IS '批准金额；人民币元，不能用浮点';


--
-- Name: COLUMN asp_refund.completed_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.completed_amount IS '已核实退款金额；人民币元，不能用浮点';


--
-- Name: COLUMN asp_refund.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.status IS '独立业务状态；合法值不等于业务已获批准：requested approved rejected executing completed failed';


--
-- Name: COLUMN asp_refund.channel_reference; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.channel_reference IS '渠道退款唯一号';


--
-- Name: COLUMN asp_refund.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.reason IS '规则和退款责任依据';


--
-- Name: COLUMN asp_refund.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.request_key IS '幂等键';


--
-- Name: COLUMN asp_refund.completed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.completed_at IS '实际核实到账；有时区业务时间';


--
-- Name: COLUMN asp_refund.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_refund.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_refund.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_refund.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_refund.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_refund.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_refund.recipient_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.recipient_name IS '实际退款接收人；旧事实未采集可空，不推断补造';


--
-- Name: COLUMN asp_refund.recipient_basis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_refund.recipient_basis IS '与原付款人不同的核验授权依据，限资金用途访问';


--
-- Name: asp_registration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_registration (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    unit_id bigint NOT NULL,
    rule_version_id bigint,
    fee_policy_id bigint,
    batch_id bigint,
    team_id bigint,
    submitter_account_id bigint NOT NULL,
    operator_account_id bigint NOT NULL,
    request_key character varying(128) NOT NULL,
    status character varying(32) NOT NULL,
    hold_expires_at timestamp with time zone,
    roster_revision integer NOT NULL,
    team_name_snapshot character varying(200),
    submitted_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    manager_account_id bigint,
    CONSTRAINT asp_registration_roster_revision_check CHECK ((roster_revision >= 0)),
    CONSTRAINT asp_registration_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_registration_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_asp_registration_status CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'submitted'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[])))
);


--
-- Name: TABLE asp_registration; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_registration IS '竞赛单元报名。草稿不占名额；已提交和已通过占名额；撤回回到草稿；来源：母版 D05；同一提交人在同一单元只有一条报名。代表队伍的报名按 team_id 识别当前可办理的那一条，不另加一队一单元的唯一约束。已经完成提交的请求键只重放该次事实，不第二次占名额，撤回后也不复活报名。名额排队使用通用锁，used_count 只做上限。';


--
-- Name: COLUMN asp_registration.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_registration.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_registration.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.unit_id IS '报名单元';


--
-- Name: COLUMN asp_registration.rule_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.rule_version_id IS '提交时规则。本期可空，不临时造规则版本';


--
-- Name: COLUMN asp_registration.fee_policy_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.fee_policy_id IS '费用依据';


--
-- Name: COLUMN asp_registration.batch_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.batch_id IS '操作批次';


--
-- Name: COLUMN asp_registration.team_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.team_id IS '可选长期代表队。空表示个人或临时双打';


--
-- Name: COLUMN asp_registration.submitter_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.submitter_account_id IS '原提交人';


--
-- Name: COLUMN asp_registration.operator_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.operator_account_id IS '当前办理人';


--
-- Name: COLUMN asp_registration.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.request_key IS '当前办理请求键。尚未完成提交时沿用创建键；完成后的重放不再占用，主动重提更换新键';


--
-- Name: COLUMN asp_registration.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.status IS 'draft submitted approved rejected。撤回回到草稿';


--
-- Name: COLUMN asp_registration.hold_expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.hold_expires_at IS '旧的临时占位期限。本期不使用';


--
-- Name: COLUMN asp_registration.roster_revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.roster_revision IS '当前名单版本';


--
-- Name: COLUMN asp_registration.team_name_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.team_name_snapshot IS '提交成功时的队名。之后队伍改名不回写';


--
-- Name: COLUMN asp_registration.submitted_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.submitted_at IS '实际提交时间。草稿可空';


--
-- Name: COLUMN asp_registration.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_registration.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_registration.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_registration.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_registration.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_registration.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_registration_batch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_registration_batch (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    submitter_account_id bigint NOT NULL,
    request_key character varying(128) NOT NULL,
    status character varying(32) NOT NULL,
    total_count integer NOT NULL,
    success_count integer NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_registration_batch_check CHECK ((success_count <= total_count)),
    CONSTRAINT asp_registration_batch_status_check CHECK (((status)::text = ANY ((ARRAY['processing'::character varying, 'completed'::character varying, 'partial'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT asp_registration_batch_success_count_check CHECK ((success_count >= 0)),
    CONSTRAINT asp_registration_batch_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_registration_batch_total_count_check CHECK ((total_count >= 0)),
    CONSTRAINT asp_registration_batch_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_registration_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_registration_batch IS '领队提交批次；不等于一笔订单；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_registration_batch.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_registration_batch.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_registration_batch.submitter_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.submitter_account_id IS '提交人';


--
-- Name: COLUMN asp_registration_batch.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.request_key IS '请求幂等键';


--
-- Name: COLUMN asp_registration_batch.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.status IS '独立业务状态；合法值不等于业务已获批准：processing completed partial failed';


--
-- Name: COLUMN asp_registration_batch.total_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.total_count IS '提交条目数';


--
-- Name: COLUMN asp_registration_batch.success_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.success_count IS '成功条目数';


--
-- Name: COLUMN asp_registration_batch.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_registration_batch.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_registration_batch.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_registration_batch.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_registration_batch.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_registration_batch.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_batch.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_registration_member; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_registration_member (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    registration_id bigint NOT NULL,
    unit_id bigint NOT NULL,
    account_id bigint NOT NULL,
    person_id bigint,
    status character varying(32) NOT NULL,
    self_member boolean DEFAULT false NOT NULL,
    invite_token character varying(64),
    person_snapshot jsonb,
    occupying boolean DEFAULT false NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_registration_member_check CHECK (((occupying = false) OR ((status)::text = 'confirmed'::text))),
    CONSTRAINT asp_registration_member_status_check CHECK (((status)::text = ANY ((ARRAY['pending_confirmation'::character varying, 'confirmed'::character varying, 'declined'::character varying])::text[]))),
    CONSTRAINT asp_registration_member_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_registration_member_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_registration_member; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_registration_member IS '报名成员确认。按平台账号记录，提交成功后才抄入名单快照';


--
-- Name: COLUMN asp_registration_member.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_registration_member.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_registration_member.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.registration_id IS '报名';


--
-- Name: COLUMN asp_registration_member.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.unit_id IS '竞赛单元。冗余，用于同一人同一单元只有一条有效报名';


--
-- Name: COLUMN asp_registration_member.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.account_id IS '成员平台账号';


--
-- Name: COLUMN asp_registration_member.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.person_id IS '确认时的本人档案。待确认时可空';


--
-- Name: COLUMN asp_registration_member.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.status IS 'pending_confirmation confirmed declined';


--
-- Name: COLUMN asp_registration_member.self_member; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.self_member IS 'true 表示报名提交人本人';


--
-- Name: COLUMN asp_registration_member.invite_token; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.invite_token IS '邀请确认令牌。本人成员为空';


--
-- Name: COLUMN asp_registration_member.person_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.person_snapshot IS '确认时抄下的档案。提交名单时使用，之后改档案不回写';


--
-- Name: COLUMN asp_registration_member.occupying; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.occupying IS 'true 表示这条成员正在占用该单元的有效报名';


--
-- Name: COLUMN asp_registration_member.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_registration_member.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_registration_member.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_registration_member.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_registration_member.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_registration_member.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_member.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_registration_payment_proof; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_registration_payment_proof (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    registration_id bigint NOT NULL,
    obligation_id bigint NOT NULL,
    uploaded_by_account_id bigint NOT NULL,
    file_id bigint NOT NULL,
    request_key character varying(128) NOT NULL,
    content_digest character varying(64) NOT NULL,
    uploaded_at timestamp with time zone NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_registration_payment_proof_content_digest_check CHECK ((length((content_digest)::text) = 64)),
    CONSTRAINT asp_registration_payment_proof_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_registration_payment_proof_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_registration_payment_proof; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_registration_payment_proof IS '报名管理人自愿上传的私有付款图片。只关联一次提交的义务，不代表到账，撤回重提不沿用；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_registration_payment_proof.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_registration_payment_proof.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_registration_payment_proof.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.registration_id IS '凭证所属报名';


--
-- Name: COLUMN asp_registration_payment_proof.obligation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.obligation_id IS '本次提交的付款义务';


--
-- Name: COLUMN asp_registration_payment_proof.uploaded_by_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.uploaded_by_account_id IS '本人或当前队长的上传账号';


--
-- Name: COLUMN asp_registration_payment_proof.file_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.file_id IS '私有 payment-proof 图片，金融敏感材料，不公开 URL';


--
-- Name: COLUMN asp_registration_payment_proof.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.request_key IS '上传幂等键，同键不能更换内容';


--
-- Name: COLUMN asp_registration_payment_proof.content_digest; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.content_digest IS '图片 SHA-256，用于重复请求核验';


--
-- Name: COLUMN asp_registration_payment_proof.uploaded_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.uploaded_at IS '上传完成时间，不是到账时间；有时区业务时间';


--
-- Name: COLUMN asp_registration_payment_proof.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_registration_payment_proof.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_registration_payment_proof.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_registration_payment_proof.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_registration_payment_proof.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_registration_payment_proof.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_payment_proof.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_registration_submit_key; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_registration_submit_key (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    registration_id bigint NOT NULL,
    submitter_account_id bigint NOT NULL,
    request_key character varying(128) NOT NULL,
    roster_revision integer NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_registration_submit_key_roster_revision_check CHECK ((roster_revision > 0)),
    CONSTRAINT asp_registration_submit_key_roster_revision_check1 CHECK ((roster_revision >= 0)),
    CONSTRAINT asp_registration_submit_key_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_registration_submit_key_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_registration_submit_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_registration_submit_key IS '已经完成的报名提交请求键。撤回或拒绝后重放旧键不得再次占用；来源：母版 D05；同一提交人的一个请求键只完成一次提交。主动重提使用新键并另记一行，对应这次的名单版本和独立付款义务。未完成提交的创建键不记入本表。';


--
-- Name: COLUMN asp_registration_submit_key.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_registration_submit_key.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_registration_submit_key.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.registration_id IS '报名';


--
-- Name: COLUMN asp_registration_submit_key.submitter_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.submitter_account_id IS '提交人';


--
-- Name: COLUMN asp_registration_submit_key.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.request_key IS '已经完成一次提交的请求键';


--
-- Name: COLUMN asp_registration_submit_key.roster_revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.roster_revision IS '这次提交冻结的名单版本';


--
-- Name: COLUMN asp_registration_submit_key.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_registration_submit_key.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_registration_submit_key.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_registration_submit_key.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_registration_submit_key.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_registration_submit_key.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_registration_submit_key.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_resource; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_resource (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    venue_id bigint NOT NULL,
    parent_id bigint,
    name character varying(200) NOT NULL,
    resource_type character varying(100) NOT NULL,
    capacity integer NOT NULL,
    capacity_unit character varying(100) NOT NULL,
    status character varying(32) NOT NULL,
    sport_scope jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_resource_capacity_check CHECK ((capacity > 0)),
    CONSTRAINT asp_resource_capacity_check1 CHECK ((capacity >= 0)),
    CONSTRAINT asp_resource_check CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT asp_resource_status_check CHECK (((status)::text = ANY ((ARRAY['available'::character varying, 'unconfirmed'::character varying, 'maintenance'::character varying, 'disabled'::character varying])::text[]))),
    CONSTRAINT asp_resource_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_resource_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_resource; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_resource IS '可分配资源单元及容量；整体和半场不能重复占用；来源：母版 D12；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_resource.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_resource.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_resource.venue_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.venue_id IS '场馆';


--
-- Name: COLUMN asp_resource.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.parent_id IS '整体/拆分父资源';


--
-- Name: COLUMN asp_resource.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.name IS '场地或泳道等名称';


--
-- Name: COLUMN asp_resource.resource_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.resource_type IS 'court/table/lane/track/judge_group 等';


--
-- Name: COLUMN asp_resource.capacity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.capacity IS '可同时使用容量';


--
-- Name: COLUMN asp_resource.capacity_unit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.capacity_unit IS '容量单位';


--
-- Name: COLUMN asp_resource.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.status IS '独立业务状态；合法值不等于业务已获批准：available unconfirmed maintenance disabled';


--
-- Name: COLUMN asp_resource.sport_scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.sport_scope IS '运动适配及必要限制；必须按版本校验结构';


--
-- Name: COLUMN asp_resource.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_resource.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_resource.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_resource.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_resource.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_resource.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_resource_reservation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_resource_reservation (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    resource_id bigint NOT NULL,
    event_id bigint NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    quantity integer NOT NULL,
    status character varying(32) NOT NULL,
    confirmation jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_resource_reservation_check CHECK ((ends_at > starts_at)),
    CONSTRAINT asp_resource_reservation_quantity_check CHECK ((quantity > 0)),
    CONSTRAINT asp_resource_reservation_quantity_check1 CHECK ((quantity >= 0)),
    CONSTRAINT asp_resource_reservation_status_check CHECK (((status)::text = ANY ((ARRAY['requested'::character varying, 'confirmed'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT asp_resource_reservation_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_resource_reservation_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_resource_reservation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_resource_reservation IS '赛事资源使用确认；不冒充商业预约交易；来源：母版 D12；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_resource_reservation.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_resource_reservation.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_resource_reservation.resource_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.resource_id IS '具体资源';


--
-- Name: COLUMN asp_resource_reservation.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.event_id IS '赛事';


--
-- Name: COLUMN asp_resource_reservation.starts_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.starts_at IS '使用开始；有时区业务时间';


--
-- Name: COLUMN asp_resource_reservation.ends_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.ends_at IS '使用结束；有时区业务时间';


--
-- Name: COLUMN asp_resource_reservation.quantity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.quantity IS '占用容量';


--
-- Name: COLUMN asp_resource_reservation.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.status IS '独立业务状态；合法值不等于业务已获批准：requested confirmed cancelled';


--
-- Name: COLUMN asp_resource_reservation.confirmation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.confirmation IS '场地方和赛事方确认依据；必须按版本校验结构';


--
-- Name: COLUMN asp_resource_reservation.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_resource_reservation.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_resource_reservation.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_resource_reservation.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_resource_reservation.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_resource_reservation.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_resource_reservation.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_result_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_result_item (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    result_version_id bigint NOT NULL,
    match_entry_id bigint NOT NULL,
    performance_status character varying(32) NOT NULL,
    value numeric(20,6),
    unit character varying(100),
    components jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_result_item_performance_status_check CHECK (((performance_status)::text = ANY ((ARRAY['valid'::character varying, 'did_not_start'::character varying, 'did_not_finish'::character varying, 'forfeited'::character varying, 'disqualified'::character varying, 'invalid'::character varying])::text[]))),
    CONSTRAINT asp_result_item_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_result_item_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_result_item; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_result_item IS '每参赛单位原始成绩及单位；零与缺失/未完赛分开；来源：母版 D10；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_result_item.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_result_item.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_result_item.result_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.result_version_id IS '结果版本';


--
-- Name: COLUMN asp_result_item.match_entry_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.match_entry_id IS '实际参赛单位';


--
-- Name: COLUMN asp_result_item.performance_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.performance_status IS '独立业务状态；合法值不等于业务已获批准：valid did_not_start did_not_finish forfeited disqualified invalid';


--
-- Name: COLUMN asp_result_item.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.value IS '可比较主数值；分项另存，缺失不是零';


--
-- Name: COLUMN asp_result_item.unit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.unit IS 'second/metre/point/kg 等确认单位';


--
-- Name: COLUMN asp_result_item.components; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.components IS '局、试次、裁判分项和处罚；必须按版本校验结构';


--
-- Name: COLUMN asp_result_item.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_result_item.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_result_item.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_result_item.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_result_item.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_result_item.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_item.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_result_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_result_version (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    match_id bigint NOT NULL,
    revision integer NOT NULL,
    previous_id bigint,
    status character varying(32) NOT NULL,
    raw_performance jsonb NOT NULL,
    decision jsonb NOT NULL,
    confirmer_id bigint,
    confirmed_at timestamp with time zone,
    published_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_result_version_check CHECK (((previous_id IS NULL) OR (previous_id <> id))),
    CONSTRAINT asp_result_version_revision_check CHECK ((revision > 0)),
    CONSTRAINT asp_result_version_revision_check1 CHECK ((revision >= 0)),
    CONSTRAINT asp_result_version_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'confirmed'::character varying, 'appealed'::character varying, 'published'::character varying, 'superseded'::character varying, 'void'::character varying])::text[]))),
    CONSTRAINT asp_result_version_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_result_version_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_result_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_result_version IS '原始表现、有效性、专业确认及修订链；来源：母版 D10；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_result_version.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_result_version.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_result_version.match_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.match_id IS '比赛';


--
-- Name: COLUMN asp_result_version.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.revision IS '结果版本';


--
-- Name: COLUMN asp_result_version.previous_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.previous_id IS '更正前版本';


--
-- Name: COLUMN asp_result_version.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.status IS '独立业务状态；合法值不等于业务已获批准：draft confirmed appealed published superseded void';


--
-- Name: COLUMN asp_result_version.raw_performance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.raw_performance IS '比分/计时/计量/评分等原始分项；必须按版本校验结构';


--
-- Name: COLUMN asp_result_version.decision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.decision IS '弃权、处罚、取消及结果专业依据；必须按版本校验结构';


--
-- Name: COLUMN asp_result_version.confirmer_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.confirmer_id IS '有权确认人员';


--
-- Name: COLUMN asp_result_version.confirmed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.confirmed_at IS '确认；有时区业务时间';


--
-- Name: COLUMN asp_result_version.published_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.published_at IS '发布；有时区业务时间';


--
-- Name: COLUMN asp_result_version.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_result_version.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_result_version.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_result_version.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_result_version.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_result_version.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_result_version.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_room_interaction; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_room_interaction (
    id bigint NOT NULL,
    room_id bigint NOT NULL,
    account_id bigint NOT NULL,
    kind character varying(32) NOT NULL,
    text character varying(500) NOT NULL,
    request_key character varying(128) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_room_interaction_kind_check CHECK (((kind)::text = ANY ((ARRAY['welcome'::character varying, 'encourage'::character varying, 'ready'::character varying, 'announcement'::character varying])::text[]))),
    CONSTRAINT asp_room_interaction_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_room_interaction; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_room_interaction IS '房间内可见欢迎与鼓励；不是社区或私聊平台';


--
-- Name: COLUMN asp_room_interaction.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_room_interaction.room_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.room_id IS '房间';


--
-- Name: COLUMN asp_room_interaction.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.account_id IS '发送人';


--
-- Name: COLUMN asp_room_interaction.kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.kind IS '独立业务状态；合法值不等于业务已获批准：welcome encourage ready announcement';


--
-- Name: COLUMN asp_room_interaction.text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.text IS '可见消息';


--
-- Name: COLUMN asp_room_interaction.request_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.request_key IS '防重键';


--
-- Name: COLUMN asp_room_interaction.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_room_interaction.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_room_interaction.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_room_interaction.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_room_interaction.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_room_interaction.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_room_interaction.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_roster_member; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_roster_member (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    roster_version_id bigint NOT NULL,
    person_id bigint NOT NULL,
    role character varying(32) NOT NULL,
    person_snapshot jsonb NOT NULL,
    qualification_status character varying(32) NOT NULL,
    "position" integer,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_roster_member_position_check CHECK (("position" >= 0)),
    CONSTRAINT asp_roster_member_qualification_status_check CHECK (((qualification_status)::text = ANY ((ARRAY['pending'::character varying, 'supplement'::character varying, 'approved'::character varying, 'rejected'::character varying, 'restricted'::character varying])::text[]))),
    CONSTRAINT asp_roster_member_role_check CHECK (((role)::text = ANY ((ARRAY['starter'::character varying, 'substitute'::character varying, 'leader'::character varying])::text[]))),
    CONSTRAINT asp_roster_member_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_roster_member_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_roster_member; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_roster_member IS '名单内实际参赛人及资格快照；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_roster_member.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_roster_member.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_roster_member.roster_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.roster_version_id IS '名单版本';


--
-- Name: COLUMN asp_roster_member.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.person_id IS '现实选手';


--
-- Name: COLUMN asp_roster_member.role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.role IS '独立业务状态；合法值不等于业务已获批准：starter substitute leader';


--
-- Name: COLUMN asp_roster_member.person_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.person_snapshot IS '报名必要身份、年龄及代表资格；敏感字段受控；必须按版本校验结构';


--
-- Name: COLUMN asp_roster_member.qualification_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.qualification_status IS '独立业务状态；合法值不等于业务已获批准：pending supplement approved rejected restricted';


--
-- Name: COLUMN asp_roster_member."position"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member."position" IS '顺序或位置；0 是否适用由规则解释';


--
-- Name: COLUMN asp_roster_member.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_roster_member.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_roster_member.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_roster_member.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_roster_member.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_roster_member.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_member.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_roster_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_roster_version (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    registration_id bigint NOT NULL,
    revision integer NOT NULL,
    rule_version_id bigint,
    status character varying(32) NOT NULL,
    effective_at timestamp with time zone,
    change_reason character varying(1000) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_roster_version_revision_check CHECK ((revision > 0)),
    CONSTRAINT asp_roster_version_revision_check1 CHECK ((revision >= 0)),
    CONSTRAINT asp_roster_version_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'effective'::character varying, 'frozen'::character varying, 'superseded'::character varying])::text[]))),
    CONSTRAINT asp_roster_version_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_roster_version_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_roster_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_roster_version IS '赛事报名名单版本；替补和冻结依据；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_roster_version.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_roster_version.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_roster_version.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.registration_id IS '报名';


--
-- Name: COLUMN asp_roster_version.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.revision IS '名单版本';


--
-- Name: COLUMN asp_roster_version.rule_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.rule_version_id IS '核验规则。本期报名可空';


--
-- Name: COLUMN asp_roster_version.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.status IS '独立业务状态；合法值不等于业务已获批准：draft effective frozen superseded';


--
-- Name: COLUMN asp_roster_version.effective_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.effective_at IS '名单生效；有时区业务时间';


--
-- Name: COLUMN asp_roster_version.change_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.change_reason IS '换人/补员/冻结依据';


--
-- Name: COLUMN asp_roster_version.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_roster_version.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_roster_version.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_roster_version.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_roster_version.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_roster_version.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_roster_version.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_rule_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_rule_version (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    unit_id bigint NOT NULL,
    revision integer NOT NULL,
    source character varying(1000) NOT NULL,
    parameters jsonb NOT NULL,
    status character varying(32) NOT NULL,
    verification_level character varying(32) NOT NULL,
    confirmed_by bigint,
    confirmed_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_rule_version_revision_check CHECK ((revision > 0)),
    CONSTRAINT asp_rule_version_revision_check1 CHECK ((revision >= 0)),
    CONSTRAINT asp_rule_version_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'confirmed'::character varying, 'retired'::character varying])::text[]))),
    CONSTRAINT asp_rule_version_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_rule_version_verification_level_check CHECK (((verification_level)::text = ANY ((ARRAY['unverified'::character varying, 'samples_verified'::character varying, 'professional_verified'::character varying])::text[]))),
    CONSTRAINT asp_rule_version_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_rule_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_rule_version IS '资格、赛制、晋级和排名规则版本与专业来源；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_rule_version.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_rule_version.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_rule_version.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.unit_id IS '适用竞赛单元';


--
-- Name: COLUMN asp_rule_version.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.revision IS '规则版本';


--
-- Name: COLUMN asp_rule_version.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.source IS '专业/地方/特别规程来源';


--
-- Name: COLUMN asp_rule_version.parameters; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.parameters IS '结构化规则；不得猜测缺项；必须按版本校验结构';


--
-- Name: COLUMN asp_rule_version.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.status IS '独立业务状态；合法值不等于业务已获批准：draft confirmed retired';


--
-- Name: COLUMN asp_rule_version.verification_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.verification_level IS '独立业务状态；合法值不等于业务已获批准：unverified samples_verified professional_verified';


--
-- Name: COLUMN asp_rule_version.confirmed_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.confirmed_by IS '有权确认人';


--
-- Name: COLUMN asp_rule_version.confirmed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.confirmed_at IS '确认时间；有时区业务时间';


--
-- Name: COLUMN asp_rule_version.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_rule_version.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_rule_version.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_rule_version.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_rule_version.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_rule_version.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_rule_version.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_schedule_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_schedule_run (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    stage_id bigint NOT NULL,
    draw_run_id bigint,
    revision integer NOT NULL,
    input_snapshot jsonb NOT NULL,
    diagnostics jsonb NOT NULL,
    status character varying(32) NOT NULL,
    published_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_schedule_run_revision_check CHECK ((revision >= 0)),
    CONSTRAINT asp_schedule_run_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'feasible'::character varying, 'infeasible'::character varying, 'published'::character varying, 'superseded'::character varying])::text[]))),
    CONSTRAINT asp_schedule_run_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_schedule_run_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_schedule_run; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_schedule_run IS '约束编排草案、不可行原因及发布版本；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_schedule_run.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_schedule_run.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_schedule_run.stage_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.stage_id IS '阶段';


--
-- Name: COLUMN asp_schedule_run.draw_run_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.draw_run_id IS '抽签依据';


--
-- Name: COLUMN asp_schedule_run.revision; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.revision IS '排程版本';


--
-- Name: COLUMN asp_schedule_run.input_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.input_snapshot IS '规则、人员、资源、窗口、时长和缓冲；必须按版本校验结构';


--
-- Name: COLUMN asp_schedule_run.diagnostics; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.diagnostics IS '已排/未排/冲突及取舍；必须按版本校验结构';


--
-- Name: COLUMN asp_schedule_run.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.status IS '独立业务状态；合法值不等于业务已获批准：draft feasible infeasible published superseded';


--
-- Name: COLUMN asp_schedule_run.published_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.published_at IS '生效发布；有时区业务时间';


--
-- Name: COLUMN asp_schedule_run.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_schedule_run.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_schedule_run.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_schedule_run.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_schedule_run.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_schedule_run.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_schedule_run.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_service_fee; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_service_fee (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint NOT NULL,
    contract_reference character varying(200) NOT NULL,
    calculation_basis jsonb NOT NULL,
    amount numeric(18,2) NOT NULL,
    status character varying(32) NOT NULL,
    confirmed_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_service_fee_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT asp_service_fee_status_check CHECK (((status)::text = ANY ((ARRAY['calculated'::character varying, 'confirmed'::character varying, 'reversed'::character varying])::text[]))),
    CONSTRAINT asp_service_fee_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_service_fee_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_service_fee; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_service_fee IS '平台服务收入依据；不能将报名流水认作平台收入；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_service_fee.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_service_fee.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_service_fee.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.event_id IS '赛事';


--
-- Name: COLUMN asp_service_fee.contract_reference; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.contract_reference IS '真实服务及合同依据';


--
-- Name: COLUMN asp_service_fee.calculation_basis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.calculation_basis IS '固定额/基数/费率/税及退费政策；必须按版本校验结构';


--
-- Name: COLUMN asp_service_fee.amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.amount IS '确认服务费；人民币元，不能用浮点';


--
-- Name: COLUMN asp_service_fee.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.status IS '独立业务状态；合法值不等于业务已获批准：calculated confirmed reversed';


--
-- Name: COLUMN asp_service_fee.confirmed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.confirmed_at IS '收入核对；有时区业务时间';


--
-- Name: COLUMN asp_service_fee.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_service_fee.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_service_fee.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_service_fee.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_service_fee.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_service_fee.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_service_fee.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_settlement; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_settlement (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    event_id bigint NOT NULL,
    subject character varying(200) NOT NULL,
    due_amount numeric(18,2) NOT NULL,
    settled_amount numeric(18,2) NOT NULL,
    status character varying(32) NOT NULL,
    evidence jsonb NOT NULL,
    reference character varying(200) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_settlement_check CHECK ((settled_amount <= due_amount)),
    CONSTRAINT asp_settlement_due_amount_check CHECK ((due_amount >= (0)::numeric)),
    CONSTRAINT asp_settlement_settled_amount_check CHECK ((settled_amount >= (0)::numeric)),
    CONSTRAINT asp_settlement_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'partial'::character varying, 'completed'::character varying, 'failed'::character varying, 'disputed'::character varying])::text[]))),
    CONSTRAINT asp_settlement_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_settlement_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_settlement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_settlement IS '收款方或支付机构结算证据；记账不证明已结算；来源：母版 D06；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_settlement.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_settlement.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_settlement.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.event_id IS '赛事';


--
-- Name: COLUMN asp_settlement.subject; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.subject IS '结算主体';


--
-- Name: COLUMN asp_settlement.due_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.due_amount IS '应结算；人民币元，不能用浮点';


--
-- Name: COLUMN asp_settlement.settled_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.settled_amount IS '已核实结算；人民币元，不能用浮点';


--
-- Name: COLUMN asp_settlement.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.status IS '独立业务状态；合法值不等于业务已获批准：pending partial completed failed disputed';


--
-- Name: COLUMN asp_settlement.evidence; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.evidence IS '真实结算依据；必须按版本校验结构';


--
-- Name: COLUMN asp_settlement.reference; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.reference IS '结算唯一号';


--
-- Name: COLUMN asp_settlement.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_settlement.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_settlement.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_settlement.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_settlement.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_settlement.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_settlement.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_sport; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_sport (
    id bigint NOT NULL,
    code character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    rule_family character varying(100) NOT NULL,
    capability_status character varying(32) NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_sport_capability_status_check CHECK (((capability_status)::text = ANY ((ARRAY['catalog'::character varying, 'registration'::character varying, 'manual'::character varying, 'automatic'::character varying, 'verified'::character varying])::text[]))),
    CONSTRAINT asp_sport_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'disabled'::character varying])::text[]))),
    CONSTRAINT asp_sport_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_sport; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_sport IS '开放运动目录与变体；收录不等于自动规则已验证；来源：母版 D04；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_sport.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_sport.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.code IS '稳定运动或变体编码';


--
-- Name: COLUMN asp_sport.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.name IS '名称';


--
-- Name: COLUMN asp_sport.rule_family; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.rule_family IS '对抗/计时/评分/综合等规则族';


--
-- Name: COLUMN asp_sport.capability_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.capability_status IS '独立业务状态；合法值不等于业务已获批准：catalog registration manual automatic verified';


--
-- Name: COLUMN asp_sport.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.status IS '独立业务状态；合法值不等于业务已获批准：active disabled';


--
-- Name: COLUMN asp_sport.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_sport.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_sport.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_sport.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_sport.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_sport.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_sport.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_staff_grant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_staff_grant (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    organization_id bigint NOT NULL,
    account_id bigint NOT NULL,
    event_id bigint,
    permissions jsonb NOT NULL,
    status character varying(32) NOT NULL,
    valid_from timestamp with time zone NOT NULL,
    valid_until timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_staff_grant_check CHECK (((valid_until IS NULL) OR (valid_until > valid_from))),
    CONSTRAINT asp_staff_grant_status_check CHECK (((status)::text = ANY ((ARRAY['invited'::character varying, 'active'::character varying, 'revoked'::character varying, 'expired'::character varying])::text[]))),
    CONSTRAINT asp_staff_grant_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_staff_grant_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_staff_grant; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_staff_grant IS '工作人员组织、赛事、动作及材料范围授权；来源：母版 D01；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_staff_grant.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_staff_grant.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_staff_grant.organization_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.organization_id IS '授权组织';


--
-- Name: COLUMN asp_staff_grant.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.account_id IS '工作人员平台账号';


--
-- Name: COLUMN asp_staff_grant.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.event_id IS '限定赛事 ID；为空为组织范围，应用核验';


--
-- Name: COLUMN asp_staff_grant.permissions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.permissions IS '动作与材料范围；必须按版本校验结构';


--
-- Name: COLUMN asp_staff_grant.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.status IS '独立业务状态；合法值不等于业务已获批准：invited active revoked expired';


--
-- Name: COLUMN asp_staff_grant.valid_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.valid_from IS '生效；有时区业务时间';


--
-- Name: COLUMN asp_staff_grant.valid_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.valid_until IS '到期；有时区业务时间';


--
-- Name: COLUMN asp_staff_grant.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_staff_grant.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_staff_grant.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_staff_grant.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_staff_grant.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_staff_grant.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_staff_grant.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_stage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_stage (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    unit_id bigint NOT NULL,
    rule_version_id bigint,
    name character varying(100) NOT NULL,
    format character varying(100) NOT NULL,
    sequence integer NOT NULL,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_stage_sequence_check CHECK ((sequence >= 0)),
    CONSTRAINT asp_stage_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'ready'::character varying, 'published'::character varying, 'running'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT asp_stage_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_stage_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_stage; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_stage IS '竞赛阶段及已确认赛制关系；来源：母版 D08；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_stage.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_stage.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_stage.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.unit_id IS '竞赛单元';


--
-- Name: COLUMN asp_stage.rule_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.rule_version_id IS '适用规则。手工场次的内部阶段可空，不制造虚假规则';


--
-- Name: COLUMN asp_stage.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.name IS '阶段名称';


--
-- Name: COLUMN asp_stage.format; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.format IS '淘汰/循环/分组/计时/评分等确认格式';


--
-- Name: COLUMN asp_stage.sequence; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.sequence IS '阶段顺序';


--
-- Name: COLUMN asp_stage.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.status IS '独立业务状态；合法值不等于业务已获批准：draft ready published running completed cancelled';


--
-- Name: COLUMN asp_stage.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_stage.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_stage.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_stage.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_stage.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_stage.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_stage.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_team; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_team (
    id bigint NOT NULL,
    name character varying(200) NOT NULL,
    sport_id bigint NOT NULL,
    captain_person_id bigint NOT NULL,
    creator_account_id bigint NOT NULL,
    join_policy character varying(32) NOT NULL,
    visibility character varying(32) NOT NULL,
    status character varying(32) NOT NULL,
    region character varying(100),
    profile jsonb,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_team_version_check CHECK ((version >= 0)),
    CONSTRAINT asp_team_visibility_check CHECK (((visibility)::text = ANY ((ARRAY['private'::character varying, 'members'::character varying, 'public'::character varying])::text[]))),
    CONSTRAINT ck_asp_team_join_policy CHECK (((join_policy)::text = ANY ((ARRAY['open'::character varying, 'application'::character varying, 'invitation'::character varying, 'closed'::character varying])::text[]))),
    CONSTRAINT ck_asp_team_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'disbanded'::character varying])::text[])))
);


--
-- Name: TABLE asp_team; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_team IS '长期项目队伍。一期只有有效和解散，解散后不恢复，不归属组织；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_team.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_team.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.name IS '当前队名。已提交报名使用自己的队名快照';


--
-- Name: COLUMN asp_team.sport_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.sport_id IS '项目。一期创建时写入羽毛球，之后不改';


--
-- Name: COLUMN asp_team.captain_person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.captain_person_id IS '当前队长档案。解散后保留最后一任，有效队伍还必须有一条有效队长成员';


--
-- Name: COLUMN asp_team.creator_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.creator_account_id IS '创建人。不代表当前能否代表队伍报名';


--
-- Name: COLUMN asp_team.join_policy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.join_policy IS '一期创建写 open。申请和邀请同时开放，服务不按这列分支：open application invitation closed';


--
-- Name: COLUMN asp_team.visibility; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.visibility IS '一期创建写 members。不做队伍广场，服务不按这列分支：private members public';


--
-- Name: COLUMN asp_team.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.status IS '独立业务状态；合法值不等于业务已获批准：active disbanded';


--
-- Name: COLUMN asp_team.region; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.region IS '活动区域。一期页面不维护';


--
-- Name: COLUMN asp_team.profile; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.profile IS '非敏感展示资料。一期页面不维护；必须按版本校验结构';


--
-- Name: COLUMN asp_team.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_team.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_team.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_team.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_team.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_team.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_team_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_team_history (
    id bigint NOT NULL,
    team_id bigint NOT NULL,
    action character varying(100) NOT NULL,
    before_snapshot jsonb NOT NULL,
    after_snapshot jsonb NOT NULL,
    reason character varying(1000) NOT NULL,
    effective_at timestamp with time zone NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_team_history_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_team_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_team_history IS '队伍改名、转让、解散的事实和快照。不代替成员终止行，也不回写已提交报名；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_team_history.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_team_history.team_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.team_id IS '长期队伍';


--
-- Name: COLUMN asp_team_history.action; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.action IS '变更动作';


--
-- Name: COLUMN asp_team_history.before_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.before_snapshot IS '原事实；必须按版本校验结构';


--
-- Name: COLUMN asp_team_history.after_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.after_snapshot IS '新事实；必须按版本校验结构';


--
-- Name: COLUMN asp_team_history.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.reason IS '变更依据';


--
-- Name: COLUMN asp_team_history.effective_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.effective_at IS '生效时间；有时区业务时间';


--
-- Name: COLUMN asp_team_history.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_team_history.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_team_history.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_team_history.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_team_history.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_team_history.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_history.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_team_invitation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_team_invitation (
    id bigint NOT NULL,
    team_id bigint NOT NULL,
    inviter_account_id bigint NOT NULL,
    target_person_id bigint,
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    invitation_kind character varying(32) DEFAULT 'direct'::character varying NOT NULL,
    inviter_person_id bigint,
    invite_token character varying(64),
    expires_at timestamp with time zone,
    share_invitation_id bigint,
    CONSTRAINT asp_team_invitation_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_asp_team_invitation_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'declined'::character varying, 'revoked'::character varying, 'invalidated'::character varying])::text[]))),
    CONSTRAINT ck_team_invitation_kind CHECK (((invitation_kind)::text = ANY ((ARRAY['direct'::character varying, 'share'::character varying])::text[]))),
    CONSTRAINT ck_team_share_acceptance CHECK (((share_invitation_id IS NULL) OR (((invitation_kind)::text = 'direct'::text) AND ((status)::text = 'accepted'::text) AND (share_invitation_id <> id)))),
    CONSTRAINT ck_team_share_shape CHECK (((((invitation_kind)::text = 'direct'::text) AND (target_person_id IS NOT NULL) AND (invite_token IS NULL) AND (expires_at IS NULL)) OR (((invitation_kind)::text = 'share'::text) AND (target_person_id IS NULL) AND (inviter_person_id IS NOT NULL) AND (invite_token IS NOT NULL) AND (expires_at IS NOT NULL) AND (share_invitation_id IS NULL) AND ((status)::text = ANY ((ARRAY['pending'::character varying, 'revoked'::character varying, 'invalidated'::character varying])::text[]))))),
    CONSTRAINT ck_team_share_token CHECK (((invite_token IS NULL) OR ((invite_token)::text ~ '^[a-f0-9]{64}$'::text)))
);


--
-- Name: TABLE asp_team_invitation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_team_invitation IS '队长指定一名用户的入队邀请。必须本人接受，不使用可转发链接；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_team_invitation.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_team_invitation.team_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.team_id IS '邀请队伍';


--
-- Name: COLUMN asp_team_invitation.inviter_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.inviter_account_id IS '邀请者';


--
-- Name: COLUMN asp_team_invitation.target_person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.target_person_id IS '定向受邀本人；分享授权为空，接受另插本人事实';


--
-- Name: COLUMN asp_team_invitation.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.status IS '独立业务状态；合法值不等于业务已获批准：pending accepted declined revoked invalidated';


--
-- Name: COLUMN asp_team_invitation.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_team_invitation.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_team_invitation.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_team_invitation.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_team_invitation.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_team_invitation.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_team_invitation.invitation_kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.invitation_kind IS 'direct 定向邀请或接受事实；share 队长可转发入队授权';


--
-- Name: COLUMN asp_team_invitation.inviter_person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.inviter_person_id IS '分享授权时的队长稳定档案；转让或账号停止后失效';


--
-- Name: COLUMN asp_team_invitation.invite_token; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.invite_token IS '256位随机业务分享凭据，仅当前队长回显，不写通知或日志';


--
-- Name: COLUMN asp_team_invitation.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.expires_at IS '分享链接七天到期；定向邀请为空';


--
-- Name: COLUMN asp_team_invitation.share_invitation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_invitation.share_invitation_id IS '本人接受分享的来源，同来源同本人一次，离队不复活';


--
-- Name: asp_team_join_request; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_team_join_request (
    id bigint NOT NULL,
    team_id bigint NOT NULL,
    person_id bigint NOT NULL,
    status character varying(32) NOT NULL,
    reviewer_account_id bigint,
    reason character varying(500),
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_team_join_request_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_asp_team_join_request_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'cancelled'::character varying, 'invalidated'::character varying])::text[])))
);


--
-- Name: TABLE asp_team_join_request; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_team_join_request IS '入队申请。待处理不是成员，失效不能记成申请人撤销或队长拒绝；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_team_join_request.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_team_join_request.team_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.team_id IS '申请队伍';


--
-- Name: COLUMN asp_team_join_request.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.person_id IS '申请者';


--
-- Name: COLUMN asp_team_join_request.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.status IS '独立业务状态；合法值不等于业务已获批准：pending approved rejected cancelled invalidated';


--
-- Name: COLUMN asp_team_join_request.reviewer_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.reviewer_account_id IS '处理人。申请人撤销和系统失效时为空';


--
-- Name: COLUMN asp_team_join_request.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.reason IS '处理依据';


--
-- Name: COLUMN asp_team_join_request.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_team_join_request.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_team_join_request.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_team_join_request.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_team_join_request.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_team_join_request.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_join_request.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_team_member; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_team_member (
    id bigint NOT NULL,
    team_id bigint NOT NULL,
    person_id bigint NOT NULL,
    role character varying(32) NOT NULL,
    status character varying(32) NOT NULL,
    join_source character varying(100) NOT NULL,
    joined_at timestamp with time zone NOT NULL,
    left_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    end_reason character varying(32),
    CONSTRAINT asp_team_member_check CHECK (((left_at IS NULL) OR (left_at >= joined_at))),
    CONSTRAINT asp_team_member_version_check CHECK ((version >= 0)),
    CONSTRAINT ck_asp_team_member_end_reason CHECK (((end_reason IS NULL) OR ((end_reason)::text = ANY ((ARRAY['member_left'::character varying, 'captain_removed'::character varying, 'team_disbanded'::character varying])::text[])))),
    CONSTRAINT ck_asp_team_member_episode CHECK (((((status)::text = 'active'::text) AND (left_at IS NULL) AND (end_reason IS NULL)) OR (((status)::text = 'ended'::text) AND (left_at IS NOT NULL) AND (end_reason IS NOT NULL)))),
    CONSTRAINT ck_asp_team_member_role CHECK (((role)::text = ANY ((ARRAY['captain'::character varying, 'member'::character varying])::text[]))),
    CONSTRAINT ck_asp_team_member_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'ended'::character varying])::text[])))
);


--
-- Name: TABLE asp_team_member; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_team_member IS '队伍成员的一段关系。结束后不重新激活，再次加入另起一行；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_team_member.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_team_member.team_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.team_id IS '长期队伍';


--
-- Name: COLUMN asp_team_member.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.person_id IS '现实成员';


--
-- Name: COLUMN asp_team_member.role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.role IS '独立业务状态；合法值不等于业务已获批准：captain member';


--
-- Name: COLUMN asp_team_member.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.status IS '独立业务状态；合法值不等于业务已获批准：active ended';


--
-- Name: COLUMN asp_team_member.join_source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.join_source IS 'create、application 或 invitation';


--
-- Name: COLUMN asp_team_member.joined_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.joined_at IS '入队时间；有时区业务时间';


--
-- Name: COLUMN asp_team_member.left_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.left_at IS '离队时间；有时区业务时间';


--
-- Name: COLUMN asp_team_member.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_team_member.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_team_member.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_team_member.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_team_member.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_team_member.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: COLUMN asp_team_member.end_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_member.end_reason IS '结束原因。有效成员必须为空：member_left captain_removed team_disbanded';


--
-- Name: asp_team_quota; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_team_quota (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    create_limit integer NOT NULL,
    join_limit integer NOT NULL,
    policy_version character varying(100) NOT NULL,
    exception_basis character varying(500),
    valid_until timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_team_quota_create_limit_check CHECK ((create_limit >= 0)),
    CONSTRAINT asp_team_quota_join_limit_check CHECK ((join_limit >= 0)),
    CONSTRAINT asp_team_quota_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_team_quota; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_team_quota IS '账户建队与入队配额。一期没有已批准数值，服务不读不写；来源：母版 D03；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_team_quota.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_team_quota.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.account_id IS '受配额账号';


--
-- Name: COLUMN asp_team_quota.create_limit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.create_limit IS '有效自建队上限；非固定 3';


--
-- Name: COLUMN asp_team_quota.join_limit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.join_limit IS '有效加入队上限；非固定 10';


--
-- Name: COLUMN asp_team_quota.policy_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.policy_version IS '平台公开配额版本';


--
-- Name: COLUMN asp_team_quota.exception_basis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.exception_basis IS '扩额批准依据';


--
-- Name: COLUMN asp_team_quota.valid_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.valid_until IS '豁免或规则到期；有时区业务时间';


--
-- Name: COLUMN asp_team_quota.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_team_quota.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_team_quota.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_team_quota.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_team_quota.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_team_quota.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_quota.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_team_room; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_team_room (
    id bigint NOT NULL,
    unit_id bigint NOT NULL,
    competition_type_id bigint NOT NULL,
    host_account_id bigint NOT NULL,
    team_id bigint,
    name character varying(100) NOT NULL,
    status character varying(32) NOT NULL,
    registration_id bigint,
    announcement character varying(1000),
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_team_room_status_check CHECK (((status)::text = ANY ((ARRAY['forming'::character varying, 'ready'::character varying, 'submitted'::character varying, 'closed'::character varying])::text[]))),
    CONSTRAINT asp_team_room_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_team_room; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_team_room IS '本场参赛房间，与长期队伍及已提交名单分开；房主计入成员人数';


--
-- Name: COLUMN asp_team_room.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_team_room.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.unit_id IS '赛事报名单元';


--
-- Name: COLUMN asp_team_room.competition_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.competition_type_id IS '比赛类型';


--
-- Name: COLUMN asp_team_room.host_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.host_account_id IS '当前房主';


--
-- Name: COLUMN asp_team_room.team_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.team_id IS '可选长期代表队';


--
-- Name: COLUMN asp_team_room.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.name IS '房间名称';


--
-- Name: COLUMN asp_team_room.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.status IS '独立业务状态；合法值不等于业务已获批准：forming ready submitted closed';


--
-- Name: COLUMN asp_team_room.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.registration_id IS '成功生成的报名草稿或事实编号';


--
-- Name: COLUMN asp_team_room.announcement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.announcement IS '房间公告';


--
-- Name: COLUMN asp_team_room.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_team_room.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_team_room.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_team_room.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_team_room.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_team_room.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_team_room_member; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_team_room_member (
    id bigint NOT NULL,
    room_id bigint NOT NULL,
    unit_id bigint NOT NULL,
    account_id bigint NOT NULL,
    person_id bigint NOT NULL,
    status character varying(32) NOT NULL,
    ready boolean DEFAULT false NOT NULL,
    joined_at timestamp with time zone NOT NULL,
    left_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_team_room_member_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'left'::character varying])::text[]))),
    CONSTRAINT asp_team_room_member_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_team_room_member; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_team_room_member IS '参赛房间成员；加入不等于本人报名声明确认';


--
-- Name: COLUMN asp_team_room_member.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_team_room_member.room_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.room_id IS '房间';


--
-- Name: COLUMN asp_team_room_member.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.unit_id IS '同项目防重复参赛房间占位';


--
-- Name: COLUMN asp_team_room_member.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.account_id IS '成员';


--
-- Name: COLUMN asp_team_room_member.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.person_id IS '本人档案';


--
-- Name: COLUMN asp_team_room_member.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.status IS '独立业务状态；合法值不等于业务已获批准：active left';


--
-- Name: COLUMN asp_team_room_member.ready; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.ready IS '本人备赛确认，不能替代参赛声明';


--
-- Name: COLUMN asp_team_room_member.joined_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.joined_at IS '加入时间；有时区业务时间';


--
-- Name: COLUMN asp_team_room_member.left_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.left_at IS '离开时间；有时区业务时间';


--
-- Name: COLUMN asp_team_room_member.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_team_room_member.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_team_room_member.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_team_room_member.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_team_room_member.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_team_room_member.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_team_room_member.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_time_constraint; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_time_constraint (
    id bigint NOT NULL,
    person_id bigint,
    resource_id bigint,
    source_tenant_id character varying(20) NOT NULL,
    source_type character varying(100) NOT NULL,
    source_id bigint NOT NULL,
    parent_id bigint,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    certainty character varying(32) NOT NULL,
    strength character varying(32) NOT NULL,
    status character varying(32) NOT NULL,
    buffer_before_seconds integer NOT NULL,
    buffer_after_seconds integer NOT NULL,
    expires_at timestamp with time zone,
    basis jsonb NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_time_constraint_buffer_after_seconds_check CHECK ((buffer_after_seconds >= 0)),
    CONSTRAINT asp_time_constraint_buffer_before_seconds_check CHECK ((buffer_before_seconds >= 0)),
    CONSTRAINT asp_time_constraint_certainty_check CHECK (((certainty)::text = ANY ((ARRAY['tentative'::character varying, 'conditional'::character varying, 'confirmed'::character varying])::text[]))),
    CONSTRAINT asp_time_constraint_check CHECK ((ends_at > starts_at)),
    CONSTRAINT asp_time_constraint_check1 CHECK (((person_id IS NOT NULL) <> (resource_id IS NOT NULL))),
    CONSTRAINT asp_time_constraint_check2 CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT asp_time_constraint_status_check CHECK (((status)::text = ANY ((ARRAY['held'::character varying, 'active'::character varying, 'released'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT asp_time_constraint_strength_check CHECK (((strength)::text = ANY ((ARRAY['soft'::character varying, 'hard'::character varying])::text[]))),
    CONSTRAINT asp_time_constraint_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_time_constraint; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_time_constraint IS '受控跨赛事时间事实；与名额生命周期关联但独立；来源：母版 D07；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_time_constraint.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_time_constraint.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.person_id IS '实际相关人员';


--
-- Name: COLUMN asp_time_constraint.resource_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.resource_id IS '资源 ID；source_tenant_id 标识资源所属方';


--
-- Name: COLUMN asp_time_constraint.source_tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.source_tenant_id IS '来源租户；只返回受限冲突结果';


--
-- Name: COLUMN asp_time_constraint.source_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.source_type IS '报名/阶段/场次/裁判任务';


--
-- Name: COLUMN asp_time_constraint.source_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.source_id IS '来源业务 ID';


--
-- Name: COLUMN asp_time_constraint.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.parent_id IS '父子安排，避免自冲突';


--
-- Name: COLUMN asp_time_constraint.starts_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.starts_at IS '约束开始；有时区业务时间';


--
-- Name: COLUMN asp_time_constraint.ends_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.ends_at IS '约束结束；有时区业务时间';


--
-- Name: COLUMN asp_time_constraint.certainty; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.certainty IS '独立业务状态；合法值不等于业务已获批准：tentative conditional confirmed';


--
-- Name: COLUMN asp_time_constraint.strength; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.strength IS '独立业务状态；合法值不等于业务已获批准：soft hard';


--
-- Name: COLUMN asp_time_constraint.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.status IS '独立业务状态；合法值不等于业务已获批准：held active released cancelled';


--
-- Name: COLUMN asp_time_constraint.buffer_before_seconds; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.buffer_before_seconds IS '确认的准备或转场缓冲';


--
-- Name: COLUMN asp_time_constraint.buffer_after_seconds; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.buffer_after_seconds IS '确认的恢复缓冲';


--
-- Name: COLUMN asp_time_constraint.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.expires_at IS '临时约束期限；有时区业务时间';


--
-- Name: COLUMN asp_time_constraint.basis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.basis IS '来源版本、晋级路径与排他条件；必须按版本校验结构';


--
-- Name: COLUMN asp_time_constraint.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_time_constraint.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_time_constraint.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_time_constraint.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_time_constraint.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_time_constraint.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_time_constraint.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_title_equipment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_title_equipment (
    id bigint NOT NULL,
    owner_type character varying(32) NOT NULL,
    owner_id bigint NOT NULL,
    sport_id bigint NOT NULL,
    title_code character varying(64) NOT NULL,
    honor_id bigint,
    frame_style character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_title_equipment_owner_type_check CHECK (((owner_type)::text = ANY ((ARRAY['person'::character varying, 'team'::character varying])::text[]))),
    CONSTRAINT asp_title_equipment_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_title_equipment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_title_equipment IS '本人或队长选择当前佩戴的成长称号；授予来源由荣誉事实保留';


--
-- Name: COLUMN asp_title_equipment.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_title_equipment.owner_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.owner_type IS '独立业务状态；合法值不等于业务已获批准：person team';


--
-- Name: COLUMN asp_title_equipment.owner_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.owner_id IS '本人或队伍编号';


--
-- Name: COLUMN asp_title_equipment.sport_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.sport_id IS '运动';


--
-- Name: COLUMN asp_title_equipment.title_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.title_code IS '规则目录中的称号编码';


--
-- Name: COLUMN asp_title_equipment.honor_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.honor_id IS '获授荣誉事实；欢迎样式可空';


--
-- Name: COLUMN asp_title_equipment.frame_style; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.frame_style IS '允许的头像边框样式';


--
-- Name: COLUMN asp_title_equipment.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_title_equipment.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_title_equipment.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_title_equipment.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_title_equipment.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_title_equipment.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_title_equipment.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_venue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_venue (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    name character varying(200) NOT NULL,
    address character varying(500) NOT NULL,
    operator character varying(200) NOT NULL,
    contact_cipher character varying(1000),
    status character varying(32) NOT NULL,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_venue_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'maintenance'::character varying, 'disabled'::character varying])::text[]))),
    CONSTRAINT asp_venue_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_venue_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_venue; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_venue IS '场馆及实际管理责任；来源：母版 D12；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_venue.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_venue.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_venue.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.name IS '场馆名';


--
-- Name: COLUMN asp_venue.address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.address IS '地址';


--
-- Name: COLUMN asp_venue.operator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.operator IS '实际责任主体';


--
-- Name: COLUMN asp_venue.contact_cipher; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.contact_cipher IS '受控联络';


--
-- Name: COLUMN asp_venue.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.status IS '独立业务状态；合法值不等于业务已获批准：active maintenance disabled';


--
-- Name: COLUMN asp_venue.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_venue.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_venue.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_venue.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_venue.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_venue.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_venue.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_waitlist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_waitlist (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    registration_id bigint NOT NULL,
    pool_id bigint NOT NULL,
    rank integer NOT NULL,
    basis character varying(500) NOT NULL,
    status character varying(32) NOT NULL,
    confirm_until timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_waitlist_rank_check CHECK ((rank >= 0)),
    CONSTRAINT asp_waitlist_status_check CHECK (((status)::text = ANY ((ARRAY['waiting'::character varying, 'invited'::character varying, 'confirmed'::character varying, 'expired'::character varying, 'withdrawn'::character varying])::text[]))),
    CONSTRAINT asp_waitlist_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_waitlist_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_waitlist; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_waitlist IS '候补排序、获邀确认及期限；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_waitlist.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_waitlist.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_waitlist.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.registration_id IS '候补申请';


--
-- Name: COLUMN asp_waitlist.pool_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.pool_id IS '容量池';


--
-- Name: COLUMN asp_waitlist.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.rank IS '公布规则下候补排序';


--
-- Name: COLUMN asp_waitlist.basis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.basis IS '排序依据';


--
-- Name: COLUMN asp_waitlist.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.status IS '独立业务状态；合法值不等于业务已获批准：waiting invited confirmed expired withdrawn';


--
-- Name: COLUMN asp_waitlist.confirm_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.confirm_until IS '递补确认期限；有时区业务时间';


--
-- Name: COLUMN asp_waitlist.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_waitlist.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_waitlist.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_waitlist.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_waitlist.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_waitlist.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_waitlist.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_withdrawal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asp_withdrawal (
    id bigint NOT NULL,
    tenant_id character varying(20) NOT NULL,
    registration_id bigint NOT NULL,
    person_id bigint,
    applicant_account_id bigint NOT NULL,
    status character varying(32) NOT NULL,
    reason character varying(1000) NOT NULL,
    impact jsonb NOT NULL,
    effective_at timestamp with time zone,
    create_dept bigint,
    create_by bigint,
    create_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_by bigint,
    update_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT asp_withdrawal_status_check CHECK (((status)::text = ANY ((ARRAY['requested'::character varying, 'approved'::character varying, 'rejected'::character varying, 'completed'::character varying])::text[]))),
    CONSTRAINT asp_withdrawal_tenant_id_check CHECK ((length((tenant_id)::text) > 0)),
    CONSTRAINT asp_withdrawal_version_check CHECK ((version >= 0))
);


--
-- Name: TABLE asp_withdrawal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.asp_withdrawal IS '退赛申请、资格终止及退款义务接续；来源：母版 D05；应用服务执行状态转换、授权和跨记录一致性，数据库约束只是结构防线。';


--
-- Name: COLUMN asp_withdrawal.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.id IS '应用分配的稳定雪花 ID；不能随变更重建';


--
-- Name: COLUMN asp_withdrawal.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';


--
-- Name: COLUMN asp_withdrawal.registration_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.registration_id IS '报名';


--
-- Name: COLUMN asp_withdrawal.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.person_id IS '允许局部退赛时对应成员';


--
-- Name: COLUMN asp_withdrawal.applicant_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.applicant_account_id IS '申请者';


--
-- Name: COLUMN asp_withdrawal.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.status IS '独立业务状态；合法值不等于业务已获批准：requested approved rejected completed';


--
-- Name: COLUMN asp_withdrawal.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.reason IS '请求及批准依据';


--
-- Name: COLUMN asp_withdrawal.impact; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.impact IS '资格、名单、名额、时间和资金影响；必须按版本校验结构';


--
-- Name: COLUMN asp_withdrawal.effective_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.effective_at IS '退赛生效；有时区业务时间';


--
-- Name: COLUMN asp_withdrawal.create_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.create_dept IS '操作创建部门；上游审计字段';


--
-- Name: COLUMN asp_withdrawal.create_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';


--
-- Name: COLUMN asp_withdrawal.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.create_time IS '记录创建时间；不同于实际发生时间';


--
-- Name: COLUMN asp_withdrawal.update_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.update_by IS '最近更新操作主体';


--
-- Name: COLUMN asp_withdrawal.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.update_time IS '最近更新记录时间；由服务维护';


--
-- Name: COLUMN asp_withdrawal.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.asp_withdrawal.version IS '乐观并发版本；不替代业务规则/名单版本';


--
-- Name: asp_account asp_account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_account
    ADD CONSTRAINT asp_account_pkey PRIMARY KEY (id);


--
-- Name: asp_account_tenant_principal asp_account_tenant_principal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_account_tenant_principal
    ADD CONSTRAINT asp_account_tenant_principal_pkey PRIMARY KEY (id);


--
-- Name: asp_action_confirmation asp_action_confirmation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_action_confirmation
    ADD CONSTRAINT asp_action_confirmation_pkey PRIMARY KEY (id);


--
-- Name: asp_action_execution asp_action_execution_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_action_execution
    ADD CONSTRAINT asp_action_execution_pkey PRIMARY KEY (id);


--
-- Name: asp_advancement asp_advancement_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_advancement
    ADD CONSTRAINT asp_advancement_pkey PRIMARY KEY (id);


--
-- Name: asp_advancement asp_advancement_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_advancement
    ADD CONSTRAINT asp_advancement_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_agent_grant asp_agent_grant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_agent_grant
    ADD CONSTRAINT asp_agent_grant_pkey PRIMARY KEY (id);


--
-- Name: asp_agent_message asp_agent_message_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_agent_message
    ADD CONSTRAINT asp_agent_message_pkey PRIMARY KEY (id);


--
-- Name: asp_agent asp_agent_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_agent
    ADD CONSTRAINT asp_agent_pkey PRIMARY KEY (id);


--
-- Name: asp_agent_run asp_agent_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_agent_run
    ADD CONSTRAINT asp_agent_run_pkey PRIMARY KEY (id);


--
-- Name: asp_agent_step asp_agent_step_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_agent_step
    ADD CONSTRAINT asp_agent_step_pkey PRIMARY KEY (id);


--
-- Name: asp_agent_version asp_agent_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_agent_version
    ADD CONSTRAINT asp_agent_version_pkey PRIMARY KEY (id);


--
-- Name: asp_ai_gateway_call asp_ai_gateway_call_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_gateway_call
    ADD CONSTRAINT asp_ai_gateway_call_pkey PRIMARY KEY (id);


--
-- Name: asp_ai_gateway_call asp_ai_gateway_call_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_gateway_call
    ADD CONSTRAINT asp_ai_gateway_call_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_ai_gateway_task asp_ai_gateway_task_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_gateway_task
    ADD CONSTRAINT asp_ai_gateway_task_pkey PRIMARY KEY (id);


--
-- Name: asp_ai_gateway_task asp_ai_gateway_task_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_gateway_task
    ADD CONSTRAINT asp_ai_gateway_task_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_ai_invocation asp_ai_invocation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_invocation
    ADD CONSTRAINT asp_ai_invocation_pkey PRIMARY KEY (id);


--
-- Name: asp_ai_invocation asp_ai_invocation_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_invocation
    ADD CONSTRAINT asp_ai_invocation_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_ai_task_file asp_ai_task_file_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_task_file
    ADD CONSTRAINT asp_ai_task_file_pkey PRIMARY KEY (id);


--
-- Name: asp_ai_task_file asp_ai_task_file_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_task_file
    ADD CONSTRAINT asp_ai_task_file_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_ai_task asp_ai_task_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_task
    ADD CONSTRAINT asp_ai_task_pkey PRIMARY KEY (id);


--
-- Name: asp_ai_task asp_ai_task_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_task
    ADD CONSTRAINT asp_ai_task_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_appeal asp_appeal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_appeal
    ADD CONSTRAINT asp_appeal_pkey PRIMARY KEY (id);


--
-- Name: asp_appeal asp_appeal_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_appeal
    ADD CONSTRAINT asp_appeal_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_audit_event asp_audit_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_audit_event
    ADD CONSTRAINT asp_audit_event_pkey PRIMARY KEY (id);


--
-- Name: asp_audit_event asp_audit_event_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_audit_event
    ADD CONSTRAINT asp_audit_event_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_capability_activation asp_capability_activation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_capability_activation
    ADD CONSTRAINT asp_capability_activation_pkey PRIMARY KEY (id);


--
-- Name: asp_capability_version asp_capability_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_capability_version
    ADD CONSTRAINT asp_capability_version_pkey PRIMARY KEY (id);


--
-- Name: asp_capacity_occupation asp_capacity_occupation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_capacity_occupation
    ADD CONSTRAINT asp_capacity_occupation_pkey PRIMARY KEY (id);


--
-- Name: asp_capacity_occupation asp_capacity_occupation_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_capacity_occupation
    ADD CONSTRAINT asp_capacity_occupation_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_capacity_pool asp_capacity_pool_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_capacity_pool
    ADD CONSTRAINT asp_capacity_pool_pkey PRIMARY KEY (id);


--
-- Name: asp_capacity_pool asp_capacity_pool_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_capacity_pool
    ADD CONSTRAINT asp_capacity_pool_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_change_case asp_change_case_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_change_case
    ADD CONSTRAINT asp_change_case_pkey PRIMARY KEY (id);


--
-- Name: asp_change_case asp_change_case_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_change_case
    ADD CONSTRAINT asp_change_case_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_checkin asp_checkin_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_checkin
    ADD CONSTRAINT asp_checkin_pkey PRIMARY KEY (id);


--
-- Name: asp_checkin asp_checkin_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_checkin
    ADD CONSTRAINT asp_checkin_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_collaboration asp_collaboration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_collaboration
    ADD CONSTRAINT asp_collaboration_pkey PRIMARY KEY (id);


--
-- Name: asp_collaboration asp_collaboration_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_collaboration
    ADD CONSTRAINT asp_collaboration_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_competition_type asp_competition_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_competition_type
    ADD CONSTRAINT asp_competition_type_pkey PRIMARY KEY (id);


--
-- Name: asp_competition_unit asp_competition_unit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_competition_unit
    ADD CONSTRAINT asp_competition_unit_pkey PRIMARY KEY (id);


--
-- Name: asp_competition_unit asp_competition_unit_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_competition_unit
    ADD CONSTRAINT asp_competition_unit_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_complaint_message asp_complaint_message_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_complaint_message
    ADD CONSTRAINT asp_complaint_message_pkey PRIMARY KEY (id);


--
-- Name: asp_complaint asp_complaint_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_complaint
    ADD CONSTRAINT asp_complaint_pkey PRIMARY KEY (id);


--
-- Name: asp_complaint asp_complaint_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_complaint
    ADD CONSTRAINT asp_complaint_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_conflict_case asp_conflict_case_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_conflict_case
    ADD CONSTRAINT asp_conflict_case_pkey PRIMARY KEY (id);


--
-- Name: asp_conflict_case asp_conflict_case_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_conflict_case
    ADD CONSTRAINT asp_conflict_case_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_consent asp_consent_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_consent
    ADD CONSTRAINT asp_consent_pkey PRIMARY KEY (id);


--
-- Name: asp_data_request asp_data_request_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_data_request
    ADD CONSTRAINT asp_data_request_pkey PRIMARY KEY (id);


--
-- Name: asp_declaration_ack asp_declaration_ack_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_declaration_ack
    ADD CONSTRAINT asp_declaration_ack_pkey PRIMARY KEY (id);


--
-- Name: asp_declaration_ack asp_declaration_ack_registration_member_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_declaration_ack
    ADD CONSTRAINT asp_declaration_ack_registration_member_id_key UNIQUE (registration_member_id);


--
-- Name: asp_draw_run asp_draw_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_draw_run
    ADD CONSTRAINT asp_draw_run_pkey PRIMARY KEY (id);


--
-- Name: asp_draw_run asp_draw_run_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_draw_run
    ADD CONSTRAINT asp_draw_run_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_entry_field_value asp_entry_field_value_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_entry_field_value
    ADD CONSTRAINT asp_entry_field_value_pkey PRIMARY KEY (id);


--
-- Name: asp_entry_field_value asp_entry_field_value_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_entry_field_value
    ADD CONSTRAINT asp_entry_field_value_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_event_command asp_event_command_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_command
    ADD CONSTRAINT asp_event_command_pkey PRIMARY KEY (id);


--
-- Name: asp_event_command asp_event_command_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_command
    ADD CONSTRAINT asp_event_command_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_event_field asp_event_field_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_field
    ADD CONSTRAINT asp_event_field_pkey PRIMARY KEY (id);


--
-- Name: asp_event_field asp_event_field_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_field
    ADD CONSTRAINT asp_event_field_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_event_payment_config asp_event_payment_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_payment_config
    ADD CONSTRAINT asp_event_payment_config_pkey PRIMARY KEY (id);


--
-- Name: asp_event_payment_config asp_event_payment_config_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_payment_config
    ADD CONSTRAINT asp_event_payment_config_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_event asp_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event
    ADD CONSTRAINT asp_event_pkey PRIMARY KEY (id);


--
-- Name: asp_event_poster asp_event_poster_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_poster
    ADD CONSTRAINT asp_event_poster_pkey PRIMARY KEY (id);


--
-- Name: asp_event_poster_stat asp_event_poster_stat_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_poster_stat
    ADD CONSTRAINT asp_event_poster_stat_pkey PRIMARY KEY (id);


--
-- Name: asp_event_poster_stat asp_event_poster_stat_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_poster_stat
    ADD CONSTRAINT asp_event_poster_stat_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_event_poster asp_event_poster_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_poster
    ADD CONSTRAINT asp_event_poster_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_event_revision asp_event_revision_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_revision
    ADD CONSTRAINT asp_event_revision_pkey PRIMARY KEY (id);


--
-- Name: asp_event_revision asp_event_revision_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_revision
    ADD CONSTRAINT asp_event_revision_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_event asp_event_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event
    ADD CONSTRAINT asp_event_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_execution_command asp_execution_command_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_execution_command
    ADD CONSTRAINT asp_execution_command_pkey PRIMARY KEY (id);


--
-- Name: asp_execution_command asp_execution_command_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_execution_command
    ADD CONSTRAINT asp_execution_command_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_fee_item asp_fee_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_item
    ADD CONSTRAINT asp_fee_item_pkey PRIMARY KEY (id);


--
-- Name: asp_fee_item asp_fee_item_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_item
    ADD CONSTRAINT asp_fee_item_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_fee_obligation asp_fee_obligation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_obligation
    ADD CONSTRAINT asp_fee_obligation_pkey PRIMARY KEY (id);


--
-- Name: asp_fee_obligation asp_fee_obligation_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_obligation
    ADD CONSTRAINT asp_fee_obligation_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_fee_policy asp_fee_policy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_policy
    ADD CONSTRAINT asp_fee_policy_pkey PRIMARY KEY (id);


--
-- Name: asp_fee_policy asp_fee_policy_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_policy
    ADD CONSTRAINT asp_fee_policy_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_fee_share asp_fee_share_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_share
    ADD CONSTRAINT asp_fee_share_pkey PRIMARY KEY (id);


--
-- Name: asp_fee_share asp_fee_share_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_share
    ADD CONSTRAINT asp_fee_share_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_file asp_file_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_file
    ADD CONSTRAINT asp_file_pkey PRIMARY KEY (id);


--
-- Name: asp_governance_grant asp_governance_grant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_governance_grant
    ADD CONSTRAINT asp_governance_grant_pkey PRIMARY KEY (id);


--
-- Name: asp_growth_policy asp_growth_policy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_growth_policy
    ADD CONSTRAINT asp_growth_policy_pkey PRIMARY KEY (id);


--
-- Name: asp_growth_profile asp_growth_profile_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_growth_profile
    ADD CONSTRAINT asp_growth_profile_pkey PRIMARY KEY (id);


--
-- Name: asp_growth_record asp_growth_record_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_growth_record
    ADD CONSTRAINT asp_growth_record_pkey PRIMARY KEY (id);


--
-- Name: asp_growth_record asp_growth_record_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_growth_record
    ADD CONSTRAINT asp_growth_record_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_honor asp_honor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_honor
    ADD CONSTRAINT asp_honor_pkey PRIMARY KEY (id);


--
-- Name: asp_honor asp_honor_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_honor
    ADD CONSTRAINT asp_honor_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_idempotency asp_idempotency_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_idempotency
    ADD CONSTRAINT asp_idempotency_pkey PRIMARY KEY (id);


--
-- Name: asp_idempotency asp_idempotency_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_idempotency
    ADD CONSTRAINT asp_idempotency_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_lineup_member asp_lineup_member_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_lineup_member
    ADD CONSTRAINT asp_lineup_member_pkey PRIMARY KEY (id);


--
-- Name: asp_lineup_member asp_lineup_member_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_lineup_member
    ADD CONSTRAINT asp_lineup_member_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_login_identity asp_login_identity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_login_identity
    ADD CONSTRAINT asp_login_identity_pkey PRIMARY KEY (id);


--
-- Name: asp_match_entry asp_match_entry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_match_entry
    ADD CONSTRAINT asp_match_entry_pkey PRIMARY KEY (id);


--
-- Name: asp_match_entry asp_match_entry_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_match_entry
    ADD CONSTRAINT asp_match_entry_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_match asp_match_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_match
    ADD CONSTRAINT asp_match_pkey PRIMARY KEY (id);


--
-- Name: asp_match asp_match_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_match
    ADD CONSTRAINT asp_match_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_matching_offer_member asp_matching_offer_member_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_matching_offer_member
    ADD CONSTRAINT asp_matching_offer_member_pkey PRIMARY KEY (id);


--
-- Name: asp_matching_offer asp_matching_offer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_matching_offer
    ADD CONSTRAINT asp_matching_offer_pkey PRIMARY KEY (id);


--
-- Name: asp_matching_request asp_matching_request_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_matching_request
    ADD CONSTRAINT asp_matching_request_pkey PRIMARY KEY (id);


--
-- Name: asp_material_requirement asp_material_requirement_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_material_requirement
    ADD CONSTRAINT asp_material_requirement_pkey PRIMARY KEY (id);


--
-- Name: asp_material_requirement asp_material_requirement_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_material_requirement
    ADD CONSTRAINT asp_material_requirement_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_material_submission asp_material_submission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_material_submission
    ADD CONSTRAINT asp_material_submission_pkey PRIMARY KEY (id);


--
-- Name: asp_material_submission asp_material_submission_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_material_submission
    ADD CONSTRAINT asp_material_submission_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_migration_batch asp_migration_batch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_migration_batch
    ADD CONSTRAINT asp_migration_batch_pkey PRIMARY KEY (id);


--
-- Name: asp_migration_batch asp_migration_batch_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_migration_batch
    ADD CONSTRAINT asp_migration_batch_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_migration_mapping asp_migration_mapping_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_migration_mapping
    ADD CONSTRAINT asp_migration_mapping_pkey PRIMARY KEY (id);


--
-- Name: asp_migration_mapping asp_migration_mapping_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_migration_mapping
    ADD CONSTRAINT asp_migration_mapping_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_notification_delivery asp_notification_delivery_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_notification_delivery
    ADD CONSTRAINT asp_notification_delivery_pkey PRIMARY KEY (id);


--
-- Name: asp_notification_delivery asp_notification_delivery_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_notification_delivery
    ADD CONSTRAINT asp_notification_delivery_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_notification asp_notification_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_notification
    ADD CONSTRAINT asp_notification_pkey PRIMARY KEY (id);


--
-- Name: asp_notification asp_notification_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_notification
    ADD CONSTRAINT asp_notification_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_occupation_reference asp_occupation_reference_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_occupation_reference
    ADD CONSTRAINT asp_occupation_reference_pkey PRIMARY KEY (id);


--
-- Name: asp_occupation_reference asp_occupation_reference_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_occupation_reference
    ADD CONSTRAINT asp_occupation_reference_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_official_assignment asp_official_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_official_assignment
    ADD CONSTRAINT asp_official_assignment_pkey PRIMARY KEY (id);


--
-- Name: asp_official_assignment asp_official_assignment_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_official_assignment
    ADD CONSTRAINT asp_official_assignment_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_org_field asp_org_field_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_org_field
    ADD CONSTRAINT asp_org_field_pkey PRIMARY KEY (id);


--
-- Name: asp_org_field asp_org_field_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_org_field
    ADD CONSTRAINT asp_org_field_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_organization_application asp_organization_application_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_organization_application
    ADD CONSTRAINT asp_organization_application_pkey PRIMARY KEY (id);


--
-- Name: asp_organization_application_version asp_organization_application_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_organization_application_version
    ADD CONSTRAINT asp_organization_application_version_pkey PRIMARY KEY (id);


--
-- Name: asp_organization asp_organization_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_organization
    ADD CONSTRAINT asp_organization_pkey PRIMARY KEY (id);


--
-- Name: asp_organization asp_organization_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_organization
    ADD CONSTRAINT asp_organization_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_outbox asp_outbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_outbox
    ADD CONSTRAINT asp_outbox_pkey PRIMARY KEY (id);


--
-- Name: asp_outbox asp_outbox_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_outbox
    ADD CONSTRAINT asp_outbox_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_payment_action asp_payment_action_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_action
    ADD CONSTRAINT asp_payment_action_pkey PRIMARY KEY (id);


--
-- Name: asp_payment_action asp_payment_action_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_action
    ADD CONSTRAINT asp_payment_action_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_payment_allocation asp_payment_allocation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_allocation
    ADD CONSTRAINT asp_payment_allocation_pkey PRIMARY KEY (id);


--
-- Name: asp_payment_allocation asp_payment_allocation_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_allocation
    ADD CONSTRAINT asp_payment_allocation_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_payment_exception asp_payment_exception_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_exception
    ADD CONSTRAINT asp_payment_exception_pkey PRIMARY KEY (id);


--
-- Name: asp_payment_exception asp_payment_exception_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_exception
    ADD CONSTRAINT asp_payment_exception_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_payment asp_payment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment
    ADD CONSTRAINT asp_payment_pkey PRIMARY KEY (id);


--
-- Name: asp_payment asp_payment_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment
    ADD CONSTRAINT asp_payment_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_person asp_person_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_person
    ADD CONSTRAINT asp_person_pkey PRIMARY KEY (id);


--
-- Name: asp_profile_display asp_profile_display_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_profile_display
    ADD CONSTRAINT asp_profile_display_pkey PRIMARY KEY (id);


--
-- Name: asp_qualification asp_qualification_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_qualification
    ADD CONSTRAINT asp_qualification_pkey PRIMARY KEY (id);


--
-- Name: asp_qualification_review asp_qualification_review_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_qualification_review
    ADD CONSTRAINT asp_qualification_review_pkey PRIMARY KEY (id);


--
-- Name: asp_qualification_review asp_qualification_review_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_qualification_review
    ADD CONSTRAINT asp_qualification_review_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_qualification asp_qualification_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_qualification
    ADD CONSTRAINT asp_qualification_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_ranking_item asp_ranking_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ranking_item
    ADD CONSTRAINT asp_ranking_item_pkey PRIMARY KEY (id);


--
-- Name: asp_ranking_item asp_ranking_item_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ranking_item
    ADD CONSTRAINT asp_ranking_item_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_ranking_run asp_ranking_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ranking_run
    ADD CONSTRAINT asp_ranking_run_pkey PRIMARY KEY (id);


--
-- Name: asp_ranking_run asp_ranking_run_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ranking_run
    ADD CONSTRAINT asp_ranking_run_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_recruitment asp_recruitment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_recruitment
    ADD CONSTRAINT asp_recruitment_pkey PRIMARY KEY (id);


--
-- Name: asp_refund asp_refund_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_refund
    ADD CONSTRAINT asp_refund_pkey PRIMARY KEY (id);


--
-- Name: asp_refund asp_refund_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_refund
    ADD CONSTRAINT asp_refund_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_registration_batch asp_registration_batch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_batch
    ADD CONSTRAINT asp_registration_batch_pkey PRIMARY KEY (id);


--
-- Name: asp_registration_batch asp_registration_batch_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_batch
    ADD CONSTRAINT asp_registration_batch_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_registration_member asp_registration_member_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_member
    ADD CONSTRAINT asp_registration_member_pkey PRIMARY KEY (id);


--
-- Name: asp_registration_member asp_registration_member_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_member
    ADD CONSTRAINT asp_registration_member_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_registration_payment_proof asp_registration_payment_proof_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_payment_proof
    ADD CONSTRAINT asp_registration_payment_proof_pkey PRIMARY KEY (id);


--
-- Name: asp_registration_payment_proof asp_registration_payment_proof_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_payment_proof
    ADD CONSTRAINT asp_registration_payment_proof_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_registration asp_registration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration
    ADD CONSTRAINT asp_registration_pkey PRIMARY KEY (id);


--
-- Name: asp_registration_submit_key asp_registration_submit_key_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_submit_key
    ADD CONSTRAINT asp_registration_submit_key_pkey PRIMARY KEY (id);


--
-- Name: asp_registration_submit_key asp_registration_submit_key_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_submit_key
    ADD CONSTRAINT asp_registration_submit_key_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_registration asp_registration_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration
    ADD CONSTRAINT asp_registration_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_resource asp_resource_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_resource
    ADD CONSTRAINT asp_resource_pkey PRIMARY KEY (id);


--
-- Name: asp_resource_reservation asp_resource_reservation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_resource_reservation
    ADD CONSTRAINT asp_resource_reservation_pkey PRIMARY KEY (id);


--
-- Name: asp_resource_reservation asp_resource_reservation_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_resource_reservation
    ADD CONSTRAINT asp_resource_reservation_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_resource asp_resource_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_resource
    ADD CONSTRAINT asp_resource_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_result_item asp_result_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_result_item
    ADD CONSTRAINT asp_result_item_pkey PRIMARY KEY (id);


--
-- Name: asp_result_item asp_result_item_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_result_item
    ADD CONSTRAINT asp_result_item_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_result_version asp_result_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_result_version
    ADD CONSTRAINT asp_result_version_pkey PRIMARY KEY (id);


--
-- Name: asp_result_version asp_result_version_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_result_version
    ADD CONSTRAINT asp_result_version_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_room_interaction asp_room_interaction_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_room_interaction
    ADD CONSTRAINT asp_room_interaction_pkey PRIMARY KEY (id);


--
-- Name: asp_roster_member asp_roster_member_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_roster_member
    ADD CONSTRAINT asp_roster_member_pkey PRIMARY KEY (id);


--
-- Name: asp_roster_member asp_roster_member_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_roster_member
    ADD CONSTRAINT asp_roster_member_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_roster_version asp_roster_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_roster_version
    ADD CONSTRAINT asp_roster_version_pkey PRIMARY KEY (id);


--
-- Name: asp_roster_version asp_roster_version_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_roster_version
    ADD CONSTRAINT asp_roster_version_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_rule_version asp_rule_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_rule_version
    ADD CONSTRAINT asp_rule_version_pkey PRIMARY KEY (id);


--
-- Name: asp_rule_version asp_rule_version_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_rule_version
    ADD CONSTRAINT asp_rule_version_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_schedule_run asp_schedule_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_schedule_run
    ADD CONSTRAINT asp_schedule_run_pkey PRIMARY KEY (id);


--
-- Name: asp_schedule_run asp_schedule_run_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_schedule_run
    ADD CONSTRAINT asp_schedule_run_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_service_fee asp_service_fee_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_service_fee
    ADD CONSTRAINT asp_service_fee_pkey PRIMARY KEY (id);


--
-- Name: asp_service_fee asp_service_fee_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_service_fee
    ADD CONSTRAINT asp_service_fee_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_settlement asp_settlement_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_settlement
    ADD CONSTRAINT asp_settlement_pkey PRIMARY KEY (id);


--
-- Name: asp_settlement asp_settlement_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_settlement
    ADD CONSTRAINT asp_settlement_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_sport asp_sport_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_sport
    ADD CONSTRAINT asp_sport_pkey PRIMARY KEY (id);


--
-- Name: asp_staff_grant asp_staff_grant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_staff_grant
    ADD CONSTRAINT asp_staff_grant_pkey PRIMARY KEY (id);


--
-- Name: asp_staff_grant asp_staff_grant_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_staff_grant
    ADD CONSTRAINT asp_staff_grant_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_stage asp_stage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_stage
    ADD CONSTRAINT asp_stage_pkey PRIMARY KEY (id);


--
-- Name: asp_stage asp_stage_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_stage
    ADD CONSTRAINT asp_stage_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_team_history asp_team_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_history
    ADD CONSTRAINT asp_team_history_pkey PRIMARY KEY (id);


--
-- Name: asp_team_invitation asp_team_invitation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_invitation
    ADD CONSTRAINT asp_team_invitation_pkey PRIMARY KEY (id);


--
-- Name: asp_team_join_request asp_team_join_request_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_join_request
    ADD CONSTRAINT asp_team_join_request_pkey PRIMARY KEY (id);


--
-- Name: asp_team_member asp_team_member_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_member
    ADD CONSTRAINT asp_team_member_pkey PRIMARY KEY (id);


--
-- Name: asp_team asp_team_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team
    ADD CONSTRAINT asp_team_pkey PRIMARY KEY (id);


--
-- Name: asp_team_quota asp_team_quota_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_quota
    ADD CONSTRAINT asp_team_quota_pkey PRIMARY KEY (id);


--
-- Name: asp_team_room_member asp_team_room_member_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_room_member
    ADD CONSTRAINT asp_team_room_member_pkey PRIMARY KEY (id);


--
-- Name: asp_team_room asp_team_room_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_room
    ADD CONSTRAINT asp_team_room_pkey PRIMARY KEY (id);


--
-- Name: asp_time_constraint asp_time_constraint_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_time_constraint
    ADD CONSTRAINT asp_time_constraint_pkey PRIMARY KEY (id);


--
-- Name: asp_title_equipment asp_title_equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_title_equipment
    ADD CONSTRAINT asp_title_equipment_pkey PRIMARY KEY (id);


--
-- Name: asp_venue asp_venue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_venue
    ADD CONSTRAINT asp_venue_pkey PRIMARY KEY (id);


--
-- Name: asp_venue asp_venue_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_venue
    ADD CONSTRAINT asp_venue_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_waitlist asp_waitlist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_waitlist
    ADD CONSTRAINT asp_waitlist_pkey PRIMARY KEY (id);


--
-- Name: asp_waitlist asp_waitlist_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_waitlist
    ADD CONSTRAINT asp_waitlist_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: asp_withdrawal asp_withdrawal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_withdrawal
    ADD CONSTRAINT asp_withdrawal_pkey PRIMARY KEY (id);


--
-- Name: asp_withdrawal asp_withdrawal_tenant_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_withdrawal
    ADD CONSTRAINT asp_withdrawal_tenant_id_id_key UNIQUE (tenant_id, id);


--
-- Name: ix_asp_account_tenant_principal_9b72fe7744; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_account_tenant_principal_9b72fe7744 ON public.asp_account_tenant_principal USING btree (account_id);


--
-- Name: ix_asp_advancement_8de3a730b7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_advancement_8de3a730b7 ON public.asp_advancement USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_advancement_e6fdd62047; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_advancement_e6fdd62047 ON public.asp_advancement USING btree (tenant_id, result_version_id);


--
-- Name: ix_asp_advancement_f36c110b02; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_advancement_f36c110b02 ON public.asp_advancement USING btree (tenant_id, target_stage_id);


--
-- Name: ix_asp_ai_gateway_call_9695a1aaa1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_ai_gateway_call_9695a1aaa1 ON public.asp_ai_gateway_call USING btree (tenant_id, task_id);


--
-- Name: ix_asp_ai_gateway_task_4046cbd2ed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_ai_gateway_task_4046cbd2ed ON public.asp_ai_gateway_task USING btree (tenant_id, organization_id);


--
-- Name: ix_asp_ai_gateway_task_c8d07e9cef; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_ai_gateway_task_c8d07e9cef ON public.asp_ai_gateway_task USING btree (tenant_id, event_id);


--
-- Name: ix_asp_ai_invocation_465b59edc7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_ai_invocation_465b59edc7 ON public.asp_ai_invocation USING btree (tenant_id, task_id);


--
-- Name: ix_asp_ai_task_bbd1b2b033; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_ai_task_bbd1b2b033 ON public.asp_ai_task USING btree (tenant_id, organization_id);


--
-- Name: ix_asp_ai_task_file_ae615e316c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_ai_task_file_ae615e316c ON public.asp_ai_task_file USING btree (tenant_id, task_id);


--
-- Name: ix_asp_appeal_11fff99669; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_appeal_11fff99669 ON public.asp_appeal USING btree (tenant_id, match_id);


--
-- Name: ix_asp_appeal_31cfd37310; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_appeal_31cfd37310 ON public.asp_appeal USING btree (applicant_account_id);


--
-- Name: ix_asp_appeal_5b2c3f012c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_appeal_5b2c3f012c ON public.asp_appeal USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_appeal_c2f5a9575f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_appeal_c2f5a9575f ON public.asp_appeal USING btree (tenant_id, result_version_id);


--
-- Name: ix_asp_audit_event_055aabf6fb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_audit_event_055aabf6fb ON public.asp_audit_event USING btree (actor_account_id);


--
-- Name: ix_asp_capacity_occupation_14434dcbb9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_capacity_occupation_14434dcbb9 ON public.asp_capacity_occupation USING btree (person_id);


--
-- Name: ix_asp_capacity_occupation_b5f4c6ed4e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_capacity_occupation_b5f4c6ed4e ON public.asp_capacity_occupation USING btree (tenant_id, pool_id);


--
-- Name: ix_asp_capacity_pool_44fc872a06; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_capacity_pool_44fc872a06 ON public.asp_capacity_pool USING btree (tenant_id, unit_id);


--
-- Name: ix_asp_capacity_pool_94e0b99016; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_capacity_pool_94e0b99016 ON public.asp_capacity_pool USING btree (tenant_id, event_id);


--
-- Name: ix_asp_checkin_3cc20a9a3e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_checkin_3cc20a9a3e ON public.asp_checkin USING btree (tenant_id, event_id);


--
-- Name: ix_asp_checkin_3e9e71d86e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_checkin_3e9e71d86e ON public.asp_checkin USING btree (tenant_id, match_id);


--
-- Name: ix_asp_checkin_446f2cc796; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_checkin_446f2cc796 ON public.asp_checkin USING btree (person_id);


--
-- Name: ix_asp_checkin_598a27ddf1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_checkin_598a27ddf1 ON public.asp_checkin USING btree (tenant_id, unit_id);


--
-- Name: ix_asp_collaboration_3d3e434d98; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_collaboration_3d3e434d98 ON public.asp_collaboration USING btree (tenant_id, organization_id);


--
-- Name: ix_asp_collaboration_5ba06833ac; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_collaboration_5ba06833ac ON public.asp_collaboration USING btree (tenant_id, event_id);


--
-- Name: ix_asp_competition_unit_8535df1119; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_competition_unit_8535df1119 ON public.asp_competition_unit USING btree (tenant_id, event_id);


--
-- Name: ix_asp_competition_unit_aa7f9ddb3b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_competition_unit_aa7f9ddb3b ON public.asp_competition_unit USING btree (sport_id);


--
-- Name: ix_asp_complaint_143ba948f2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_complaint_143ba948f2 ON public.asp_complaint USING btree (applicant_account_id);


--
-- Name: ix_asp_consent_68623c10a7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_consent_68623c10a7 ON public.asp_consent USING btree (actor_account_id);


--
-- Name: ix_asp_consent_e38cc432c1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_consent_e38cc432c1 ON public.asp_consent USING btree (person_id);


--
-- Name: ix_asp_data_request_698240e2f8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_data_request_698240e2f8 ON public.asp_data_request USING btree (account_id);


--
-- Name: ix_asp_data_request_894abf225a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_data_request_894abf225a ON public.asp_data_request USING btree (person_id);


--
-- Name: ix_asp_declaration_ack_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_declaration_ack_event ON public.asp_declaration_ack USING btree (tenant_id, event_id);


--
-- Name: ix_asp_draw_run_be023de228; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_draw_run_be023de228 ON public.asp_draw_run USING btree (tenant_id, rule_version_id);


--
-- Name: ix_asp_draw_run_fceb0110bb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_draw_run_fceb0110bb ON public.asp_draw_run USING btree (tenant_id, stage_id);


--
-- Name: ix_asp_entry_field_value_89883310ed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_entry_field_value_89883310ed ON public.asp_entry_field_value USING btree (tenant_id, event_field_id);


--
-- Name: ix_asp_entry_field_value_e0df94b724; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_entry_field_value_e0df94b724 ON public.asp_entry_field_value USING btree (tenant_id, registration_member_id);


--
-- Name: ix_asp_event_ba1502a512; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_event_ba1502a512 ON public.asp_event USING btree (tenant_id, organization_id);


--
-- Name: ix_asp_event_command_b779acfd64; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_event_command_b779acfd64 ON public.asp_event_command USING btree (tenant_id, event_id);


--
-- Name: ix_asp_event_field_e2b0754b6a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_event_field_e2b0754b6a ON public.asp_event_field USING btree (tenant_id, event_id);


--
-- Name: ix_asp_event_field_eca782102f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_event_field_eca782102f ON public.asp_event_field USING btree (tenant_id, org_field_id);


--
-- Name: ix_asp_event_payment_config_fa5895b565; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_event_payment_config_fa5895b565 ON public.asp_event_payment_config USING btree (tenant_id, event_id);


--
-- Name: ix_asp_event_poster_2f80715835; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_event_poster_2f80715835 ON public.asp_event_poster USING btree (tenant_id, event_id);


--
-- Name: ix_asp_event_poster_stat_34cbfeb820; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_event_poster_stat_34cbfeb820 ON public.asp_event_poster_stat USING btree (tenant_id, poster_id);


--
-- Name: ix_asp_event_revision_f1ffb3e031; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_event_revision_f1ffb3e031 ON public.asp_event_revision USING btree (tenant_id, event_id);


--
-- Name: ix_asp_fee_item_387b639c71; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_fee_item_387b639c71 ON public.asp_fee_item USING btree (tenant_id, obligation_id);


--
-- Name: ix_asp_fee_item_c65d43fdbc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_fee_item_c65d43fdbc ON public.asp_fee_item USING btree (person_id);


--
-- Name: ix_asp_fee_obligation_381f50c2e6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_fee_obligation_381f50c2e6 ON public.asp_fee_obligation USING btree (tenant_id, fee_policy_id);


--
-- Name: ix_asp_fee_obligation_a44fb80ed8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_fee_obligation_a44fb80ed8 ON public.asp_fee_obligation USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_fee_policy_a1c8078315; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_fee_policy_a1c8078315 ON public.asp_fee_policy USING btree (tenant_id, unit_id);


--
-- Name: ix_asp_fee_share_957a7049ae; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_fee_share_957a7049ae ON public.asp_fee_share USING btree (account_id);


--
-- Name: ix_asp_fee_share_a56fd0817d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_fee_share_a56fd0817d ON public.asp_fee_share USING btree (tenant_id, obligation_id);


--
-- Name: ix_asp_fee_share_b0b119e510; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_fee_share_b0b119e510 ON public.asp_fee_share USING btree (person_id);


--
-- Name: ix_asp_file_71cbb06677; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_file_71cbb06677 ON public.asp_file USING btree (owner_account_id);


--
-- Name: ix_asp_growth_record_8fb8a219a7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_growth_record_8fb8a219a7 ON public.asp_growth_record USING btree (team_id);


--
-- Name: ix_asp_growth_record_b8e456a801; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_growth_record_b8e456a801 ON public.asp_growth_record USING btree (person_id);


--
-- Name: ix_asp_honor_21af8d4817; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_honor_21af8d4817 ON public.asp_honor USING btree (tenant_id, event_id);


--
-- Name: ix_asp_honor_619408751b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_honor_619408751b ON public.asp_honor USING btree (person_id);


--
-- Name: ix_asp_honor_847eba6f19; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_honor_847eba6f19 ON public.asp_honor USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_honor_8b978dd3d7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_honor_8b978dd3d7 ON public.asp_honor USING btree (team_id);


--
-- Name: ix_asp_honor_certification_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_honor_certification_queue ON public.asp_honor USING btree (certification_status, update_time) WHERE (certification_status IS NOT NULL);


--
-- Name: ix_asp_idempotency_362594cd27; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_idempotency_362594cd27 ON public.asp_idempotency USING btree (account_id);


--
-- Name: ix_asp_lineup_member_0f3cbbbe80; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_lineup_member_0f3cbbbe80 ON public.asp_lineup_member USING btree (tenant_id, roster_member_id);


--
-- Name: ix_asp_lineup_member_a761239472; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_lineup_member_a761239472 ON public.asp_lineup_member USING btree (tenant_id, match_entry_id);


--
-- Name: ix_asp_login_identity_77f45262fd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_login_identity_77f45262fd ON public.asp_login_identity USING btree (account_id);


--
-- Name: ix_asp_match_4b3dd35375; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_match_4b3dd35375 ON public.asp_match USING btree (tenant_id, resource_id);


--
-- Name: ix_asp_match_8f34176002; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_match_8f34176002 ON public.asp_match USING btree (tenant_id, schedule_run_id);


--
-- Name: ix_asp_match_c2cf93ae06; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_match_c2cf93ae06 ON public.asp_match USING btree (tenant_id, stage_id);


--
-- Name: ix_asp_match_entry_4907f195db; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_match_entry_4907f195db ON public.asp_match_entry USING btree (tenant_id, roster_version_id);


--
-- Name: ix_asp_match_entry_8fa587a58f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_match_entry_8fa587a58f ON public.asp_match_entry USING btree (tenant_id, match_id);


--
-- Name: ix_asp_match_entry_ab5db3318d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_match_entry_ab5db3318d ON public.asp_match_entry USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_material_requirement_e44238f2fd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_material_requirement_e44238f2fd ON public.asp_material_requirement USING btree (tenant_id, rule_version_id);


--
-- Name: ix_asp_material_submission_2247bbd71d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_material_submission_2247bbd71d ON public.asp_material_submission USING btree (tenant_id, roster_member_id);


--
-- Name: ix_asp_material_submission_2c753b4f5d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_material_submission_2c753b4f5d ON public.asp_material_submission USING btree (tenant_id, requirement_id);


--
-- Name: ix_asp_material_submission_e06913ebbf; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_material_submission_e06913ebbf ON public.asp_material_submission USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_material_submission_ec40f1fb3b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_material_submission_ec40f1fb3b ON public.asp_material_submission USING btree (file_id);


--
-- Name: ix_asp_migration_mapping_c8d7b46161; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_migration_mapping_c8d7b46161 ON public.asp_migration_mapping USING btree (tenant_id, batch_id);


--
-- Name: ix_asp_notification_54506f0b85; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_notification_54506f0b85 ON public.asp_notification USING btree (recipient_account_id);


--
-- Name: ix_asp_notification_delivery_4d1557bb10; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_notification_delivery_4d1557bb10 ON public.asp_notification_delivery USING btree (tenant_id, notification_id);


--
-- Name: ix_asp_occupation_reference_1adb05c0a7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_occupation_reference_1adb05c0a7 ON public.asp_occupation_reference USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_occupation_reference_82be73443c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_occupation_reference_82be73443c ON public.asp_occupation_reference USING btree (tenant_id, occupation_id);


--
-- Name: ix_asp_official_assignment_41dc7655f6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_official_assignment_41dc7655f6 ON public.asp_official_assignment USING btree (person_id);


--
-- Name: ix_asp_official_assignment_7b513d632e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_official_assignment_7b513d632e ON public.asp_official_assignment USING btree (tenant_id, match_id);


--
-- Name: ix_asp_org_field_28200406a8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_org_field_28200406a8 ON public.asp_org_field USING btree (tenant_id, organization_id);


--
-- Name: ix_asp_organization_application_9b40cddf36; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_organization_application_9b40cddf36 ON public.asp_organization_application USING btree (applicant_account_id);


--
-- Name: ix_asp_organization_application_reviewer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_organization_application_reviewer ON public.asp_organization_application USING btree (assigned_reviewer_id, status);


--
-- Name: ix_asp_organization_application_version_56a5b63ed9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_organization_application_version_56a5b63ed9 ON public.asp_organization_application_version USING btree (application_id);


--
-- Name: ix_asp_payment_4dcd39863b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_payment_4dcd39863b ON public.asp_payment USING btree (payer_account_id);


--
-- Name: ix_asp_payment_action_4ccbe23792; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_payment_action_4ccbe23792 ON public.asp_payment_action USING btree (tenant_id, payment_id);


--
-- Name: ix_asp_payment_action_ffac68febf; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_payment_action_ffac68febf ON public.asp_payment_action USING btree (tenant_id, obligation_id);


--
-- Name: ix_asp_payment_allocation_edb278edfd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_payment_allocation_edb278edfd ON public.asp_payment_allocation USING btree (tenant_id, payment_id);


--
-- Name: ix_asp_payment_allocation_f2b19b68bb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_payment_allocation_f2b19b68bb ON public.asp_payment_allocation USING btree (tenant_id, share_id);


--
-- Name: ix_asp_payment_allocation_fc85422adc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_payment_allocation_fc85422adc ON public.asp_payment_allocation USING btree (tenant_id, obligation_id);


--
-- Name: ix_asp_payment_exception_792aaaf7cc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_payment_exception_792aaaf7cc ON public.asp_payment_exception USING btree (tenant_id, obligation_id);


--
-- Name: ix_asp_payment_exception_b2f12c109c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_payment_exception_b2f12c109c ON public.asp_payment_exception USING btree (tenant_id, payment_id);


--
-- Name: ix_asp_person_ef99cce6fe; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_person_ef99cce6fe ON public.asp_person USING btree (merged_into_id);


--
-- Name: ix_asp_qualification_9b8109903a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_qualification_9b8109903a ON public.asp_qualification USING btree (tenant_id, organization_id);


--
-- Name: ix_asp_qualification_review_77130e3af5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_qualification_review_77130e3af5 ON public.asp_qualification_review USING btree (tenant_id, roster_member_id);


--
-- Name: ix_asp_qualification_review_babfdefa39; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_qualification_review_babfdefa39 ON public.asp_qualification_review USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_ranking_item_44d2543cf1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_ranking_item_44d2543cf1 ON public.asp_ranking_item USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_ranking_item_bd98d8edf2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_ranking_item_bd98d8edf2 ON public.asp_ranking_item USING btree (tenant_id, ranking_run_id);


--
-- Name: ix_asp_ranking_run_707f86d252; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_ranking_run_707f86d252 ON public.asp_ranking_run USING btree (tenant_id, rule_version_id);


--
-- Name: ix_asp_ranking_run_82944954dd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_ranking_run_82944954dd ON public.asp_ranking_run USING btree (tenant_id, unit_id);


--
-- Name: ix_asp_refund_0889c78c72; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_refund_0889c78c72 ON public.asp_refund USING btree (tenant_id, withdrawal_id);


--
-- Name: ix_asp_refund_4119153df3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_refund_4119153df3 ON public.asp_refund USING btree (tenant_id, allocation_id);


--
-- Name: ix_asp_refund_6c91a131df; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_refund_6c91a131df ON public.asp_refund USING btree (tenant_id, payment_id);


--
-- Name: ix_asp_refund_9796403cc4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_refund_9796403cc4 ON public.asp_refund USING btree (applicant_account_id);


--
-- Name: ix_asp_registration_217fd3d0fd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_217fd3d0fd ON public.asp_registration USING btree (tenant_id, unit_id);


--
-- Name: ix_asp_registration_34a0daff97; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_34a0daff97 ON public.asp_registration USING btree (team_id);


--
-- Name: ix_asp_registration_a0d5d3804d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_a0d5d3804d ON public.asp_registration USING btree (tenant_id, fee_policy_id);


--
-- Name: ix_asp_registration_batch_6523f9e051; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_batch_6523f9e051 ON public.asp_registration_batch USING btree (submitter_account_id);


--
-- Name: ix_asp_registration_bddadcf747; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_bddadcf747 ON public.asp_registration USING btree (operator_account_id);


--
-- Name: ix_asp_registration_c3c2a32d6f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_c3c2a32d6f ON public.asp_registration USING btree (tenant_id, batch_id);


--
-- Name: ix_asp_registration_ee864d6727; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_ee864d6727 ON public.asp_registration USING btree (submitter_account_id);


--
-- Name: ix_asp_registration_f8b0175b47; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_f8b0175b47 ON public.asp_registration USING btree (tenant_id, rule_version_id);


--
-- Name: ix_asp_registration_member_367571c8b9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_member_367571c8b9 ON public.asp_registration_member USING btree (tenant_id, unit_id);


--
-- Name: ix_asp_registration_member_b8c5dafa6d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_member_b8c5dafa6d ON public.asp_registration_member USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_registration_member_c3cc982e77; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_member_c3cc982e77 ON public.asp_registration_member USING btree (account_id);


--
-- Name: ix_asp_registration_member_ffbd266d59; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_member_ffbd266d59 ON public.asp_registration_member USING btree (person_id);


--
-- Name: ix_asp_registration_payment_proof_448352ff99; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_payment_proof_448352ff99 ON public.asp_registration_payment_proof USING btree (file_id);


--
-- Name: ix_asp_registration_payment_proof_4be681417d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_payment_proof_4be681417d ON public.asp_registration_payment_proof USING btree (uploaded_by_account_id);


--
-- Name: ix_asp_registration_payment_proof_a1c013aef4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_payment_proof_a1c013aef4 ON public.asp_registration_payment_proof USING btree (tenant_id, obligation_id);


--
-- Name: ix_asp_registration_payment_proof_cfd6715645; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_payment_proof_cfd6715645 ON public.asp_registration_payment_proof USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_registration_submit_key_48c5af2b13; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_submit_key_48c5af2b13 ON public.asp_registration_submit_key USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_registration_submit_key_6abb4d96f7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_registration_submit_key_6abb4d96f7 ON public.asp_registration_submit_key USING btree (submitter_account_id);


--
-- Name: ix_asp_resource_20d7e5a093; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_resource_20d7e5a093 ON public.asp_resource USING btree (tenant_id, parent_id);


--
-- Name: ix_asp_resource_d336122926; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_resource_d336122926 ON public.asp_resource USING btree (tenant_id, venue_id);


--
-- Name: ix_asp_resource_reservation_70bea28f7e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_resource_reservation_70bea28f7e ON public.asp_resource_reservation USING btree (tenant_id, event_id);


--
-- Name: ix_asp_resource_reservation_d78872c2b3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_resource_reservation_d78872c2b3 ON public.asp_resource_reservation USING btree (tenant_id, resource_id);


--
-- Name: ix_asp_result_item_2f40c34f6f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_result_item_2f40c34f6f ON public.asp_result_item USING btree (tenant_id, result_version_id);


--
-- Name: ix_asp_result_item_9a5d685503; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_result_item_9a5d685503 ON public.asp_result_item USING btree (tenant_id, match_entry_id);


--
-- Name: ix_asp_result_version_01a3014925; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_result_version_01a3014925 ON public.asp_result_version USING btree (tenant_id, previous_id);


--
-- Name: ix_asp_result_version_1c5bad7d2e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_result_version_1c5bad7d2e ON public.asp_result_version USING btree (tenant_id, match_id);


--
-- Name: ix_asp_roster_member_b94356d0b2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_roster_member_b94356d0b2 ON public.asp_roster_member USING btree (person_id);


--
-- Name: ix_asp_roster_member_d30ecbbac1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_roster_member_d30ecbbac1 ON public.asp_roster_member USING btree (tenant_id, roster_version_id);


--
-- Name: ix_asp_roster_version_8fd2ad298f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_roster_version_8fd2ad298f ON public.asp_roster_version USING btree (tenant_id, rule_version_id);


--
-- Name: ix_asp_roster_version_945cc0a5de; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_roster_version_945cc0a5de ON public.asp_roster_version USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_rule_version_47a590e281; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_rule_version_47a590e281 ON public.asp_rule_version USING btree (tenant_id, unit_id);


--
-- Name: ix_asp_schedule_run_c24d09d900; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_schedule_run_c24d09d900 ON public.asp_schedule_run USING btree (tenant_id, draw_run_id);


--
-- Name: ix_asp_schedule_run_de3cc075fb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_schedule_run_de3cc075fb ON public.asp_schedule_run USING btree (tenant_id, stage_id);


--
-- Name: ix_asp_service_fee_8b6014c1b8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_service_fee_8b6014c1b8 ON public.asp_service_fee USING btree (tenant_id, event_id);


--
-- Name: ix_asp_settlement_9a2dc30a01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_settlement_9a2dc30a01 ON public.asp_settlement USING btree (tenant_id, event_id);


--
-- Name: ix_asp_staff_grant_3d19349684; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_staff_grant_3d19349684 ON public.asp_staff_grant USING btree (tenant_id, organization_id);


--
-- Name: ix_asp_staff_grant_f9a5b0f5e5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_staff_grant_f9a5b0f5e5 ON public.asp_staff_grant USING btree (account_id);


--
-- Name: ix_asp_stage_85fc908ca2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_stage_85fc908ca2 ON public.asp_stage USING btree (tenant_id, unit_id);


--
-- Name: ix_asp_stage_f9269c0082; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_stage_f9269c0082 ON public.asp_stage USING btree (tenant_id, rule_version_id);


--
-- Name: ix_asp_team_620fab166c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_620fab166c ON public.asp_team USING btree (creator_account_id);


--
-- Name: ix_asp_team_f026743fd0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_f026743fd0 ON public.asp_team USING btree (captain_person_id);


--
-- Name: ix_asp_team_f98848e1b8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_f98848e1b8 ON public.asp_team USING btree (sport_id);


--
-- Name: ix_asp_team_history_912eca6b66; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_history_912eca6b66 ON public.asp_team_history USING btree (team_id);


--
-- Name: ix_asp_team_invitation_3aa2742054; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_invitation_3aa2742054 ON public.asp_team_invitation USING btree (team_id);


--
-- Name: ix_asp_team_invitation_541edd1125; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_invitation_541edd1125 ON public.asp_team_invitation USING btree (inviter_account_id);


--
-- Name: ix_asp_team_invitation_7d44d535b7; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_invitation_7d44d535b7 ON public.asp_team_invitation USING btree (target_person_id);


--
-- Name: ix_asp_team_join_request_47326fba24; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_join_request_47326fba24 ON public.asp_team_join_request USING btree (reviewer_account_id);


--
-- Name: ix_asp_team_join_request_502a2f141d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_join_request_502a2f141d ON public.asp_team_join_request USING btree (person_id);


--
-- Name: ix_asp_team_join_request_af23f80eb0; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_join_request_af23f80eb0 ON public.asp_team_join_request USING btree (team_id);


--
-- Name: ix_asp_team_member_7591d37c1e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_member_7591d37c1e ON public.asp_team_member USING btree (team_id);


--
-- Name: ix_asp_team_member_b732ce61cb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_member_b732ce61cb ON public.asp_team_member USING btree (person_id);


--
-- Name: ix_asp_team_quota_3a6859e632; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_team_quota_3a6859e632 ON public.asp_team_quota USING btree (account_id);


--
-- Name: ix_asp_time_constraint_2071901409; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_time_constraint_2071901409 ON public.asp_time_constraint USING btree (parent_id);


--
-- Name: ix_asp_time_constraint_a8964e349e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_time_constraint_a8964e349e ON public.asp_time_constraint USING btree (person_id);


--
-- Name: ix_asp_waitlist_41dba4146a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_waitlist_41dba4146a ON public.asp_waitlist USING btree (tenant_id, pool_id);


--
-- Name: ix_asp_waitlist_7980fdb5d5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_waitlist_7980fdb5d5 ON public.asp_waitlist USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_withdrawal_52d060aa3e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_withdrawal_52d060aa3e ON public.asp_withdrawal USING btree (tenant_id, registration_id);


--
-- Name: ix_asp_withdrawal_541124a5f2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_withdrawal_541124a5f2 ON public.asp_withdrawal USING btree (person_id);


--
-- Name: ix_asp_withdrawal_597f30ba70; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_asp_withdrawal_597f30ba70 ON public.asp_withdrawal USING btree (applicant_account_id);


--
-- Name: ix_complaint_object; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_complaint_object ON public.asp_complaint USING btree (object_type, object_id, status);


--
-- Name: ix_growth_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_growth_owner ON public.asp_growth_record USING btree (person_id, team_id, sport_id, event_id);


--
-- Name: ix_matching_unit_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_matching_unit_status ON public.asp_matching_request USING btree (unit_id, status, create_time);


--
-- Name: ix_room_unit_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_room_unit_status ON public.asp_team_room USING btree (unit_id, status);


--
-- Name: ix_run_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_run_owner ON public.asp_agent_run USING btree (actor_type, actor_id, create_time);


--
-- Name: ix_team_share_inviter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_team_share_inviter ON public.asp_team_invitation USING btree (inviter_person_id);


--
-- Name: ix_team_share_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_team_share_source ON public.asp_team_invitation USING btree (share_invitation_id);


--
-- Name: uq_asp_account_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_account_person_id ON public.asp_account USING btree (person_id) WHERE (person_id IS NOT NULL);


--
-- Name: uq_asp_account_tenant_principal_a7d31f54f9; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_account_tenant_principal_a7d31f54f9 ON public.asp_account_tenant_principal USING btree (account_id, tenant_id);


--
-- Name: uq_asp_account_tenant_principal_dc518270da; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_account_tenant_principal_dc518270da ON public.asp_account_tenant_principal USING btree (sys_user_id);


--
-- Name: uq_asp_action_execution_7406d253d8; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_action_execution_7406d253d8 ON public.asp_action_execution USING btree (actor_type, actor_id, action_code, request_key) WHERE ((status)::text = 'succeeded'::text);


--
-- Name: uq_asp_advancement_42f7e9c58c; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_advancement_42f7e9c58c ON public.asp_advancement USING btree (tenant_id, target_stage_id, target_slot) WHERE ((status)::text = 'confirmed'::text);


--
-- Name: uq_asp_agent_db65b3d20b; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_agent_db65b3d20b ON public.asp_agent USING btree (code);


--
-- Name: uq_asp_agent_grant_44fe84c055; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_agent_grant_44fe84c055 ON public.asp_agent_grant USING btree (agent_id, capability_code) WHERE ((status)::text = 'active'::text);


--
-- Name: uq_asp_agent_step_410c5b62e9; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_agent_step_410c5b62e9 ON public.asp_agent_step USING btree (run_id, sequence);


--
-- Name: uq_asp_agent_version_766dffb6fe; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_agent_version_766dffb6fe ON public.asp_agent_version USING btree (agent_id, revision);


--
-- Name: uq_asp_ai_gateway_task_91f15273e8; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_ai_gateway_task_91f15273e8 ON public.asp_ai_gateway_task USING btree (tenant_id, event_id) WHERE (event_id IS NOT NULL);


--
-- Name: uq_asp_ai_task_1e20763a6c; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_ai_task_1e20763a6c ON public.asp_ai_task USING btree (tenant_id, confirm_key) WHERE (confirm_key IS NOT NULL);


--
-- Name: uq_asp_ai_task_file_11e0c240d1; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_ai_task_file_11e0c240d1 ON public.asp_ai_task_file USING btree (tenant_id, task_id, sort_order);


--
-- Name: uq_asp_capability_activation_43a359f141; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_capability_activation_43a359f141 ON public.asp_capability_activation USING btree (code, channel);


--
-- Name: uq_asp_capability_version_283dedea1b; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_capability_version_283dedea1b ON public.asp_capability_version USING btree (code, revision);


--
-- Name: uq_asp_capacity_occupation_4234bf62c2; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_capacity_occupation_4234bf62c2 ON public.asp_capacity_occupation USING btree (tenant_id, pool_id, subject_key) WHERE ((status)::text = ANY ((ARRAY['held'::character varying, 'effective'::character varying])::text[]));


--
-- Name: uq_asp_capacity_pool_a5e7dacf0b; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_capacity_pool_a5e7dacf0b ON public.asp_capacity_pool USING btree (tenant_id, unit_id) WHERE ((unit_id IS NOT NULL) AND ((capacity_unit)::text = 'entry'::text));


--
-- Name: uq_asp_checkin_0262f0772f; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_checkin_0262f0772f ON public.asp_checkin USING btree (tenant_id, event_id, unit_id, person_id) WHERE ((unit_id IS NOT NULL) AND (match_id IS NULL) AND ((status)::text = 'confirmed'::text));


--
-- Name: uq_asp_checkin_42d54f007e; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_checkin_42d54f007e ON public.asp_checkin USING btree (tenant_id, event_id, person_id) WHERE ((unit_id IS NULL) AND (match_id IS NULL) AND ((status)::text = 'confirmed'::text));


--
-- Name: uq_asp_checkin_711722409b; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_checkin_711722409b ON public.asp_checkin USING btree (tenant_id, request_key);


--
-- Name: uq_asp_competition_type_2539bdab90; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_competition_type_2539bdab90 ON public.asp_competition_type USING btree (sport_id, code);


--
-- Name: uq_asp_draw_run_f53550e154; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_draw_run_f53550e154 ON public.asp_draw_run USING btree (tenant_id, stage_id, revision);


--
-- Name: uq_asp_entry_field_value_d662a7c909; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_entry_field_value_d662a7c909 ON public.asp_entry_field_value USING btree (tenant_id, registration_member_id, event_field_id);


--
-- Name: uq_asp_event_command_7ec862025f; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_event_command_7ec862025f ON public.asp_event_command USING btree (tenant_id, action, request_key);


--
-- Name: uq_asp_event_field_97a0e34f0e; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_event_field_97a0e34f0e ON public.asp_event_field USING btree (tenant_id, event_id, org_field_id);


--
-- Name: uq_asp_event_payment_config_fa5895b565; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_event_payment_config_fa5895b565 ON public.asp_event_payment_config USING btree (tenant_id, event_id);


--
-- Name: uq_asp_event_poster_6804b38f56; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_event_poster_6804b38f56 ON public.asp_event_poster USING btree (tenant_id, source_code);


--
-- Name: uq_asp_event_poster_c9f68599d0; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_event_poster_c9f68599d0 ON public.asp_event_poster USING btree (tenant_id, event_id, channel_name);


--
-- Name: uq_asp_event_poster_stat_d5e92612f6; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_event_poster_stat_d5e92612f6 ON public.asp_event_poster_stat USING btree (tenant_id, poster_id, stat_date);


--
-- Name: uq_asp_event_revision_c8379d5a8c; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_event_revision_c8379d5a8c ON public.asp_event_revision USING btree (tenant_id, event_id, revision);


--
-- Name: uq_asp_execution_command_5063f48fca; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_execution_command_5063f48fca ON public.asp_execution_command USING btree (tenant_id, action, request_key);


--
-- Name: uq_asp_fee_obligation_679d7db660; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_fee_obligation_679d7db660 ON public.asp_fee_obligation USING btree (tenant_id, registration_id, request_key);


--
-- Name: uq_asp_fee_obligation_73e66feac9; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_fee_obligation_73e66feac9 ON public.asp_fee_obligation USING btree (tenant_id, registration_id) WHERE ((status)::text = ANY ((ARRAY['not_required'::character varying, 'open'::character varying])::text[]));


--
-- Name: uq_asp_fee_policy_1d97b077a1; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_fee_policy_1d97b077a1 ON public.asp_fee_policy USING btree (tenant_id, unit_id, revision);


--
-- Name: uq_asp_fee_policy_8d57190dfe; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_fee_policy_8d57190dfe ON public.asp_fee_policy USING btree (tenant_id, unit_id) WHERE ((status)::text = 'active'::text);


--
-- Name: uq_asp_file_9194f64174; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_file_9194f64174 ON public.asp_file USING btree (object_key);


--
-- Name: uq_asp_governance_grant_40a98a13e4; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_governance_grant_40a98a13e4 ON public.asp_governance_grant USING btree (sys_user_id, organization_id) WHERE ((status)::text = 'active'::text);


--
-- Name: uq_asp_growth_policy_54670af7b3; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_growth_policy_54670af7b3 ON public.asp_growth_policy USING btree (sport_id, code, revision);


--
-- Name: uq_asp_growth_profile_09683c1fb1; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_growth_profile_09683c1fb1 ON public.asp_growth_profile USING btree (owner_type, owner_id, sport_id);


--
-- Name: uq_asp_honor_c414b7dd7e; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_honor_c414b7dd7e ON public.asp_honor USING btree (tenant_id, award_key, person_id) WHERE (award_key IS NOT NULL);


--
-- Name: uq_asp_honor_f998040b15; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_honor_f998040b15 ON public.asp_honor USING btree (tenant_id, registration_id, person_id, title) WHERE ((registration_id IS NOT NULL) AND ((status)::text = 'verified'::text));


--
-- Name: uq_asp_idempotency_7a30f217c3; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_idempotency_7a30f217c3 ON public.asp_idempotency USING btree (tenant_id, account_id, operation, request_key);


--
-- Name: uq_asp_lineup_member_813d197632; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_lineup_member_813d197632 ON public.asp_lineup_member USING btree (tenant_id, match_entry_id, roster_member_id);


--
-- Name: uq_asp_login_identity_744f4a3e8e; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_login_identity_744f4a3e8e ON public.asp_login_identity USING btree (channel, subject_hash) WHERE (valid_until IS NULL);


--
-- Name: uq_asp_match_43038ff706; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_match_43038ff706 ON public.asp_match USING btree (tenant_id, stage_id, code);


--
-- Name: uq_asp_match_entry_ef50ad9eec; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_match_entry_ef50ad9eec ON public.asp_match_entry USING btree (tenant_id, match_id, slot);


--
-- Name: uq_asp_matching_offer_member_ce321fae43; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_matching_offer_member_ce321fae43 ON public.asp_matching_offer_member USING btree (offer_id, account_id);


--
-- Name: uq_asp_matching_request_e7775cf341; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_matching_request_e7775cf341 ON public.asp_matching_request USING btree (unit_id, account_id) WHERE ((status)::text = ANY ((ARRAY['waiting'::character varying, 'offered'::character varying])::text[]));


--
-- Name: uq_asp_material_requirement_485f48e2db; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_material_requirement_485f48e2db ON public.asp_material_requirement USING btree (tenant_id, rule_version_id, code);


--
-- Name: uq_asp_material_submission_7354dd7460; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_material_submission_7354dd7460 ON public.asp_material_submission USING btree (tenant_id, registration_id, requirement_id, roster_member_id, revision);


--
-- Name: uq_asp_migration_mapping_979f0926d3; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_migration_mapping_979f0926d3 ON public.asp_migration_mapping USING btree (tenant_id, batch_id, object_type, source_key);


--
-- Name: uq_asp_notification_51234987a2; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_notification_51234987a2 ON public.asp_notification USING btree (tenant_id, recipient_account_id, dedupe_key);


--
-- Name: uq_asp_notification_delivery_d5acc6e672; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_notification_delivery_d5acc6e672 ON public.asp_notification_delivery USING btree (tenant_id, notification_id, channel, attempt);


--
-- Name: uq_asp_occupation_reference_b12e8bc97c; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_occupation_reference_b12e8bc97c ON public.asp_occupation_reference USING btree (tenant_id, occupation_id, registration_id) WHERE ((status)::text = 'active'::text);


--
-- Name: uq_asp_org_field_9a30614e40; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_org_field_9a30614e40 ON public.asp_org_field USING btree (tenant_id, organization_id, code);


--
-- Name: uq_asp_organization_8a2fba9ad2; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_organization_8a2fba9ad2 ON public.asp_organization USING btree (tenant_id, subject_hash) WHERE (subject_hash IS NOT NULL);


--
-- Name: uq_asp_organization_application_9b40cddf36; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_organization_application_9b40cddf36 ON public.asp_organization_application USING btree (applicant_account_id);


--
-- Name: uq_asp_organization_application_version_5c7aaefaa6; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_organization_application_version_5c7aaefaa6 ON public.asp_organization_application_version USING btree (application_id, revision);


--
-- Name: uq_asp_outbox_70dab87176; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_outbox_70dab87176 ON public.asp_outbox USING btree (tenant_id, event_key);


--
-- Name: uq_asp_payment_46d600621b; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_payment_46d600621b ON public.asp_payment USING btree (tenant_id, payee_subject, transaction_id) WHERE (transaction_id IS NOT NULL);


--
-- Name: uq_asp_payment_63d8b067a7; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_payment_63d8b067a7 ON public.asp_payment USING btree (tenant_id, request_key);


--
-- Name: uq_asp_payment_action_88dcbe3096; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_payment_action_88dcbe3096 ON public.asp_payment_action USING btree (tenant_id, payment_id) WHERE ((status)::text = 'pending'::text);


--
-- Name: uq_asp_payment_allocation_7550106937; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_payment_allocation_7550106937 ON public.asp_payment_allocation USING btree (tenant_id, payment_id, request_key);


--
-- Name: uq_asp_person_bc84cd008f; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_person_bc84cd008f ON public.asp_person USING btree (identity_hash) WHERE ((identity_hash IS NOT NULL) AND ((status)::text = 'active'::text));


--
-- Name: uq_asp_profile_display_4004d8b172; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_profile_display_4004d8b172 ON public.asp_profile_display USING btree (account_id);


--
-- Name: uq_asp_qualification_f0fca6bd13; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_qualification_f0fca6bd13 ON public.asp_qualification USING btree (tenant_id, organization_id, revision);


--
-- Name: uq_asp_ranking_item_5ee4e98c43; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_ranking_item_5ee4e98c43 ON public.asp_ranking_item USING btree (tenant_id, ranking_run_id, registration_id);


--
-- Name: uq_asp_ranking_run_6aca9c4176; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_ranking_run_6aca9c4176 ON public.asp_ranking_run USING btree (tenant_id, unit_id, revision);


--
-- Name: uq_asp_recruitment_ead6f77273; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_recruitment_ead6f77273 ON public.asp_recruitment USING btree (room_id) WHERE ((status)::text = 'open'::text);


--
-- Name: uq_asp_refund_c08c271c10; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_refund_c08c271c10 ON public.asp_refund USING btree (tenant_id, payment_id, request_key);


--
-- Name: uq_asp_registration_5795931c89; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_registration_5795931c89 ON public.asp_registration USING btree (tenant_id, submitter_account_id, request_key);


--
-- Name: uq_asp_registration_batch_5aeb3df352; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_registration_batch_5aeb3df352 ON public.asp_registration_batch USING btree (tenant_id, submitter_account_id, request_key);


--
-- Name: uq_asp_registration_f61f3032ee; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_registration_f61f3032ee ON public.asp_registration USING btree (tenant_id, unit_id, submitter_account_id);


--
-- Name: uq_asp_registration_member_6da214a13c; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_registration_member_6da214a13c ON public.asp_registration_member USING btree (tenant_id, unit_id, account_id) WHERE (occupying = true);


--
-- Name: uq_asp_registration_member_8696a1f9b7; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_registration_member_8696a1f9b7 ON public.asp_registration_member USING btree (tenant_id, registration_id, account_id);


--
-- Name: uq_asp_registration_member_95aaf903f1; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_registration_member_95aaf903f1 ON public.asp_registration_member USING btree (tenant_id, invite_token) WHERE (invite_token IS NOT NULL);


--
-- Name: uq_asp_registration_payment_proof_06f2d49b8e; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_registration_payment_proof_06f2d49b8e ON public.asp_registration_payment_proof USING btree (tenant_id, obligation_id, uploaded_by_account_id, request_key);


--
-- Name: uq_asp_registration_payment_proof_448352ff99; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_registration_payment_proof_448352ff99 ON public.asp_registration_payment_proof USING btree (tenant_id, file_id);


--
-- Name: uq_asp_registration_submit_key_1f6ecc624c; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_registration_submit_key_1f6ecc624c ON public.asp_registration_submit_key USING btree (tenant_id, submitter_account_id, request_key);


--
-- Name: uq_asp_registration_submit_key_e7847965a9; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_registration_submit_key_e7847965a9 ON public.asp_registration_submit_key USING btree (tenant_id, registration_id, roster_revision);


--
-- Name: uq_asp_result_item_0840c62a07; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_result_item_0840c62a07 ON public.asp_result_item USING btree (tenant_id, result_version_id, match_entry_id);


--
-- Name: uq_asp_result_version_5dda592a74; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_result_version_5dda592a74 ON public.asp_result_version USING btree (tenant_id, match_id, revision);


--
-- Name: uq_asp_room_interaction_49044ce0f8; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_room_interaction_49044ce0f8 ON public.asp_room_interaction USING btree (account_id, request_key);


--
-- Name: uq_asp_roster_member_d3f3554a9f; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_roster_member_d3f3554a9f ON public.asp_roster_member USING btree (tenant_id, roster_version_id, person_id);


--
-- Name: uq_asp_roster_version_6b1031feba; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_roster_version_6b1031feba ON public.asp_roster_version USING btree (tenant_id, registration_id, revision);


--
-- Name: uq_asp_rule_version_59801a3a8d; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_rule_version_59801a3a8d ON public.asp_rule_version USING btree (tenant_id, unit_id, revision);


--
-- Name: uq_asp_schedule_run_e428b3f84c; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_schedule_run_e428b3f84c ON public.asp_schedule_run USING btree (tenant_id, stage_id, revision);


--
-- Name: uq_asp_settlement_a3c4d75445; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_settlement_a3c4d75445 ON public.asp_settlement USING btree (tenant_id, subject, reference);


--
-- Name: uq_asp_sport_64fed3dbd2; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_sport_64fed3dbd2 ON public.asp_sport USING btree (code);


--
-- Name: uq_asp_stage_7e51921066; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_stage_7e51921066 ON public.asp_stage USING btree (tenant_id, unit_id, sequence);


--
-- Name: uq_asp_team_invitation_6300200126; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_team_invitation_6300200126 ON public.asp_team_invitation USING btree (team_id, target_person_id) WHERE ((status)::text = 'pending'::text);


--
-- Name: uq_asp_team_join_request_526d694205; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_team_join_request_526d694205 ON public.asp_team_join_request USING btree (team_id, person_id) WHERE ((status)::text = 'pending'::text);


--
-- Name: uq_asp_team_member_f641c8ca15; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_team_member_f641c8ca15 ON public.asp_team_member USING btree (team_id, person_id) WHERE ((status)::text = 'active'::text);


--
-- Name: uq_asp_team_member_ffe09a36d7; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_team_member_ffe09a36d7 ON public.asp_team_member USING btree (team_id) WHERE (((status)::text = 'active'::text) AND ((role)::text = 'captain'::text));


--
-- Name: uq_asp_team_quota_3a6859e632; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_team_quota_3a6859e632 ON public.asp_team_quota USING btree (account_id);


--
-- Name: uq_asp_team_room_member_25616d439d; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_team_room_member_25616d439d ON public.asp_team_room_member USING btree (room_id, account_id) WHERE ((status)::text = 'active'::text);


--
-- Name: uq_asp_team_room_member_32b8256ff6; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_team_room_member_32b8256ff6 ON public.asp_team_room_member USING btree (unit_id, account_id) WHERE ((status)::text = 'active'::text);


--
-- Name: uq_asp_title_equipment_32b7cc75d3; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_title_equipment_32b7cc75d3 ON public.asp_title_equipment USING btree (owner_type, owner_id, sport_id);


--
-- Name: uq_asp_waitlist_695512a614; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_asp_waitlist_695512a614 ON public.asp_waitlist USING btree (tenant_id, registration_id, pool_id) WHERE ((status)::text = ANY ((ARRAY['waiting'::character varying, 'invited'::character varying])::text[]));


--
-- Name: uq_growth_source_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_growth_source_key ON public.asp_growth_record USING btree (source_key) WHERE (source_key IS NOT NULL);


--
-- Name: uq_team_pending_share; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_team_pending_share ON public.asp_team_invitation USING btree (team_id) WHERE (((invitation_kind)::text = 'share'::text) AND ((status)::text = 'pending'::text));


--
-- Name: uq_team_share_acceptance; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_team_share_acceptance ON public.asp_team_invitation USING btree (share_invitation_id, target_person_id) WHERE (share_invitation_id IS NOT NULL);


--
-- Name: uq_team_share_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_team_share_token ON public.asp_team_invitation USING btree (invite_token) WHERE (invite_token IS NOT NULL);


--
-- Name: uq_unit_event_display_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_unit_event_display_name ON public.asp_competition_unit USING btree (tenant_id, event_id, lower(btrim((name)::text))) WHERE ((status)::text = 'open'::text);


--
-- Name: ux_asp_honor_certified_worn; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_asp_honor_certified_worn ON public.asp_honor USING btree (person_id, sport_id) WHERE (((certification_status)::text = 'approved'::text) AND certification_worn);


--
-- Name: asp_competition_unit asp_competition_unit_competition_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_competition_unit
    ADD CONSTRAINT asp_competition_unit_competition_type_id_fkey FOREIGN KEY (competition_type_id) REFERENCES public.asp_competition_type(id);


--
-- Name: asp_growth_record asp_growth_record_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_growth_record
    ADD CONSTRAINT asp_growth_record_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.asp_event(id);


--
-- Name: asp_growth_record asp_growth_record_sport_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_growth_record
    ADD CONSTRAINT asp_growth_record_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES public.asp_sport(id);


--
-- Name: asp_honor asp_honor_applicant_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_honor
    ADD CONSTRAINT asp_honor_applicant_account_id_fkey FOREIGN KEY (applicant_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_honor asp_honor_sport_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_honor
    ADD CONSTRAINT asp_honor_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES public.asp_sport(id);


--
-- Name: asp_registration asp_registration_manager_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration
    ADD CONSTRAINT asp_registration_manager_account_id_fkey FOREIGN KEY (manager_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_account fk_asp_account_person_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_account
    ADD CONSTRAINT fk_asp_account_person_id FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_account_tenant_principal fk_asp_account_tenant_principal_9b72fe7744; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_account_tenant_principal
    ADD CONSTRAINT fk_asp_account_tenant_principal_9b72fe7744 FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_action_confirmation fk_asp_action_confirmation_c3695ffd29; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_action_confirmation
    ADD CONSTRAINT fk_asp_action_confirmation_c3695ffd29 FOREIGN KEY (run_id) REFERENCES public.asp_agent_run(id);


--
-- Name: asp_advancement fk_asp_advancement_8de3a730b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_advancement
    ADD CONSTRAINT fk_asp_advancement_8de3a730b7 FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_advancement fk_asp_advancement_e6fdd62047; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_advancement
    ADD CONSTRAINT fk_asp_advancement_e6fdd62047 FOREIGN KEY (tenant_id, result_version_id) REFERENCES public.asp_result_version(tenant_id, id);


--
-- Name: asp_advancement fk_asp_advancement_f36c110b02; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_advancement
    ADD CONSTRAINT fk_asp_advancement_f36c110b02 FOREIGN KEY (tenant_id, target_stage_id) REFERENCES public.asp_stage(tenant_id, id);


--
-- Name: asp_agent_grant fk_asp_agent_grant_d058814e58; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_agent_grant
    ADD CONSTRAINT fk_asp_agent_grant_d058814e58 FOREIGN KEY (agent_id) REFERENCES public.asp_agent(id);


--
-- Name: asp_agent_message fk_asp_agent_message_3a55415c04; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_agent_message
    ADD CONSTRAINT fk_asp_agent_message_3a55415c04 FOREIGN KEY (run_id) REFERENCES public.asp_agent_run(id);


--
-- Name: asp_agent_run fk_asp_agent_run_c34bdeca1e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_agent_run
    ADD CONSTRAINT fk_asp_agent_run_c34bdeca1e FOREIGN KEY (agent_version_id) REFERENCES public.asp_agent_version(id);


--
-- Name: asp_agent_step fk_asp_agent_step_800194d51b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_agent_step
    ADD CONSTRAINT fk_asp_agent_step_800194d51b FOREIGN KEY (run_id) REFERENCES public.asp_agent_run(id);


--
-- Name: asp_agent_version fk_asp_agent_version_bc45a3950a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_agent_version
    ADD CONSTRAINT fk_asp_agent_version_bc45a3950a FOREIGN KEY (agent_id) REFERENCES public.asp_agent(id);


--
-- Name: asp_ai_gateway_call fk_asp_ai_gateway_call_9695a1aaa1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_gateway_call
    ADD CONSTRAINT fk_asp_ai_gateway_call_9695a1aaa1 FOREIGN KEY (tenant_id, task_id) REFERENCES public.asp_ai_gateway_task(tenant_id, id);


--
-- Name: asp_ai_gateway_task fk_asp_ai_gateway_task_4046cbd2ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_gateway_task
    ADD CONSTRAINT fk_asp_ai_gateway_task_4046cbd2ed FOREIGN KEY (tenant_id, organization_id) REFERENCES public.asp_organization(tenant_id, id);


--
-- Name: asp_ai_gateway_task fk_asp_ai_gateway_task_c8d07e9cef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_gateway_task
    ADD CONSTRAINT fk_asp_ai_gateway_task_c8d07e9cef FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_ai_invocation fk_asp_ai_invocation_465b59edc7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_invocation
    ADD CONSTRAINT fk_asp_ai_invocation_465b59edc7 FOREIGN KEY (tenant_id, task_id) REFERENCES public.asp_ai_task(tenant_id, id);


--
-- Name: asp_ai_task fk_asp_ai_task_bbd1b2b033; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_task
    ADD CONSTRAINT fk_asp_ai_task_bbd1b2b033 FOREIGN KEY (tenant_id, organization_id) REFERENCES public.asp_organization(tenant_id, id);


--
-- Name: asp_ai_task_file fk_asp_ai_task_file_ae615e316c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ai_task_file
    ADD CONSTRAINT fk_asp_ai_task_file_ae615e316c FOREIGN KEY (tenant_id, task_id) REFERENCES public.asp_ai_task(tenant_id, id);


--
-- Name: asp_appeal fk_asp_appeal_11fff99669; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_appeal
    ADD CONSTRAINT fk_asp_appeal_11fff99669 FOREIGN KEY (tenant_id, match_id) REFERENCES public.asp_match(tenant_id, id);


--
-- Name: asp_appeal fk_asp_appeal_31cfd37310; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_appeal
    ADD CONSTRAINT fk_asp_appeal_31cfd37310 FOREIGN KEY (applicant_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_appeal fk_asp_appeal_5b2c3f012c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_appeal
    ADD CONSTRAINT fk_asp_appeal_5b2c3f012c FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_appeal fk_asp_appeal_c2f5a9575f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_appeal
    ADD CONSTRAINT fk_asp_appeal_c2f5a9575f FOREIGN KEY (tenant_id, result_version_id) REFERENCES public.asp_result_version(tenant_id, id);


--
-- Name: asp_audit_event fk_asp_audit_event_055aabf6fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_audit_event
    ADD CONSTRAINT fk_asp_audit_event_055aabf6fb FOREIGN KEY (actor_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_capability_activation fk_asp_capability_activation_907a689487; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_capability_activation
    ADD CONSTRAINT fk_asp_capability_activation_907a689487 FOREIGN KEY (capability_version_id) REFERENCES public.asp_capability_version(id);


--
-- Name: asp_capacity_occupation fk_asp_capacity_occupation_14434dcbb9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_capacity_occupation
    ADD CONSTRAINT fk_asp_capacity_occupation_14434dcbb9 FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_capacity_occupation fk_asp_capacity_occupation_b5f4c6ed4e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_capacity_occupation
    ADD CONSTRAINT fk_asp_capacity_occupation_b5f4c6ed4e FOREIGN KEY (tenant_id, pool_id) REFERENCES public.asp_capacity_pool(tenant_id, id);


--
-- Name: asp_capacity_pool fk_asp_capacity_pool_44fc872a06; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_capacity_pool
    ADD CONSTRAINT fk_asp_capacity_pool_44fc872a06 FOREIGN KEY (tenant_id, unit_id) REFERENCES public.asp_competition_unit(tenant_id, id);


--
-- Name: asp_capacity_pool fk_asp_capacity_pool_94e0b99016; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_capacity_pool
    ADD CONSTRAINT fk_asp_capacity_pool_94e0b99016 FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_checkin fk_asp_checkin_3cc20a9a3e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_checkin
    ADD CONSTRAINT fk_asp_checkin_3cc20a9a3e FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_checkin fk_asp_checkin_3e9e71d86e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_checkin
    ADD CONSTRAINT fk_asp_checkin_3e9e71d86e FOREIGN KEY (tenant_id, match_id) REFERENCES public.asp_match(tenant_id, id);


--
-- Name: asp_checkin fk_asp_checkin_446f2cc796; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_checkin
    ADD CONSTRAINT fk_asp_checkin_446f2cc796 FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_checkin fk_asp_checkin_598a27ddf1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_checkin
    ADD CONSTRAINT fk_asp_checkin_598a27ddf1 FOREIGN KEY (tenant_id, unit_id) REFERENCES public.asp_competition_unit(tenant_id, id);


--
-- Name: asp_collaboration fk_asp_collaboration_3d3e434d98; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_collaboration
    ADD CONSTRAINT fk_asp_collaboration_3d3e434d98 FOREIGN KEY (tenant_id, organization_id) REFERENCES public.asp_organization(tenant_id, id);


--
-- Name: asp_collaboration fk_asp_collaboration_5ba06833ac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_collaboration
    ADD CONSTRAINT fk_asp_collaboration_5ba06833ac FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_competition_type fk_asp_competition_type_171c7d41bc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_competition_type
    ADD CONSTRAINT fk_asp_competition_type_171c7d41bc FOREIGN KEY (sport_id) REFERENCES public.asp_sport(id);


--
-- Name: asp_competition_unit fk_asp_competition_unit_8535df1119; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_competition_unit
    ADD CONSTRAINT fk_asp_competition_unit_8535df1119 FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_competition_unit fk_asp_competition_unit_aa7f9ddb3b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_competition_unit
    ADD CONSTRAINT fk_asp_competition_unit_aa7f9ddb3b FOREIGN KEY (sport_id) REFERENCES public.asp_sport(id);


--
-- Name: asp_complaint fk_asp_complaint_143ba948f2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_complaint
    ADD CONSTRAINT fk_asp_complaint_143ba948f2 FOREIGN KEY (applicant_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_complaint_message fk_asp_complaint_message_df2b4cf5af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_complaint_message
    ADD CONSTRAINT fk_asp_complaint_message_df2b4cf5af FOREIGN KEY (complaint_id) REFERENCES public.asp_complaint(id);


--
-- Name: asp_consent fk_asp_consent_68623c10a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_consent
    ADD CONSTRAINT fk_asp_consent_68623c10a7 FOREIGN KEY (actor_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_consent fk_asp_consent_e38cc432c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_consent
    ADD CONSTRAINT fk_asp_consent_e38cc432c1 FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_data_request fk_asp_data_request_698240e2f8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_data_request
    ADD CONSTRAINT fk_asp_data_request_698240e2f8 FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_data_request fk_asp_data_request_894abf225a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_data_request
    ADD CONSTRAINT fk_asp_data_request_894abf225a FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_draw_run fk_asp_draw_run_be023de228; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_draw_run
    ADD CONSTRAINT fk_asp_draw_run_be023de228 FOREIGN KEY (tenant_id, rule_version_id) REFERENCES public.asp_rule_version(tenant_id, id);


--
-- Name: asp_draw_run fk_asp_draw_run_fceb0110bb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_draw_run
    ADD CONSTRAINT fk_asp_draw_run_fceb0110bb FOREIGN KEY (tenant_id, stage_id) REFERENCES public.asp_stage(tenant_id, id);


--
-- Name: asp_entry_field_value fk_asp_entry_field_value_89883310ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_entry_field_value
    ADD CONSTRAINT fk_asp_entry_field_value_89883310ed FOREIGN KEY (tenant_id, event_field_id) REFERENCES public.asp_event_field(tenant_id, id);


--
-- Name: asp_entry_field_value fk_asp_entry_field_value_e0df94b724; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_entry_field_value
    ADD CONSTRAINT fk_asp_entry_field_value_e0df94b724 FOREIGN KEY (tenant_id, registration_member_id) REFERENCES public.asp_registration_member(tenant_id, id);


--
-- Name: asp_event fk_asp_event_ba1502a512; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event
    ADD CONSTRAINT fk_asp_event_ba1502a512 FOREIGN KEY (tenant_id, organization_id) REFERENCES public.asp_organization(tenant_id, id);


--
-- Name: asp_event_command fk_asp_event_command_b779acfd64; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_command
    ADD CONSTRAINT fk_asp_event_command_b779acfd64 FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_event_field fk_asp_event_field_e2b0754b6a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_field
    ADD CONSTRAINT fk_asp_event_field_e2b0754b6a FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_event_field fk_asp_event_field_eca782102f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_field
    ADD CONSTRAINT fk_asp_event_field_eca782102f FOREIGN KEY (tenant_id, org_field_id) REFERENCES public.asp_org_field(tenant_id, id);


--
-- Name: asp_event_payment_config fk_asp_event_payment_config_fa5895b565; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_payment_config
    ADD CONSTRAINT fk_asp_event_payment_config_fa5895b565 FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_event_poster fk_asp_event_poster_2f80715835; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_poster
    ADD CONSTRAINT fk_asp_event_poster_2f80715835 FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_event_poster_stat fk_asp_event_poster_stat_34cbfeb820; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_poster_stat
    ADD CONSTRAINT fk_asp_event_poster_stat_34cbfeb820 FOREIGN KEY (tenant_id, poster_id) REFERENCES public.asp_event_poster(tenant_id, id);


--
-- Name: asp_event_revision fk_asp_event_revision_f1ffb3e031; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_event_revision
    ADD CONSTRAINT fk_asp_event_revision_f1ffb3e031 FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_fee_item fk_asp_fee_item_387b639c71; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_item
    ADD CONSTRAINT fk_asp_fee_item_387b639c71 FOREIGN KEY (tenant_id, obligation_id) REFERENCES public.asp_fee_obligation(tenant_id, id);


--
-- Name: asp_fee_item fk_asp_fee_item_c65d43fdbc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_item
    ADD CONSTRAINT fk_asp_fee_item_c65d43fdbc FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_fee_obligation fk_asp_fee_obligation_381f50c2e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_obligation
    ADD CONSTRAINT fk_asp_fee_obligation_381f50c2e6 FOREIGN KEY (tenant_id, fee_policy_id) REFERENCES public.asp_fee_policy(tenant_id, id);


--
-- Name: asp_fee_obligation fk_asp_fee_obligation_a44fb80ed8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_obligation
    ADD CONSTRAINT fk_asp_fee_obligation_a44fb80ed8 FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_fee_policy fk_asp_fee_policy_a1c8078315; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_policy
    ADD CONSTRAINT fk_asp_fee_policy_a1c8078315 FOREIGN KEY (tenant_id, unit_id) REFERENCES public.asp_competition_unit(tenant_id, id);


--
-- Name: asp_fee_share fk_asp_fee_share_957a7049ae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_share
    ADD CONSTRAINT fk_asp_fee_share_957a7049ae FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_fee_share fk_asp_fee_share_a56fd0817d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_share
    ADD CONSTRAINT fk_asp_fee_share_a56fd0817d FOREIGN KEY (tenant_id, obligation_id) REFERENCES public.asp_fee_obligation(tenant_id, id);


--
-- Name: asp_fee_share fk_asp_fee_share_b0b119e510; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_fee_share
    ADD CONSTRAINT fk_asp_fee_share_b0b119e510 FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_file fk_asp_file_71cbb06677; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_file
    ADD CONSTRAINT fk_asp_file_71cbb06677 FOREIGN KEY (owner_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_governance_grant fk_asp_governance_grant_9046659b25; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_governance_grant
    ADD CONSTRAINT fk_asp_governance_grant_9046659b25 FOREIGN KEY (organization_id) REFERENCES public.asp_organization(id);


--
-- Name: asp_growth_policy fk_asp_growth_policy_72dce142e4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_growth_policy
    ADD CONSTRAINT fk_asp_growth_policy_72dce142e4 FOREIGN KEY (sport_id) REFERENCES public.asp_sport(id);


--
-- Name: asp_growth_profile fk_asp_growth_profile_5431d8e0c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_growth_profile
    ADD CONSTRAINT fk_asp_growth_profile_5431d8e0c8 FOREIGN KEY (sport_id) REFERENCES public.asp_sport(id);


--
-- Name: asp_growth_record fk_asp_growth_record_8fb8a219a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_growth_record
    ADD CONSTRAINT fk_asp_growth_record_8fb8a219a7 FOREIGN KEY (team_id) REFERENCES public.asp_team(id);


--
-- Name: asp_growth_record fk_asp_growth_record_b8e456a801; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_growth_record
    ADD CONSTRAINT fk_asp_growth_record_b8e456a801 FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_honor fk_asp_honor_21af8d4817; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_honor
    ADD CONSTRAINT fk_asp_honor_21af8d4817 FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_honor fk_asp_honor_619408751b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_honor
    ADD CONSTRAINT fk_asp_honor_619408751b FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_honor fk_asp_honor_847eba6f19; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_honor
    ADD CONSTRAINT fk_asp_honor_847eba6f19 FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_honor fk_asp_honor_8b978dd3d7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_honor
    ADD CONSTRAINT fk_asp_honor_8b978dd3d7 FOREIGN KEY (team_id) REFERENCES public.asp_team(id);


--
-- Name: asp_idempotency fk_asp_idempotency_362594cd27; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_idempotency
    ADD CONSTRAINT fk_asp_idempotency_362594cd27 FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_lineup_member fk_asp_lineup_member_0f3cbbbe80; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_lineup_member
    ADD CONSTRAINT fk_asp_lineup_member_0f3cbbbe80 FOREIGN KEY (tenant_id, roster_member_id) REFERENCES public.asp_roster_member(tenant_id, id);


--
-- Name: asp_lineup_member fk_asp_lineup_member_a761239472; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_lineup_member
    ADD CONSTRAINT fk_asp_lineup_member_a761239472 FOREIGN KEY (tenant_id, match_entry_id) REFERENCES public.asp_match_entry(tenant_id, id);


--
-- Name: asp_login_identity fk_asp_login_identity_77f45262fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_login_identity
    ADD CONSTRAINT fk_asp_login_identity_77f45262fd FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_match fk_asp_match_4b3dd35375; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_match
    ADD CONSTRAINT fk_asp_match_4b3dd35375 FOREIGN KEY (tenant_id, resource_id) REFERENCES public.asp_resource(tenant_id, id);


--
-- Name: asp_match fk_asp_match_8f34176002; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_match
    ADD CONSTRAINT fk_asp_match_8f34176002 FOREIGN KEY (tenant_id, schedule_run_id) REFERENCES public.asp_schedule_run(tenant_id, id);


--
-- Name: asp_match fk_asp_match_c2cf93ae06; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_match
    ADD CONSTRAINT fk_asp_match_c2cf93ae06 FOREIGN KEY (tenant_id, stage_id) REFERENCES public.asp_stage(tenant_id, id);


--
-- Name: asp_match_entry fk_asp_match_entry_4907f195db; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_match_entry
    ADD CONSTRAINT fk_asp_match_entry_4907f195db FOREIGN KEY (tenant_id, roster_version_id) REFERENCES public.asp_roster_version(tenant_id, id);


--
-- Name: asp_match_entry fk_asp_match_entry_8fa587a58f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_match_entry
    ADD CONSTRAINT fk_asp_match_entry_8fa587a58f FOREIGN KEY (tenant_id, match_id) REFERENCES public.asp_match(tenant_id, id);


--
-- Name: asp_match_entry fk_asp_match_entry_ab5db3318d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_match_entry
    ADD CONSTRAINT fk_asp_match_entry_ab5db3318d FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_matching_offer fk_asp_matching_offer_77aae21b6b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_matching_offer
    ADD CONSTRAINT fk_asp_matching_offer_77aae21b6b FOREIGN KEY (unit_id) REFERENCES public.asp_competition_unit(id);


--
-- Name: asp_matching_offer fk_asp_matching_offer_7c52f06e1c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_matching_offer
    ADD CONSTRAINT fk_asp_matching_offer_7c52f06e1c FOREIGN KEY (room_id) REFERENCES public.asp_team_room(id);


--
-- Name: asp_matching_offer_member fk_asp_matching_offer_member_302eb57a1b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_matching_offer_member
    ADD CONSTRAINT fk_asp_matching_offer_member_302eb57a1b FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_matching_offer_member fk_asp_matching_offer_member_db8fdcae2e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_matching_offer_member
    ADD CONSTRAINT fk_asp_matching_offer_member_db8fdcae2e FOREIGN KEY (offer_id) REFERENCES public.asp_matching_offer(id);


--
-- Name: asp_matching_offer_member fk_asp_matching_offer_member_f86541945e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_matching_offer_member
    ADD CONSTRAINT fk_asp_matching_offer_member_f86541945e FOREIGN KEY (request_id) REFERENCES public.asp_matching_request(id);


--
-- Name: asp_matching_request fk_asp_matching_request_00493307af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_matching_request
    ADD CONSTRAINT fk_asp_matching_request_00493307af FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_matching_request fk_asp_matching_request_600dd02184; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_matching_request
    ADD CONSTRAINT fk_asp_matching_request_600dd02184 FOREIGN KEY (unit_id) REFERENCES public.asp_competition_unit(id);


--
-- Name: asp_matching_request fk_asp_matching_request_9742c3d66f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_matching_request
    ADD CONSTRAINT fk_asp_matching_request_9742c3d66f FOREIGN KEY (room_id) REFERENCES public.asp_team_room(id);


--
-- Name: asp_material_requirement fk_asp_material_requirement_e44238f2fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_material_requirement
    ADD CONSTRAINT fk_asp_material_requirement_e44238f2fd FOREIGN KEY (tenant_id, rule_version_id) REFERENCES public.asp_rule_version(tenant_id, id);


--
-- Name: asp_material_submission fk_asp_material_submission_2247bbd71d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_material_submission
    ADD CONSTRAINT fk_asp_material_submission_2247bbd71d FOREIGN KEY (tenant_id, roster_member_id) REFERENCES public.asp_roster_member(tenant_id, id);


--
-- Name: asp_material_submission fk_asp_material_submission_2c753b4f5d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_material_submission
    ADD CONSTRAINT fk_asp_material_submission_2c753b4f5d FOREIGN KEY (tenant_id, requirement_id) REFERENCES public.asp_material_requirement(tenant_id, id);


--
-- Name: asp_material_submission fk_asp_material_submission_e06913ebbf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_material_submission
    ADD CONSTRAINT fk_asp_material_submission_e06913ebbf FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_material_submission fk_asp_material_submission_ec40f1fb3b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_material_submission
    ADD CONSTRAINT fk_asp_material_submission_ec40f1fb3b FOREIGN KEY (file_id) REFERENCES public.asp_file(id);


--
-- Name: asp_migration_mapping fk_asp_migration_mapping_c8d7b46161; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_migration_mapping
    ADD CONSTRAINT fk_asp_migration_mapping_c8d7b46161 FOREIGN KEY (tenant_id, batch_id) REFERENCES public.asp_migration_batch(tenant_id, id);


--
-- Name: asp_notification fk_asp_notification_54506f0b85; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_notification
    ADD CONSTRAINT fk_asp_notification_54506f0b85 FOREIGN KEY (recipient_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_notification_delivery fk_asp_notification_delivery_4d1557bb10; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_notification_delivery
    ADD CONSTRAINT fk_asp_notification_delivery_4d1557bb10 FOREIGN KEY (tenant_id, notification_id) REFERENCES public.asp_notification(tenant_id, id);


--
-- Name: asp_occupation_reference fk_asp_occupation_reference_1adb05c0a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_occupation_reference
    ADD CONSTRAINT fk_asp_occupation_reference_1adb05c0a7 FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_occupation_reference fk_asp_occupation_reference_82be73443c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_occupation_reference
    ADD CONSTRAINT fk_asp_occupation_reference_82be73443c FOREIGN KEY (tenant_id, occupation_id) REFERENCES public.asp_capacity_occupation(tenant_id, id);


--
-- Name: asp_official_assignment fk_asp_official_assignment_41dc7655f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_official_assignment
    ADD CONSTRAINT fk_asp_official_assignment_41dc7655f6 FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_official_assignment fk_asp_official_assignment_7b513d632e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_official_assignment
    ADD CONSTRAINT fk_asp_official_assignment_7b513d632e FOREIGN KEY (tenant_id, match_id) REFERENCES public.asp_match(tenant_id, id);


--
-- Name: asp_org_field fk_asp_org_field_28200406a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_org_field
    ADD CONSTRAINT fk_asp_org_field_28200406a8 FOREIGN KEY (tenant_id, organization_id) REFERENCES public.asp_organization(tenant_id, id);


--
-- Name: asp_organization_application fk_asp_organization_application_9b40cddf36; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_organization_application
    ADD CONSTRAINT fk_asp_organization_application_9b40cddf36 FOREIGN KEY (applicant_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_organization_application_version fk_asp_organization_application_version_56a5b63ed9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_organization_application_version
    ADD CONSTRAINT fk_asp_organization_application_version_56a5b63ed9 FOREIGN KEY (application_id) REFERENCES public.asp_organization_application(id);


--
-- Name: asp_payment fk_asp_payment_4dcd39863b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment
    ADD CONSTRAINT fk_asp_payment_4dcd39863b FOREIGN KEY (payer_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_payment_action fk_asp_payment_action_4ccbe23792; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_action
    ADD CONSTRAINT fk_asp_payment_action_4ccbe23792 FOREIGN KEY (tenant_id, payment_id) REFERENCES public.asp_payment(tenant_id, id);


--
-- Name: asp_payment_action fk_asp_payment_action_ffac68febf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_action
    ADD CONSTRAINT fk_asp_payment_action_ffac68febf FOREIGN KEY (tenant_id, obligation_id) REFERENCES public.asp_fee_obligation(tenant_id, id);


--
-- Name: asp_payment_allocation fk_asp_payment_allocation_edb278edfd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_allocation
    ADD CONSTRAINT fk_asp_payment_allocation_edb278edfd FOREIGN KEY (tenant_id, payment_id) REFERENCES public.asp_payment(tenant_id, id);


--
-- Name: asp_payment_allocation fk_asp_payment_allocation_f2b19b68bb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_allocation
    ADD CONSTRAINT fk_asp_payment_allocation_f2b19b68bb FOREIGN KEY (tenant_id, share_id) REFERENCES public.asp_fee_share(tenant_id, id);


--
-- Name: asp_payment_allocation fk_asp_payment_allocation_fc85422adc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_allocation
    ADD CONSTRAINT fk_asp_payment_allocation_fc85422adc FOREIGN KEY (tenant_id, obligation_id) REFERENCES public.asp_fee_obligation(tenant_id, id);


--
-- Name: asp_payment_exception fk_asp_payment_exception_792aaaf7cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_exception
    ADD CONSTRAINT fk_asp_payment_exception_792aaaf7cc FOREIGN KEY (tenant_id, obligation_id) REFERENCES public.asp_fee_obligation(tenant_id, id);


--
-- Name: asp_payment_exception fk_asp_payment_exception_b2f12c109c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_payment_exception
    ADD CONSTRAINT fk_asp_payment_exception_b2f12c109c FOREIGN KEY (tenant_id, payment_id) REFERENCES public.asp_payment(tenant_id, id);


--
-- Name: asp_person fk_asp_person_ef99cce6fe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_person
    ADD CONSTRAINT fk_asp_person_ef99cce6fe FOREIGN KEY (merged_into_id) REFERENCES public.asp_person(id);


--
-- Name: asp_profile_display fk_asp_profile_display_4004d8b172; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_profile_display
    ADD CONSTRAINT fk_asp_profile_display_4004d8b172 FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_qualification fk_asp_qualification_9b8109903a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_qualification
    ADD CONSTRAINT fk_asp_qualification_9b8109903a FOREIGN KEY (tenant_id, organization_id) REFERENCES public.asp_organization(tenant_id, id);


--
-- Name: asp_qualification_review fk_asp_qualification_review_77130e3af5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_qualification_review
    ADD CONSTRAINT fk_asp_qualification_review_77130e3af5 FOREIGN KEY (tenant_id, roster_member_id) REFERENCES public.asp_roster_member(tenant_id, id);


--
-- Name: asp_qualification_review fk_asp_qualification_review_babfdefa39; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_qualification_review
    ADD CONSTRAINT fk_asp_qualification_review_babfdefa39 FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_ranking_item fk_asp_ranking_item_44d2543cf1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ranking_item
    ADD CONSTRAINT fk_asp_ranking_item_44d2543cf1 FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_ranking_item fk_asp_ranking_item_bd98d8edf2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ranking_item
    ADD CONSTRAINT fk_asp_ranking_item_bd98d8edf2 FOREIGN KEY (tenant_id, ranking_run_id) REFERENCES public.asp_ranking_run(tenant_id, id);


--
-- Name: asp_ranking_run fk_asp_ranking_run_707f86d252; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ranking_run
    ADD CONSTRAINT fk_asp_ranking_run_707f86d252 FOREIGN KEY (tenant_id, rule_version_id) REFERENCES public.asp_rule_version(tenant_id, id);


--
-- Name: asp_ranking_run fk_asp_ranking_run_82944954dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_ranking_run
    ADD CONSTRAINT fk_asp_ranking_run_82944954dd FOREIGN KEY (tenant_id, unit_id) REFERENCES public.asp_competition_unit(tenant_id, id);


--
-- Name: asp_recruitment fk_asp_recruitment_753c464296; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_recruitment
    ADD CONSTRAINT fk_asp_recruitment_753c464296 FOREIGN KEY (creator_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_recruitment fk_asp_recruitment_ead6f77273; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_recruitment
    ADD CONSTRAINT fk_asp_recruitment_ead6f77273 FOREIGN KEY (room_id) REFERENCES public.asp_team_room(id);


--
-- Name: asp_refund fk_asp_refund_0889c78c72; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_refund
    ADD CONSTRAINT fk_asp_refund_0889c78c72 FOREIGN KEY (tenant_id, withdrawal_id) REFERENCES public.asp_withdrawal(tenant_id, id);


--
-- Name: asp_refund fk_asp_refund_4119153df3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_refund
    ADD CONSTRAINT fk_asp_refund_4119153df3 FOREIGN KEY (tenant_id, allocation_id) REFERENCES public.asp_payment_allocation(tenant_id, id);


--
-- Name: asp_refund fk_asp_refund_6c91a131df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_refund
    ADD CONSTRAINT fk_asp_refund_6c91a131df FOREIGN KEY (tenant_id, payment_id) REFERENCES public.asp_payment(tenant_id, id);


--
-- Name: asp_refund fk_asp_refund_9796403cc4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_refund
    ADD CONSTRAINT fk_asp_refund_9796403cc4 FOREIGN KEY (applicant_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_registration fk_asp_registration_217fd3d0fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration
    ADD CONSTRAINT fk_asp_registration_217fd3d0fd FOREIGN KEY (tenant_id, unit_id) REFERENCES public.asp_competition_unit(tenant_id, id);


--
-- Name: asp_registration fk_asp_registration_34a0daff97; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration
    ADD CONSTRAINT fk_asp_registration_34a0daff97 FOREIGN KEY (team_id) REFERENCES public.asp_team(id);


--
-- Name: asp_registration fk_asp_registration_a0d5d3804d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration
    ADD CONSTRAINT fk_asp_registration_a0d5d3804d FOREIGN KEY (tenant_id, fee_policy_id) REFERENCES public.asp_fee_policy(tenant_id, id);


--
-- Name: asp_registration_batch fk_asp_registration_batch_6523f9e051; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_batch
    ADD CONSTRAINT fk_asp_registration_batch_6523f9e051 FOREIGN KEY (submitter_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_registration fk_asp_registration_bddadcf747; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration
    ADD CONSTRAINT fk_asp_registration_bddadcf747 FOREIGN KEY (operator_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_registration fk_asp_registration_c3c2a32d6f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration
    ADD CONSTRAINT fk_asp_registration_c3c2a32d6f FOREIGN KEY (tenant_id, batch_id) REFERENCES public.asp_registration_batch(tenant_id, id);


--
-- Name: asp_registration fk_asp_registration_ee864d6727; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration
    ADD CONSTRAINT fk_asp_registration_ee864d6727 FOREIGN KEY (submitter_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_registration fk_asp_registration_f8b0175b47; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration
    ADD CONSTRAINT fk_asp_registration_f8b0175b47 FOREIGN KEY (tenant_id, rule_version_id) REFERENCES public.asp_rule_version(tenant_id, id);


--
-- Name: asp_registration_member fk_asp_registration_member_367571c8b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_member
    ADD CONSTRAINT fk_asp_registration_member_367571c8b9 FOREIGN KEY (tenant_id, unit_id) REFERENCES public.asp_competition_unit(tenant_id, id);


--
-- Name: asp_registration_member fk_asp_registration_member_b8c5dafa6d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_member
    ADD CONSTRAINT fk_asp_registration_member_b8c5dafa6d FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_registration_member fk_asp_registration_member_c3cc982e77; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_member
    ADD CONSTRAINT fk_asp_registration_member_c3cc982e77 FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_registration_member fk_asp_registration_member_ffbd266d59; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_member
    ADD CONSTRAINT fk_asp_registration_member_ffbd266d59 FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_registration_payment_proof fk_asp_registration_payment_proof_448352ff99; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_payment_proof
    ADD CONSTRAINT fk_asp_registration_payment_proof_448352ff99 FOREIGN KEY (file_id) REFERENCES public.asp_file(id);


--
-- Name: asp_registration_payment_proof fk_asp_registration_payment_proof_4be681417d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_payment_proof
    ADD CONSTRAINT fk_asp_registration_payment_proof_4be681417d FOREIGN KEY (uploaded_by_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_registration_payment_proof fk_asp_registration_payment_proof_a1c013aef4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_payment_proof
    ADD CONSTRAINT fk_asp_registration_payment_proof_a1c013aef4 FOREIGN KEY (tenant_id, obligation_id) REFERENCES public.asp_fee_obligation(tenant_id, id);


--
-- Name: asp_registration_payment_proof fk_asp_registration_payment_proof_cfd6715645; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_payment_proof
    ADD CONSTRAINT fk_asp_registration_payment_proof_cfd6715645 FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_registration_submit_key fk_asp_registration_submit_key_48c5af2b13; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_submit_key
    ADD CONSTRAINT fk_asp_registration_submit_key_48c5af2b13 FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_registration_submit_key fk_asp_registration_submit_key_6abb4d96f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_registration_submit_key
    ADD CONSTRAINT fk_asp_registration_submit_key_6abb4d96f7 FOREIGN KEY (submitter_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_resource fk_asp_resource_20d7e5a093; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_resource
    ADD CONSTRAINT fk_asp_resource_20d7e5a093 FOREIGN KEY (tenant_id, parent_id) REFERENCES public.asp_resource(tenant_id, id);


--
-- Name: asp_resource fk_asp_resource_d336122926; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_resource
    ADD CONSTRAINT fk_asp_resource_d336122926 FOREIGN KEY (tenant_id, venue_id) REFERENCES public.asp_venue(tenant_id, id);


--
-- Name: asp_resource_reservation fk_asp_resource_reservation_70bea28f7e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_resource_reservation
    ADD CONSTRAINT fk_asp_resource_reservation_70bea28f7e FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_resource_reservation fk_asp_resource_reservation_d78872c2b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_resource_reservation
    ADD CONSTRAINT fk_asp_resource_reservation_d78872c2b3 FOREIGN KEY (tenant_id, resource_id) REFERENCES public.asp_resource(tenant_id, id);


--
-- Name: asp_result_item fk_asp_result_item_2f40c34f6f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_result_item
    ADD CONSTRAINT fk_asp_result_item_2f40c34f6f FOREIGN KEY (tenant_id, result_version_id) REFERENCES public.asp_result_version(tenant_id, id);


--
-- Name: asp_result_item fk_asp_result_item_9a5d685503; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_result_item
    ADD CONSTRAINT fk_asp_result_item_9a5d685503 FOREIGN KEY (tenant_id, match_entry_id) REFERENCES public.asp_match_entry(tenant_id, id);


--
-- Name: asp_result_version fk_asp_result_version_01a3014925; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_result_version
    ADD CONSTRAINT fk_asp_result_version_01a3014925 FOREIGN KEY (tenant_id, previous_id) REFERENCES public.asp_result_version(tenant_id, id);


--
-- Name: asp_result_version fk_asp_result_version_1c5bad7d2e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_result_version
    ADD CONSTRAINT fk_asp_result_version_1c5bad7d2e FOREIGN KEY (tenant_id, match_id) REFERENCES public.asp_match(tenant_id, id);


--
-- Name: asp_room_interaction fk_asp_room_interaction_5bd69eddfc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_room_interaction
    ADD CONSTRAINT fk_asp_room_interaction_5bd69eddfc FOREIGN KEY (room_id) REFERENCES public.asp_team_room(id);


--
-- Name: asp_room_interaction fk_asp_room_interaction_a43601fbcb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_room_interaction
    ADD CONSTRAINT fk_asp_room_interaction_a43601fbcb FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_roster_member fk_asp_roster_member_b94356d0b2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_roster_member
    ADD CONSTRAINT fk_asp_roster_member_b94356d0b2 FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_roster_member fk_asp_roster_member_d30ecbbac1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_roster_member
    ADD CONSTRAINT fk_asp_roster_member_d30ecbbac1 FOREIGN KEY (tenant_id, roster_version_id) REFERENCES public.asp_roster_version(tenant_id, id);


--
-- Name: asp_roster_version fk_asp_roster_version_8fd2ad298f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_roster_version
    ADD CONSTRAINT fk_asp_roster_version_8fd2ad298f FOREIGN KEY (tenant_id, rule_version_id) REFERENCES public.asp_rule_version(tenant_id, id);


--
-- Name: asp_roster_version fk_asp_roster_version_945cc0a5de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_roster_version
    ADD CONSTRAINT fk_asp_roster_version_945cc0a5de FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_rule_version fk_asp_rule_version_47a590e281; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_rule_version
    ADD CONSTRAINT fk_asp_rule_version_47a590e281 FOREIGN KEY (tenant_id, unit_id) REFERENCES public.asp_competition_unit(tenant_id, id);


--
-- Name: asp_schedule_run fk_asp_schedule_run_c24d09d900; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_schedule_run
    ADD CONSTRAINT fk_asp_schedule_run_c24d09d900 FOREIGN KEY (tenant_id, draw_run_id) REFERENCES public.asp_draw_run(tenant_id, id);


--
-- Name: asp_schedule_run fk_asp_schedule_run_de3cc075fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_schedule_run
    ADD CONSTRAINT fk_asp_schedule_run_de3cc075fb FOREIGN KEY (tenant_id, stage_id) REFERENCES public.asp_stage(tenant_id, id);


--
-- Name: asp_service_fee fk_asp_service_fee_8b6014c1b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_service_fee
    ADD CONSTRAINT fk_asp_service_fee_8b6014c1b8 FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_settlement fk_asp_settlement_9a2dc30a01; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_settlement
    ADD CONSTRAINT fk_asp_settlement_9a2dc30a01 FOREIGN KEY (tenant_id, event_id) REFERENCES public.asp_event(tenant_id, id);


--
-- Name: asp_staff_grant fk_asp_staff_grant_3d19349684; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_staff_grant
    ADD CONSTRAINT fk_asp_staff_grant_3d19349684 FOREIGN KEY (tenant_id, organization_id) REFERENCES public.asp_organization(tenant_id, id);


--
-- Name: asp_staff_grant fk_asp_staff_grant_f9a5b0f5e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_staff_grant
    ADD CONSTRAINT fk_asp_staff_grant_f9a5b0f5e5 FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_stage fk_asp_stage_85fc908ca2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_stage
    ADD CONSTRAINT fk_asp_stage_85fc908ca2 FOREIGN KEY (tenant_id, unit_id) REFERENCES public.asp_competition_unit(tenant_id, id);


--
-- Name: asp_stage fk_asp_stage_f9269c0082; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_stage
    ADD CONSTRAINT fk_asp_stage_f9269c0082 FOREIGN KEY (tenant_id, rule_version_id) REFERENCES public.asp_rule_version(tenant_id, id);


--
-- Name: asp_team fk_asp_team_620fab166c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team
    ADD CONSTRAINT fk_asp_team_620fab166c FOREIGN KEY (creator_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_team fk_asp_team_f026743fd0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team
    ADD CONSTRAINT fk_asp_team_f026743fd0 FOREIGN KEY (captain_person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_team fk_asp_team_f98848e1b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team
    ADD CONSTRAINT fk_asp_team_f98848e1b8 FOREIGN KEY (sport_id) REFERENCES public.asp_sport(id);


--
-- Name: asp_team_history fk_asp_team_history_912eca6b66; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_history
    ADD CONSTRAINT fk_asp_team_history_912eca6b66 FOREIGN KEY (team_id) REFERENCES public.asp_team(id);


--
-- Name: asp_team_invitation fk_asp_team_invitation_3aa2742054; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_invitation
    ADD CONSTRAINT fk_asp_team_invitation_3aa2742054 FOREIGN KEY (team_id) REFERENCES public.asp_team(id);


--
-- Name: asp_team_invitation fk_asp_team_invitation_541edd1125; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_invitation
    ADD CONSTRAINT fk_asp_team_invitation_541edd1125 FOREIGN KEY (inviter_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_team_invitation fk_asp_team_invitation_7d44d535b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_invitation
    ADD CONSTRAINT fk_asp_team_invitation_7d44d535b7 FOREIGN KEY (target_person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_team_join_request fk_asp_team_join_request_47326fba24; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_join_request
    ADD CONSTRAINT fk_asp_team_join_request_47326fba24 FOREIGN KEY (reviewer_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_team_join_request fk_asp_team_join_request_502a2f141d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_join_request
    ADD CONSTRAINT fk_asp_team_join_request_502a2f141d FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_team_join_request fk_asp_team_join_request_af23f80eb0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_join_request
    ADD CONSTRAINT fk_asp_team_join_request_af23f80eb0 FOREIGN KEY (team_id) REFERENCES public.asp_team(id);


--
-- Name: asp_team_member fk_asp_team_member_7591d37c1e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_member
    ADD CONSTRAINT fk_asp_team_member_7591d37c1e FOREIGN KEY (team_id) REFERENCES public.asp_team(id);


--
-- Name: asp_team_member fk_asp_team_member_b732ce61cb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_member
    ADD CONSTRAINT fk_asp_team_member_b732ce61cb FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_team_quota fk_asp_team_quota_3a6859e632; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_quota
    ADD CONSTRAINT fk_asp_team_quota_3a6859e632 FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_team_room fk_asp_team_room_41cce5f02e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_room
    ADD CONSTRAINT fk_asp_team_room_41cce5f02e FOREIGN KEY (host_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_team_room fk_asp_team_room_78abb6d8fa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_room
    ADD CONSTRAINT fk_asp_team_room_78abb6d8fa FOREIGN KEY (competition_type_id) REFERENCES public.asp_competition_type(id);


--
-- Name: asp_team_room fk_asp_team_room_97d2595381; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_room
    ADD CONSTRAINT fk_asp_team_room_97d2595381 FOREIGN KEY (team_id) REFERENCES public.asp_team(id);


--
-- Name: asp_team_room fk_asp_team_room_9bb197d38e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_room
    ADD CONSTRAINT fk_asp_team_room_9bb197d38e FOREIGN KEY (unit_id) REFERENCES public.asp_competition_unit(id);


--
-- Name: asp_team_room_member fk_asp_team_room_member_4e4cf6dc92; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_room_member
    ADD CONSTRAINT fk_asp_team_room_member_4e4cf6dc92 FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_team_room_member fk_asp_team_room_member_5e409a13b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_room_member
    ADD CONSTRAINT fk_asp_team_room_member_5e409a13b7 FOREIGN KEY (account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_team_room_member fk_asp_team_room_member_67b5f29a62; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_room_member
    ADD CONSTRAINT fk_asp_team_room_member_67b5f29a62 FOREIGN KEY (room_id) REFERENCES public.asp_team_room(id);


--
-- Name: asp_team_room_member fk_asp_team_room_member_c364cb6efa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_room_member
    ADD CONSTRAINT fk_asp_team_room_member_c364cb6efa FOREIGN KEY (unit_id) REFERENCES public.asp_competition_unit(id);


--
-- Name: asp_time_constraint fk_asp_time_constraint_2071901409; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_time_constraint
    ADD CONSTRAINT fk_asp_time_constraint_2071901409 FOREIGN KEY (parent_id) REFERENCES public.asp_time_constraint(id);


--
-- Name: asp_time_constraint fk_asp_time_constraint_a8964e349e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_time_constraint
    ADD CONSTRAINT fk_asp_time_constraint_a8964e349e FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_title_equipment fk_asp_title_equipment_75184f7b12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_title_equipment
    ADD CONSTRAINT fk_asp_title_equipment_75184f7b12 FOREIGN KEY (sport_id) REFERENCES public.asp_sport(id);


--
-- Name: asp_title_equipment fk_asp_title_equipment_ba878710fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_title_equipment
    ADD CONSTRAINT fk_asp_title_equipment_ba878710fb FOREIGN KEY (honor_id) REFERENCES public.asp_honor(id);


--
-- Name: asp_waitlist fk_asp_waitlist_41dba4146a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_waitlist
    ADD CONSTRAINT fk_asp_waitlist_41dba4146a FOREIGN KEY (tenant_id, pool_id) REFERENCES public.asp_capacity_pool(tenant_id, id);


--
-- Name: asp_waitlist fk_asp_waitlist_7980fdb5d5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_waitlist
    ADD CONSTRAINT fk_asp_waitlist_7980fdb5d5 FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_withdrawal fk_asp_withdrawal_52d060aa3e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_withdrawal
    ADD CONSTRAINT fk_asp_withdrawal_52d060aa3e FOREIGN KEY (tenant_id, registration_id) REFERENCES public.asp_registration(tenant_id, id);


--
-- Name: asp_withdrawal fk_asp_withdrawal_541124a5f2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_withdrawal
    ADD CONSTRAINT fk_asp_withdrawal_541124a5f2 FOREIGN KEY (person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_withdrawal fk_asp_withdrawal_597f30ba70; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_withdrawal
    ADD CONSTRAINT fk_asp_withdrawal_597f30ba70 FOREIGN KEY (applicant_account_id) REFERENCES public.asp_account(id);


--
-- Name: asp_team_invitation fk_team_share_inviter; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_invitation
    ADD CONSTRAINT fk_team_share_inviter FOREIGN KEY (inviter_person_id) REFERENCES public.asp_person(id);


--
-- Name: asp_team_invitation fk_team_share_source; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asp_team_invitation
    ADD CONSTRAINT fk_team_share_source FOREIGN KEY (share_invitation_id) REFERENCES public.asp_team_invitation(id);


--

COMMENT ON COLUMN public.asp_agent_run.round_key IS '当前预算结算轮次的单向摘要；不是身份凭据，防止旧线程释放新轮次预算';
COMMENT ON COLUMN public.asp_ai_task.consent_version IS '实际告知版本';
COMMENT ON COLUMN public.asp_ai_task.provider_consent IS '对当前资料任务的实际模型供应商告知确认';
COMMENT ON COLUMN public.asp_ai_task.provider_name IS '实际获授权供应商；旧百炼授权保留原含义';
COMMENT ON COLUMN public.asp_competition_unit.competition_type_id IS '统一比赛类型；旧数据按明确人数匹配，不能猜测未支持类型';
COMMENT ON COLUMN public.asp_declaration_ack.account_id IS '点击确认的平台账号，必须是该成员本人';
COMMENT ON COLUMN public.asp_declaration_ack.create_by IS '创建操作后台主体或服务主体；不是实际参赛人';
COMMENT ON COLUMN public.asp_declaration_ack.create_dept IS '操作创建部门；上游审计字段';
COMMENT ON COLUMN public.asp_declaration_ack.create_time IS '记录创建时间；不同于实际发生时间';
COMMENT ON COLUMN public.asp_declaration_ack.event_id IS '声明所属赛事';
COMMENT ON COLUMN public.asp_declaration_ack.id IS '应用分配的稳定雪花 ID；不能随变更重建';
COMMENT ON COLUMN public.asp_declaration_ack.registration_member_id IS '确认的报名成员';
COMMENT ON COLUMN public.asp_declaration_ack.tenant_id IS '业务管理租户，必填；不代表拥有全平台个人档案';
COMMENT ON COLUMN public.asp_declaration_ack.update_by IS '最近更新操作主体';
COMMENT ON COLUMN public.asp_declaration_ack.update_time IS '最近更新记录时间；由服务维护';
COMMENT ON COLUMN public.asp_declaration_ack.version IS '乐观并发版本；不替代业务规则/名单版本';
COMMENT ON COLUMN public.asp_event.closure_status IS '赛后问题与资金收尾状态';
COMMENT ON COLUMN public.asp_growth_record.event_id IS '来源赛事';
COMMENT ON COLUMN public.asp_growth_record.milestone IS 'checkin finish team_finish 或 correction；由业务事实确定';
COMMENT ON COLUMN public.asp_growth_record.points_delta IS '追加的成长分变化；负值为事实纠正补偿';
COMMENT ON COLUMN public.asp_growth_record.source_key IS '事实唯一来源，包含被纠正原记录编号';
COMMENT ON COLUMN public.asp_growth_record.sport_id IS '成长所属运动';
COMMENT ON COLUMN public.asp_honor.sport_id IS '所属运动；历史奖项可空';
COMMENT ON COLUMN public.asp_honor.title_code IS '成长称号规则编码；正式奖项可空';
COMMENT ON COLUMN public.asp_match.court_name IS '本场比赛球场名称，不表示资源预订交易';
COMMENT ON COLUMN public.asp_registration.manager_account_id IS '稳定报名管理人，独立于当前队长与组织审核经办人';

-- PostgreSQL database dump complete
--

# asp_event_command

赛事写操作幂等。同一租户、同一动作、同一请求键只生效一次，重复提交不再次发布

域：D04。模块：aisports-table-event-command。状态：schema。

生成区为对象元数据与模块描述，业务代码放 src/main/java；已有跨表投影仅供完整入口动作私用。默认不开通用写入或Agent查询。

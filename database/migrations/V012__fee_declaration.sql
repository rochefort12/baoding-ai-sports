-- 参赛者模拟付款完成时间。不表示到账。收费记账菜单并入报名审核。

ALTER TABLE asp_fee_obligation ADD COLUMN declared_at timestamptz;
COMMENT ON COLUMN asp_fee_obligation.declared_at IS '参赛者点击模拟付款完成的时间。不是到账确认；有时区业务时间';

UPDATE sys_menu
SET visible = '1',
    status = '1',
    remark = '收费设置已并入报名审核。单独的收费记账菜单不再使用。'
WHERE menu_id = 2106100000000000019;

# 报名动作及本人声明阅读

本文件是手写模块说明，生成器不覆盖。

正式提交会在同一事务内核对每位成员的必填资料，并冻结字段名称、类型、选项和值的快照。`registration.submit` 的写入范围包含 `asp_entry_field_value`，不因此开放本人档案表的写入。

`EntryCard` 与 `InviteView` 用 `declarationImageAvailable` 表示该报名绑定的赛事是否有图片声明，不返回存储地址。参赛者通过 `GET /sports/c/registrations/{registrationId}/declaration-image` 阅读图片。当前报名管理人、已确认名单成员，以及草稿/拒绝状态下的待确认本人邀请成员可以读取；无关账号、已拒绝成员及已提交报名的过期待确认邀请不能读取。图片同时检查声明用途和报名所属组织，响应禁止共享缓存。

参赛详情与邀请页共用 `EntryDeclaration.vue`，支持文字、文字加图片及仅图片。图片加载失败保留重试入口，不允许在图片未显示时点击确认。邀请页通过 `EntryPersonalFields.vue` 提供本人字段填写，队长不能代填；本人确认前保存必填资料，正式提交后保持只读。

验证入口：`RegistrationActionWriteScopeTest`（动作范围契约）、`RegistrationDeclarationImageTest`（模拟依赖下的授权与存储失败）、`scripts/Test-BadmintonParticipantFlow.mjs` 与 `scripts/Test-BadmintonParticipantUI.mjs`（独立本机真实HTTP/UI）。单元测试不替代普通角色、实际对象存储和声明图片的界面验证。正式生效及回执以最新独立验证记录为准。
### 草稿与正式提交的资料门槛

`FieldCatalogService.saveMine` 允许必填项暂空、清空旧答案和逐项保存，非空答案仍核对数值、日期、枚举与长度。必填完整性保持在 `requireFilled` 的正式提交事务里；保存草稿不冻结名单、不占名额、不改变本人共享档案。已提交报名和非本人成员继续禁止修改。`FieldCatalogDraftBoundaryTest` 仅模拟依赖验证九项边界，普通页面保存→真实登录→回到草稿的实际证据独立记录。

### 本人邀请的历史查看入口

`GET /sports/c/registrations/received` 仅为登录人自己的非提交人邀请返回 `inviteToken`，用于卡片上的“查看本人参赛”。详情、确认及拒绝接口仍逐次核验邀请账号；链接不赋予报名管理、代填或付款权限。已拒绝、已撤回的历史可查看实际状态，但沿用原有响应、资料及声明权限，不恢复被撤销的邀请。其他邀请详情与办理响应不重新导出令牌。`RegistrationReceivedLinkTest` 模拟依赖验证匿名、跨人、房主排除、缺失链接及历史状态，真实普通角色复验单独保存。

### 可选付款图片的同事务保存

`PaymentProofService` 的公开 `StoredObjectApi` 调用在报名动作内保存私有付款图片及其 `asp_file` 元数据，动作范围声明同时包含该文件表的读写。图片绑定本人有权限的当次付款义务，上传不表示实际到账或资格通过。动作范围失败时没有产生付款凭证的记录保留为失败证据；存储、跨人及跨义务边界按独立实际复验记录判断。

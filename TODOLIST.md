# CheckInDuck MVP TODO List

> Last updated: 2026-03-18  
> Source baseline: `Start.md`

## 状态说明
- `✅ 已完成`
- `🟡 进行中`
- `⬜ 未开始`

## 总览进度
- 当前阶段：`核心功能闭环已完成，处于联调 / 收尾 / 文档补齐阶段`
- 功能完成度：`约 92%`
- 已完成：`20/24`
- 进行中：`3/24`
- 未开始：`1/24`
- 本轮核对结论：
  - App 主目标、`DeviceActivityMonitor` 扩展、`CheckInDuckWidget` 扩展均可构建
  - 单元测试当前 `13` 项通过
  - UI Tests 仍为启动级占位，不足以覆盖核心流程
  - Screen Time / Family Controls 真机链路仍应视为 `T20 Debug` 的一部分

## 任务清单（按先后顺序）

| ID | 任务 | 状态 | 进度 | 完成目标（DoD） | 先后关系/依赖 |
|---|---|---|---:|---|---|
| T01 | 项目初始化与目录骨架 | ✅ 已完成 | 100% | App 可启动；根 Tab 可用；目录稳定 | 无 |
| T02 | `AI_RULES.md` 项目规则文件 | ✅ 已完成 | 100% | 协作与编码规则统一 | T01 之后 |
| T03 | 核心数据模型 | ✅ 已完成 | 100% | 模型字段稳定，可持久化 | T01 之后 |
| T04 | 本地存储层 | ✅ 已完成 | 100% | Task/Record 可增删改查 | T03 之后 |
| T05 | Today 首页 | ✅ 已完成 | 100% | Today 可读可操作 | T01、T03、T04 |
| T06 | 创建任务页 | ✅ 已完成 | 100% | 独立创建流程与校验 | T05 之后 |
| T07 | Today ViewModel | ✅ 已完成 | 100% | 事件处理闭环 | T03、T04、T05 |
| T08 | Family Controls 授权流程 | ✅ 已完成 | 100% | 授权请求 + 状态持久化 | T01 之后 |
| T09 | App 选择器 | ✅ 已完成 | 100% | 选择结果写入任务配置 | T08 之后 |
| T10 | DeviceActivity 自动完成逻辑 | ✅ 已完成 | 100% | 达阈值自动完成 | T08、T09、T11 |
| T11 | 每日状态计算 | ✅ 已完成 | 100% | pending/completed/missed 规则统一 | T03、T07 |
| T12 | 本地通知提醒 | ✅ 已完成 | 100% | 提醒创建/更新/取消可用 | T08、T11 |
| T13 | 设置页核心配置 | ✅ 已完成 | 100% | 权限状态 + 提醒配置 | T08、T12 |
| T14 | 历史记录页 | ✅ 已完成 | 100% | 按日/按任务查看 | T04、T11 |
| T15 | 手动补完成 | ✅ 已完成 | 100% | 完成来源可追踪 | T11、T14 |
| T16 | 订阅架构设计 | ✅ 已完成 | 100% | 免费/付费边界明确 | T01 之后 |
| T17 | StoreKit 订阅接入 | ✅ 已完成 | 100% | 商品/购买/恢复/同步完整 | T16 之后 |
| T18 | 测试体系 | ✅ 已完成 | 100% | 关键路径单测可回归 | T03、T04、T07、T11 |
| T19 | 代码 Review 轮次 | ✅ 已完成 | 100% | 问题清单与修复闭环 | T05-T18 之后 |
| T20 | Debug 轮次 | 🟡 进行中 | 99% | 关键 bug 可复现可追溯 | T19 之后 |
| T21 | 重构与清理 | ⬜ 未开始 | 0% | 提升可维护性 | T20 之后 |
| T22 | README 与开发文档 | 🟡 进行中 | 45% | 新成员可独立构建开发 | T21 之后 |
| T23 | 分阶段执行与里程碑验收 | 🟡 进行中 | 80% | 阶段验收记录完整 | 全程 |
| T24 | 首页状态小组件 | ✅ 已完成 | 100% | 小组件可展示今日任务状态 | T04、T11、T20 之后 |

## T17 执行记录（最近补充）

- 订阅商品 ID：`com.wang.CheckInDuck.monthly`、`com.wang.CheckInDuck.yearly`
- 新增独立升级页 `UpgradeView`，接入 Today/History/Settings 升级入口
- 升级页新增 `Upgrade Now` 主按钮（默认优先年付），无商品时有 `Reload Plans`
- 新增本地 StoreKit 测试配置（`pro monthly`, `$1.99`）并挂到 `CheckInDuck` Scheme

## T20 执行记录（最近补充）

- Family Controls 授权异常可见化（不再静默失败）
- App/Extension 的 Family Controls + App Group entitlement 已补齐
- Simulator 下 helper app / Family Controls 限制有明确错误提示
- 修复 DeviceActivityMonitor 扩展基类类型，恢复主工程可编译
- `xcodebuild build -scheme CheckInDuck` 已通过（含 extension embed）
- Today 页新增前后台切换同步：App 回到前台会立即消费 usage 事件并更新打卡状态
- 创建任务新增“Auto Check-in threshold”字段，可配置超过多少分钟自动打卡
- 监控启动失败补充日志输出，便于定位未授权/选择数据异常
- 新增 Diagnostics 面板：可直接查看 App Group 容器、当前监控 activity 数、最后阈值回调时间
- Extension 写入阈值事件时新增持久化标记（last threshold task/time），用于排查“未回调 or 未消费”
- 修复同一任务重复 `startMonitoring` 的问题，避免阈值统计被反复重置
- iOS 17.4+ 监控事件启用 `includesPastActivity = true`，覆盖“当天已产生使用时长”的场景
- 扩展阈值回调与主 App 事件消费新增日志，定位链路断点更直接
- 新增回归测试：`refreshDoesNotRestartMonitoringForUnchangedTask`、`thresholdEventIncludesPastActivityOnSupportedIOS`
- 修复“新建任务输入自动清空”问题：创建页草稿改为 `TodayView` 级 `@StateObject` 持有，避免根视图定时刷新导致 `CreateTaskViewModel` 重建
- 新增回归测试：`createTaskViewModelResetDraftClearsUserInput`
- `AppUsageMonitoringService` 增加“已在监控时重建配置（先停后启）”逻辑，避免旧配置滞留
- 新增 `bootstrap activity name` 命名与解析，兼容 `task-<uuid>-bootstrap-<yyyyMMdd>`，提升低系统版本首日监控稳定性
- `stopMonitoring` 改为停止同 task 的所有 activity（含 bootstrap）
- `DeviceActivityMonitor` 扩展同步支持 bootstrap 命名解析，避免阈值回调因 activity 名称格式变化被丢弃
- 新增回归测试：`parseTaskIDSupportsBootstrapActivityName`
- 监控启动增加 `selectedTokens` 计数日志，空 selection 会被拒绝启动并输出原因
- 当监控 activity 已存在时改为“重建配置”（先停后启），避免旧配置长期滞留导致阈值不回调
- 扩展新增 `intervalDidStart` 持久化诊断（last interval task/time），用于区分“扩展未启动”与“未到阈值”
- Settings Diagnostics 新增 `Last interval start` / `Last interval task` 展示
- 对齐参考项目 `ScreenLimit`：修复 DeviceActivity Monitor 扩展 `Info.plist` 扩展点标识为 `com.apple.deviceactivity.monitor-extension`
- 修复监控阈值构造：`DeviceActivityEvent` 从秒粒度改为分钟粒度（向上取整），避免秒级配置不触发阈值回调
- 新增回归测试：`thresholdEventUsesMinuteGranularity`
- 修复历史 `Unknown Task`：启动时自动清理 orphan daily records（`record.taskId` 无对应 task）
- 修复 stale completion event：对不存在任务的自动完成事件直接忽略，并尝试停止对应监控 activity
- 新增回归测试：`initPrunesOrphanDailyRecords`、`evaluateDailyStatusesIgnoresCompletionEventsForUnknownTasks`
- Create Task 页细节优化（不改核心逻辑）：`Auto Check-in` 改为 `Slider`（1-60 分钟）
- Create Task 页细节优化：`Deadline` 改为系统 `DatePicker(.hourAndMinute)`
- Create Task 页细节优化：已选应用改为图标+标题列表展示（参考 ScreenLimit 的 `Label(token)` 方式）
- 修复应用选择器交互：改为独立选择页 + 固定 `Save` 按钮，搜索状态下也可直接确认
- 应用选择器改为“仅单选 App”（不支持多选/分类/网站），并将按钮改为原生 `xmark/checkmark`
- 修复“到点未完成不提醒”：提醒调度默认补充 `offset=0`（deadline 当刻提醒）
- 新增回归测试：`reminderScheduleIncludesDeadlineTrigger`
- 提醒优先级优化：deadline 当刻通知升级为 `Time Sensitive`（`interruptionLevel = .timeSensitive`，`relevanceScore = 1.0`）
- 预提醒保持普通优先级（`interruptionLevel = .active`），并在通知授权时追加 `timeSensitive` 选项申请
- 新增回归测试：`deadlineReminderUsesTimeSensitiveInterruptionLevel`、`preDeadlineReminderUsesActiveInterruptionLevel`
- 主 App entitlement 增加 `com.apple.developer.usernotifications.time-sensitive`，补齐系统“Time Sensitive Notifications”设置入口前提
- 根 Tab 将“历史”替换为“日历”，并在日历页右上角新增“历史”入口跳转至原历史页
- 新增日历状态视图：按日展示任务状态颜色（`completed=绿`、`pending=橙`、`missed=红`），并补充对应单测

## T22 执行记录（最近补充）

- README 已从极简占位更新为可读的项目快照，补充了：
  - 产品目标
  - 已落地能力
  - 已验证构建 / 测试状态
  - 当前剩余工程项
- 重新核对 `TODOLIST.md` 与代码现状，确认：
  - Today / History / Settings / Upgrade / Diagnostics 均已在代码中落地
  - `DeviceActivityMonitor` 与 `CheckInDuckWidget` 扩展已接入并可随主 App 一起构建
  - `CheckInDuckTests` 当前有 `13` 项回归测试通过
  - `CheckInDuckUITests` 仍只有启动与启动性能占位测试
- 文档状态从“未开始”调整为“进行中”，但仍未达到完整开发交接标准
- README 已补充小组件能力、共享 App Group 存储链路、5-target 构建状态
- 验证命令更新为 `xcodebuild test -scheme CheckInDuck -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:CheckInDuckTests`
- 单元测试通过数更新为 `13`

## T24 执行记录（最近补充）

- 新增 `CheckInDuckWidget` WidgetKit 扩展目标，并嵌入主 App
- 小组件当前支持 `systemSmall` / `systemMedium`
- 设计方向参考 iOS Reminders：浅色、简洁、任务优先级清晰
- Small 视图展示今日摘要 + 最高优先级任务
- Medium 视图展示今日任务列表与 `pending / completed / missed` 状态
- 主 App 存储切换到共享 App Group 读写，并保留从旧 `UserDefaults.standard` 的迁移逻辑
- Task / Record 保存后会主动刷新 widget timeline
- 新增回归测试：`sharedDefaultsStoreReadsLegacyDataAndMigratesToPrimary`、`widgetTaskStatusSnapshotBuilderBuildsTodaySummaryAndPrioritizesVisibleTasks`
- 本地验证通过：
  - `xcodebuild build -scheme CheckInDuck -destination 'platform=iOS Simulator,name=iPhone 17'`
  - `xcodebuild test -scheme CheckInDuck -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:CheckInDuckTests`

## 当前项目判断（2026-03-18）

- 可以认为：`MVP 核心产品功能已完成，且已具备首页状态小组件`
- 不能认为：`工程收尾已经完成`
- 当前最真实的阶段是：
  - 功能闭环：已经具备
  - 调试与稳定性：仍在收尾
  - 重构清理：尚未开始
  - 开发文档：刚从占位进入补齐阶段

## 建议的下一步顺序

1. 继续完成 `T20`，把真机 / 权限 / 扩展链路的最后问题收口
2. 进入 `T21`，处理共享存储、扩展边界和命名等遗留清理
3. 补完 `T22`，把开发、调试、验证、Widget 接入文档补齐
4. 最后做统一 UI 优化和体验打磨

## 当前已落地（核对清单）

- 根 Tab：`Today / History / Settings`
- FamilyActivityPicker 已接入创建任务页
- Reminder 调度与任务状态联动
- 免费/付费边界：任务数、历史窗口、提醒自定义
- StoreKit：商品加载、购买、恢复、交易更新监听
- 升级页：权益说明 + 升级按钮 + 恢复购买
- 首页状态小组件：今日状态摘要 + 任务列表

## 恢复记录（本轮）

- 场景：误删项目后进行本地文件恢复
- 动作：从 `CheckInDuck 12-16-31-290/` 回填源码到 `CheckInDuck/`
- 动作：重新补回 `Start.md`、`AI_RULES.md`、`TODOLIST.md`、`README.md`
- 动作：重新补回 `CheckInDuck.storekit` 与共享 Scheme 绑定
- 动作：恢复目标 `CheckInDuckTests`、`CheckInDuckUITests`、`CheckInDuckDeviceActivityMonitor`
- 动作：新增目标 `CheckInDuckWidget`
- 验证：`xcodebuild -list -project CheckInDuck.xcodeproj` 可见 5 个 target
- 验证：`xcodebuild build -scheme CheckInDuck -destination 'platform=iOS Simulator,name=iPhone 17'` 通过
- 验证：`xcodebuild test -scheme CheckInDuck -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:CheckInDuckTests` 通过

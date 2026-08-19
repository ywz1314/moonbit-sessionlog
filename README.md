# moonbit-sessionlog

一个面向康复训练记录的 MoonBit 数据模型与分析库。它把训练动作、组数、疼痛、RPE、完成度和备注组织成可校验、可迁移、可分析的会话数据，并提供可直接嵌入命令行工具、服务端或前端适配层的纯函数 API。

## 项目定位

`moonbit-sessionlog` 解决的是“训练记录可长期使用”这一问题：输入数据要能发现错误，旧格式要能迁移，连续会话要能比较，输出要能脱敏，规则变化后仍要有稳定的测试与基准。项目不绑定数据库和 UI，核心包保持确定性，方便在 Wasm-GC、原生或其他 MoonBit 目标中复用。

## 核心能力

- `lib/core`：`Set`、`Movement`、`Session` 及次数、组数、负荷、完成度和疼痛变化等派生指标。
- `lib/validation`：字段范围、日期、备注、组数和重复次数的基础校验，以及可配置的严格校验摘要。
- `lib/schema`：V1/V2 JSON 兼容、迁移告警、批量解析、规范化 JSON 和往返检查。
- `lib/analytics`、`lib/series`、`lib/aggregation`：趋势、移动平均、连续会话序列和动作聚合。
- `lib/progression`、`lib/planning`、`lib/forecast`：动作进阶策略、训练计划执行、负荷与完成度预测。
- `lib/alerts`、`lib/safety`、`lib/insights`、`lib/quality`：风险告警、安全分层、数据质量和可解释洞察。
- `lib/storage`、`lib/query`、`lib/history`：有容量边界的内存存储、组合查询和审计记录。
- `lib/reporting`、`lib/interchange`、`lib/dashboard`：文本/CSV/JSON、TSV/JSON Lines、汇总看板。
- `lib/catalog`、`lib/calendar`、`lib/consistency`：动作目录、日期运算和重复动作的一致性分析。
- `lib/retention`、`lib/normalization`：归档策略、隐私脱敏、去重、导入前清洗与规范化。

## 快速开始

需要 MoonBit stable 工具链。项目当前使用的本地工具链为 `moonc v0.10.7`，可先执行：

```bash
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
moon run cmd/main
```

运行基准与确定性校验：

```bash
moon run cmd/bench
```

## CLI

`cmd/main` 展示 V1 迁移、V2 解析、严格校验、进阶建议、规范化和 dashboard 汇总；`cmd/bench` 生成固定规模的会话夹具，输出统计量与 checksum，便于在不同机器和 CI 中复测。

在其他 MoonBit 包中引入模块：

```moonbit
import {
  "ywzywz/sessionlog/lib/core",
  "ywzywz/sessionlog/lib/analytics",
  "ywzywz/sessionlog/lib/validation",
}
```

```moonbit
let session = @core.Session::{
  id: "demo-1",
  date: "2026-08-19",
  duration: 30,
  pain_before: 4,
  pain_after: 2,
  movements: [],
  notes: "",
}
let errors = @validation.validate_session(session)
let trend = @analytics.analyze([session])
```

## 架构

```text
core types
   ├── validation ── schema migration ── interchange/reporting
   ├── metrics ──── aggregation ─────── analytics/series
   ├── catalog ──── planning ────────── progression/forecast
   ├── quality ──── safety/alerts ───── insights/dashboard
   ├── query ────── storage/history
   └── calendar ─── normalization ───── retention
```

包之间通过 `moon.pkg` 显式声明依赖；数据结构使用 `ToJson`/`FromJson`，计算和报告 API 不依赖全局状态。归档与规范化默认保留可追踪的报告信息，隐私策略需要由调用方显式选择。

## 基准

基准夹具是确定性的，不把运行时间写死在程序输出中：程序输出 checksum，外层命令负责测量实际耗时。一次 `cmd/bench` 同时覆盖 10/100/1000 会话规模，以及 1000 会话、6 动作、每动作 4 组的规范化流水线。

本地实测（2026-08-19，Windows NT 10.0.26200.0，AMD Ryzen 7 5800H，`moonc v0.10.7`，PowerShell `Measure-Command`，7 次冷启动样本）：

| 场景 | 输入规模 | 稳定输出 |
| --- | ---: | --- |
| smoke | 10 sessions × 2 movements × 2 sets | checksum `718862029` |
| weekly | 100 sessions × 4 movements × 3 sets | checksum `1950637087` |
| history | 1,000 sessions × 6 movements × 4 sets | checksum `-1039633519` |
| pipeline | 1,000 sessions × 6 movements × 4 sets，规范化 + retention | checksum `602712179` |

`cmd/bench` 端到端冷启动耗时：平均 `352.04 ms`，中位数 `342.51 ms`，样本为 `406.26, 326.25, 331.07, 382.38, 342.51, 323.20, 352.58 ms`。这些数字用于复现当前环境，不代表所有机器的性能承诺；复测命令为 `moon run cmd/bench`。

## 测试与质量门禁

测试覆盖核心模型、边界值、日期闰年、空集合、非法 JSON、迁移告警、容量限制、隐私脱敏、归档去重、动作合并、风险分层、报告格式和确定性 checksum。当前本地 Wasm-GC 目标为 **50 个测试全部通过**。

常用命令：

```bash
moon fmt
moon info
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
```

## CI

GitHub Actions 在 Ubuntu、macOS、Windows 上执行格式检查、`moon info` 接口检查、`moon check --target all --deny-warn` 和 `moon test --target all --deny-warn`；Linux 额外生成覆盖率并检查生产 MoonBit 源码规模。工具链安装脚本跟随 MoonBit stable，接口生成后的工作树必须保持干净。

## 许可证

本项目使用 [Apache License 2.0](LICENSE)。

# moonbit-sessionlog

MoonBit康复训练日志模型 (Rehabilitation Session Log Model).
标准化记录康复训练、疼痛反馈、动作完成度和进阶状态。

本项目旨在为患者及治疗师提供一个轻量、严谨且易于集成的康复训练记录与状态评估引擎。项目支持日志校验、多版本 Schema 自动迁移以及智能运动进阶分析，方便后续对接数据库或 Web 前端。

## 目录结构

```
moonbit-sessionlog/
├── moon.mod               # 模块配置 (name = "ywzywz/sessionlog")
├── LICENSE                # Apache-2.0 许可证
├── README.md              # 项目文档说明
├── .github/
│   └── workflows/
│       └── ci.yml         # GitHub Actions 自动化校验工作流
├── lib/
│   ├── core/              # 核心域数据结构 (Set, Movement, Session)
│   ├── validation/        # 日志字段及业务规则校验 (VAS, RPE, 正数校验)
│   ├── schema/            # 多版本 JSON 日志解析与 V1 -> V2 自动迁移
│   └── progression/       # 康复动作与负荷的进阶、维持、退阶分析推荐
└── cmd/
    └── main/              # 示例应用程序入口
```

## 核心功能

### 1. 核心数据结构 (`lib/core`)
标准化定义康复日志模型：
- **`Set`**：记录单组训练次数（`reps`）、维持时间（`hold_time`）、阻力或负荷（`resistance`）及动作完成率（`completion`）。
- **`Movement`**：记录动作名称、多组动作的数组、视觉模拟评分（VAS 疼痛度：`0` 至 `10`）及主观疲劳等级（RPE 疲劳度：`1` 至 `10`）。
- **`Session`**：记录训练会话 ID、日期、训练总时长、训练前疼痛、训练后疼痛、包含的动作数组及备注。同时提供 `total_reps()` 和 `average_pain_during()` 等指标计算。

### 2. 日志校验 (`lib/validation`)
提供数据安全性检查：
- 疼痛 VAS 分数必须在 `0` 至 `10` 之间。
- RPE 必须在 `1` 至 `10` 之间。
- 训练组的次数、维持时间、会话总时长必须为非负数。
- 动作完成率必须在 `0.0` 至 `1.0` 之间。
- 日期格式基本校验（`YYYY-MM-DD` 长度和分隔符检查）。
- 校验失败将累积并返回 `Array[ValidationError]` 详细错误列表。

### 3. 版本化 Schema (`lib/schema`)
提供向后兼容性：
- **V1 (Legacy)**：早期版本，`movements` 仅存储动作为简单的字符串数组，且不记录 RPE 等详细指标。
- **V2 (Modern)**：当前版本，全面记录运动的组数细节、痛觉及疲劳度。
- 支持检测输入 JSON 日志的 `"version"`，如无该字段或为 `1`，则自动反序列化为 V1 格式，并依据迁移规则（分配默认组数及中性 RPE）平滑迁移至 V2 模型。

### 4. 进阶推荐引擎 (`lib/progression`)
依据痛觉、疲劳度及动作完成率智能输出建议：
- **`Progression` (进阶)**：当动作平均完成率 $\ge 75\%$，且训练疼痛 $\le 3$、疲劳度 $\le 5$ 时，建议增加次数或组数。
- **`Maintenance` (维持)**：当痛觉达轻中度（VAS `4` 至 `6`）或疲劳度达中度（RPE `7` 至 `8`）时，建议保持当前负荷以促进组织适应。
- **`Regression` (退阶)**：当动作完成率 $< 75\%$，或疼痛强烈（VAS $\ge 7$）、负荷过大（RPE $\ge 9$）时，自动触发退阶建议，缩减组数与次数以防止运动损伤。

## 安装与开发

### 1. 准备环境
请确保本地已安装最新版的 MoonBit 工具链 (0.10.3)。可以通过以下命令更新：
```bash
# Unix
curl -fsSL https://cli.moonbitlang.com/install.sh | bash

# Windows (PowerShell)
irm https://cli.moonbitlang.com/install.ps1 | iex
```

### 2. 构建与运行示例
执行以下命令运行演示应用，观察日志解析、V1 自动迁移、校验错误汇报和进阶引擎分析流程：
```bash
moon run cmd/main
```

### 3. 运行测试套件
项目各组件包含了完善的单元测试。运行以下命令执行所有测试：
```bash
moon test
```

### 4. 格式化与静态检查
在提交流程或 CI 构建中，可以使用以下命令保证代码格式与编译警告清零：
```bash
# 格式化代码
moon fmt

# 验证是否有编译警告或错误
moon check --deny-warn
```

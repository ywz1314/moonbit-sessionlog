# MoonBit 康复训练日志模型申报书

## 1. 基本信息
- **项目名称**：moonbit-sessionlog (康复训练日志与进阶评估模型)
- **GitHub 链接**：https://github.com/ywz1314/moonbit-sessionlog
- **GitLink 链接**：https://gitlink.org.cn/ywzywz/moonbit-sessionlog
- **项目方向**：工程基础设施与应用生态 / 数字化健康管理
- **项目性质**：原创项目

## 2. 项目简介与立项背景
在运动康复与物理治疗中，标准、连续的反馈日志是保障安全和促进组织适应的关键。本项目旨在通过 MoonBit 原生开发一套标准轻量的康复日志校验与评估引擎，标准化记录动作次数、负荷（阻力）、VAS疼痛度与RPE疲劳等级，帮助患者与理疗师安全调节运动负荷，提供开箱即用的康复记录底层设施。

## 3. 核心功能设计
- **标准数据模型**：提供 `Set`、`Movement` 和 `Session` 数据类型，支持 JSON 自动序列化。
- **全链路严谨校验**：多级错误累加校验器，验证 VAS (0-10) 疼痛、RPE (1-10) 及动作完成率。
- **版本化 Schema 迁移**：兼容并平滑迁移 V1 (Legacy) 字符串形式日志至 V2 (Modern) 结构化日志。
- **智能进阶推荐**：基于平均动作完成率、痛觉及疲劳水平，按临床逻辑智能评估输出 Progression (进阶)、Maintenance (维持) 与 Regression (退阶) 状态及运动负荷微调建议。

## 4. 交付物与自查指标
- **代码交付**：含 `core`、`validation`、`schema` 和 `progression` 包及完整的 `.mbti` 接口。
- **示例与测试**：提供命令行 demo，附带覆盖边界路径的 11 个单元测试，测试及格式化 100% 警告清零。
- **自动化构建**：集成 GitHub Actions CI (支持 `fmt`、`check --deny-warn`、`test --deny-warn`)。

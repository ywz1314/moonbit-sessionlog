# moonbit-sessionlog

MoonBit康复训练日志模型 (Rehabilitation Session Log Model).
标准化记录康复训练、疼痛反馈、动作完成度和进阶状态。

## 功能特性

- **核心数据结构**：标准化记录患者康复训练、疼痛度、RPE以及动作完成度。
- **日志校验**：对输入日志数据的完整性与有效性（例如VAS疼痛度、RPE等级、正数校验等）进行验证。
- **版本化 Schema**：支持旧版本（V1）日志解析并自动迁移至新版本（V2）。
- **进阶分析算法**：基于训练日志分析痛觉与疲劳度，智能推荐进阶（Progression）、维持（Maintenance）或退阶（Regression）状态。

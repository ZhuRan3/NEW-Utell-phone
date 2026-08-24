# 技术栈学习理解文档库

本目录存放 NEW-Utell 项目中关键概念、需求决策点的学习讲解文档（HTML + PNG 图表），帮助理解 PRD 决策背后的技术原理与业界依据。

## 目录结构

```
技术栈学习理解文档库/
├── README.md                    ← 本索引
├── gen_figures.py               ← 图表生成脚本（matplotlib，修改后重跑即可更新 PNG）
├── assets/                      ← PNG 图表
│   ├── fig1-architecture.png    链路结构图：Relay 的视野
│   ├── fig2-lifecycle.png       审计元数据生命周期流程图
│   ├── fig3-tradeoff.png        四选项「隐私 × 排障」权衡对比图
│   └── fig4-benchmark.png       保留期限业界参照标尺
└── C2-Relay脱敏审计元数据保留决策.html   ← 打开此文件学习
```

## 文档清单

| 文档 | 对应决策/章节 | 内容 |
|---|---|---|
| C2-Relay脱敏审计元数据保留决策.html | 需求问答 C2；PRD FR-008 / 7.2 / 9.2 | Relay 脱敏审计元数据是什么、保留期限的学问、30/7/90 天/不保留四选项对比；当前决策为 14 天 |
| Noise首发Pattern选择/Noise首发Pattern选择.html | D4；Phone Noise Spike；PRD 配对与 E2EE | Noise 在四层链路中的位置、XX 与 IK 的握手机制、扫码/token/指纹绑定、首发建议与冻结前门禁 |

## 子目录

- `Noise首发Pattern选择/`：D4 学习讲义、来源与证据台账、冻结前决策清单、离线 HTML、思维导图/流程图/对比图 SVG。

## 使用方式

直接用浏览器打开 HTML 文件即可（图片为相对路径引用，请保持目录结构完整）。

## 更新图表

```bash
cd 文档/技术栈学习理解文档库
python3 gen_figures.py   # 需 matplotlib，中文字体 Hiragino Sans GB
```

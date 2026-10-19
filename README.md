# 植物大战僵尸 · Godot 复刻（第一阶段：白天 1-1 ~ 1-10）

用 Godot 4.7.2 + GDScript 复刻 PVZ 原版白天冒险模式的前 10 关。逻辑与表现分离：
实体是普通 `Node2D`，由 `Level` 以固定 60Hz 显式 tick，不依赖物理引擎，方便测试与复现。

## 快速开始

1. 用 Godot 4.7.2（或兼容 4.x）打开本目录的 `project.godot`。
2. 按 `F5`，进入主菜单。
3. 选择已解锁关卡（初始仅 1-1；通关后解锁下一关）。

## 本地依赖（不入库）

本仓库只含可独立运行的代码与已导出的 `assets/pvz/` 精灵表。以下路径被 `.gitignore` 排除，clone 后不存在：

| 路径 | 原因 |
|---|---|
| `pak/` | 原版 PVZ 解包素材（reanim / 图片 / 音频），版权原因不入库；参照 `docs/asset-contract.md` 自备后可用脚本重新生成精灵表 |
| `addons/` | 第三方编辑器插件（godot_ai MCP 桥接），仅本机开发与自动化测试需要 |
| `.godot/` | Godot 导入缓存，首次打开项目时自动重建 |

`project.godot` 的 `[editor_plugins]` 仍启用了 `res://addons/godot_ai/plugin.cfg`：没装该插件时 Godot 启动会提示插件缺失，忽略或到编辑器里禁用即可，不影响游戏运行。

## 操作

| 输入 | 行为 |
|---|---|
| 鼠标左键点卡片 | 选卡（阳光不足/冷却中不可选） |
| 鼠标左键点草坪格 | 种植；已占用或阳光不足时提示 |
| 鼠标左键点阳光 | 收集阳光 |
| `Esc` | 暂停 / 继续；胜利或失败时返回选关 |
| `R` | 重开本关 |
| `Enter` | 胜利/失败页返回选关 |
| `1` / `2` / `3` | 调试倍速 1× / 2× / 3× |

## 已实现

- 10 个关卡数据（`resources/levels/1_1.tres` ~ `1_10.tres`），波次、旗帜波、大波横幅、波次计数。
- 9 种植物：豌豆射手、向日葵、坚果墙、土豆雷、寒冰射手、樱桃炸弹、大嘴花、双发射手、小喷菇。
- 7 种僵尸：普通、路障、撑杆、铁桶、旗帜、橄榄球、鸭子（泳池占位单位）。
- 阳光经济、卡片冷却、种植/叠放校验、僵尸啃食、护甲、减速、撑杆跳、土豆雷布防、樱桃 3×3、大嘴花咀嚼、双发。
- 每行小推车（一次性救场）、房子血量与失败判定。
- Ready / Set / Plant 开场，胜利/失败结算，暂停，重开，返回选关。
- 关卡解锁与存档（`user://progress.json`），主菜单继续、音效/音乐开关。
- 原版素材：`pak/` 的 reanim 动画预渲染为 `assets/pvz/` 精灵表，覆盖植物、僵尸、阳光、小推车、种子卡片、背景；音效取自 `pak/sounds`，缺失时静默降级。

## 目录

```
scripts/
  core/        LawnGrid 网格、GameClock 时钟、SignalHub 信号
  data/        PlantData / ZombieData / LevelData / GameCatalog
  entities/    Plant / Zombie / Projectile / Sun
  systems/     WaveDirector、LawnMower、GameProgress、AudioManager
  levels/      Level 总控（状态机、tick 顺序、UI 装配）
  ui/          CardBar 卡片栏
  main.gd      主菜单 / 关卡选择
scenes/        main / level / plant / zombie / projectile / sun / mower
resources/     plants/*.tres、zombies/*.tres、levels/1_1..1_10.tres
tests/         test_*.gd（McpTestSuite）
docs/          values.md 数值口径、asset-contract.md 素材契约、acceptance.md 验收、plan-phase1.md 计划
```

## 测试

在 Godot 编辑器中通过 godot_ai 的测试面板运行 `test_run`（11 个 suite / 49 项，全绿）。
该面板来自 `addons/godot_ai/`（不入库，需本地安装）；测试本身不依赖它。
测试直接实例化关卡并手动 `_ready()` + `simulate()`，不依赖编辑器当前场景。

## 素材接入

当前素材由 `pak/` 离线预渲染而来（`pak/` 因版权不入库），见 `docs/asset-contract.md`：

```bash
python tools/generate_pvz_assets.py   # 重新生成 assets/pvz/*
```

输出为横向精灵表 + JSON（帧数/fps/脚底锚点）。重新生成后需让 Godot 重新导入，
再重启游戏。音频放到 `assets/audio/sfx|music/<id>.ogg` 即可被 `AudioManager` 识别；
缺失时保持占位/静默降级。

## 已知边界

- 原版动画中的攻击/受击/爆炸特效尚未全部接入；目前有 idle、啃食、撑杆跳、土豆雷起身、死亡淡出。
- 仅白天草坪 1-1~1-10；无泳池、雾夜、屋顶、迷你游戏、图鉴、商店。
- 数值按原版量级校准，尚未逐帧对齐原版。
- 无铲子、无卡片拖拽（点击选卡）；背景音乐尚未提供。

# 美术资源交付契约

> 第一阶段（M0–M6）使用代码占位图形，随后已接入 `pak/` 原版素材。
> 当前运行时优先读取 `assets/pvz/` 下由 `tools/generate_pvz_assets.py` 预渲染的精灵表，
> 缺失时自动回退到占位绘制。

## 1. 素材来源与生成

- 原始素材：`pak/reanim/*.reanim`（动画骨架）+ 同名部件 PNG；`pak/images/*` 静态图。
- 预渲染：`python tools/generate_pvz_assets.py`，解析 reanim XML 的轨道与关键帧，
  按 12fps（部分 6/20/30fps）合成横向精灵表。
- 画布：默认 360×360，原点 `(190,190)`；撑杆僵尸跳跃使用 640×360、原点 `(320,190)`。
- 脚底锚点：JSON 的 `ground` 记录脚底像素；运行时 `offset=(-origin_x, -ground)`，
  再把视觉下移（植物 34px、僵尸 36px、小推车 22px）以贴合草坪格子底部。

## 2. 输出目录

```
assets/pvz/
  plants/<id>_<anim>.png + .json      # idle / armed / bite / chew / explode
  zombies/<id>_<anim>.png + .json     # walk / eat / jump
  sun/sun.png + .json
  mower/mower.png + .json
  icons/<plant_id>.png                # 54×54 卡片图标
  projectiles/pea.png, snow_pea.png
  ui/background1.jpg, logo.png, seed_packet.png, sun_bank.png, seed_bank.png
```

- `id` 与 `.tres` 的 `id` 完全一致：植物 `peashooter/sunflower/wallnut/potatomine/snowpea/cherrybomb/chomper/repeater/puffshroom`；
  僵尸 `normal/cone/pole/bucket/flag/football/ducky`。
- 动画名固定：植物 `idle`（土豆雷另有 `armed`，大嘴花 `bite/chew`，樱桃 `explode`）；
  僵尸 `walk/eat`，撑杆另有 `jump`。
- JSON 字段：`frame_w`、`frame_h`、`frames`、`fps`、`ground`、`origin_x`。
  代码按 `frame = int(time*fps) % frames` 推进，不依赖 AnimationPlayer。

## 3. 视觉尺寸与锚点

| 类别 | 原生有效高度 | 运行时缩放 | 锚点 |
|---|---|---|---|
| 植物 | ~70–130 px | 0.95–1.3（按 id） | 脚底 |
| 僵尸 | ~150 px | 0.7 | 双脚 |
| 子弹 | 20–30 px | 0.55 | 中心 |
| 阳光 | ~107 px | 0.4 | 中心 |
| 小推车 | ~68 px | 0.7 | 底部中点 |
| 种子卡片 | 100×140 | 60×72 | 左上角 |

- 背景 `background1.jpg` 原图 1400×600，裁 `RegionRect(200,0,800,600)`，
  使草坪左边缘落在 `x=40`。
- 纹理过滤保持默认线性；原图本身为手绘风，不做像素化处理。

## 4. 音频命名

```
assets/audio/sfx/plant.ogg            # 种植
assets/audio/sfx/sun.ogg              # 收集阳光（原版 coin）
assets/audio/sfx/zombie_die.ogg       # 僵尸死亡（gulp）
assets/audio/sfx/huge_wave.ogg        # 大波警报
assets/audio/sfx/win.ogg              # 胜利
assets/audio/sfx/lose.ogg             # 失败
assets/audio/sfx/mower.ogg            # 小推车
assets/audio/sfx/click.ogg            # 选卡/按钮
assets/audio/sfx/chomp.ogg            # 大嘴花啃咬
assets/audio/sfx/cherrybomb.ogg       # 爆炸
assets/audio/sfx/ready_set_plant.ogg  # 开场语音
assets/audio/music/menu.ogg           # 主菜单（pak 未提供，当前静默）
assets/audio/music/day.ogg            # 白天关卡（pak 未提供，当前静默）
```

- 文件名即 `AudioManager.play_sfx(id)` / `play_music(id)` 的 id，支持 `.ogg` / `.wav` / `.mp3`。
- 缺少音频时 `AudioManager` 静默降级（不报错、不阻断流程），只在控制台提示一次。
- 音频总线：`Master` → `Music` / `SFX`；音量与静音存 `user://progress.json`（GameProgress）。

## 5. 验收方式

- `tests/test_assets.gd` 校验：
  - `assets/pvz/` 存在时，9 个植物图标与 idle 精灵表、7 个僵尸 walk 精灵表、背景图必须存在；
  - JSON 可解析且帧数 > 0；
  - 缺失整目录时允许回退占位，测试通过。
- 替换或重新生成素材后运行 `test_run`，并重启游戏（`project_run`）确认导入生效。
- 旧版 `assets/plants/<id>/`、`assets/zombies/<id>/` 契约仍兼容：若没有 `assets/pvz/`，
  会按尺寸契约校验目录内 PNG。

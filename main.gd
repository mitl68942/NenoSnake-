extends Node2D

# ==== WORLD CONFIG ====
const CELL := 24
const WORLD_W := 80
const WORLD_H := 80
const WORLD_PX := WORLD_W * CELL
const WORLD_PY := WORLD_H * CELL

# ==== STAGES ====
# Each stage: [name, required_colors, need_per_color, speed, bomb_count, ai_count, food_count, time_limit]
const STAGES := [
	["第一关·初识", [0, 1], 3, 0.26, 4, 1, 15, 90.0],
	["第二关·渐入", [0, 1, 2], 4, 0.23, 6, 2, 18, 100.0],
	["第三关·挑战", [0, 1, 2, 3], 4, 0.20, 8, 2, 20, 110.0],
	["第四关·纷繁", [0, 1, 2, 3, 4], 5, 0.18, 10, 3, 22, 120.0],
	["第五关·风暴", [0, 1, 2, 3, 4, 5], 5, 0.16, 12, 3, 25, 130.0],
	["第六关·极限", [0, 1, 2, 3, 4, 5, 6], 6, 0.14, 14, 4, 28, 150.0],
	["第七关·狂暴", [0, 1, 2, 3, 4, 5, 6, 7], 6, 0.12, 16, 4, 30, 160.0],
	["最终关·传说", [0, 1, 2, 3, 4, 5, 6, 7], 8, 0.10, 20, 5, 35, 200.0],
]

# ==== FOOD COLORS ====
const FCOLORS := [
	["金黄", Color(1.0, 0.9, 0.0)], ["青蓝", Color(0.0, 0.94, 1.0)],
	["翠绿", Color(0.22, 1.0, 0.08)], ["烈红", Color(1.0, 0.2, 0.3)],
	["魅紫", Color(0.75, 0.3, 1.0)], ["橙焰", Color(1.0, 0.55, 0.1)],
	["樱粉", Color(1.0, 0.4, 0.7)], ["冰蓝", Color(0.4, 0.7, 1.0)],
]

# ==== SPECIAL ====
enum Spc { REVIVAL, BONUS, SLOW, SHIELD, FREEZE, DOUBLE }
const SPC_INFO := {
	Spc.REVIVAL: {"c": Color(1, .3, .65), "s": "♥", "d": "+1复活"},
	Spc.BONUS:   {"c": Color(.22, 1, .08), "s": "◆", "d": "+5分"},
	Spc.SLOW:    {"c": Color(.75, .52, .99), "s": "◎", "d": "减速"},
	Spc.SHIELD:  {"c": Color(1, .85, .2), "s": "◇", "d": "护盾"},
	Spc.FREEZE:  {"c": Color(.3, .9, 1), "s": "※", "d": "冻结AI"},
	Spc.DOUBLE:  {"c": Color(1, .6, .1), "s": "x2", "d": "双倍分"},
}
const SPC_W := [0.3, 0.4, 0.3]  # weights for random specials: REVIVAL, BONUS, SLOW only

# Persistent map specials: Shield, Freeze, Double (2 each, always on map)
const MAP_SPC_TYPES: Array[int] = [3, 3, 4, 4, 5, 5]  # Spc.SHIELD=3, FREEZE=4, DOUBLE=5

# ==== AI CONFIG ====
const AI_LENGTHS := [12, 18, 25, 15, 20]
const AI_COLORS := [
	Color(0.6, 0.15, 0.15, 0.7),
	Color(0.15, 0.4, 0.6, 0.7),
	Color(0.5, 0.15, 0.5, 0.7),
	Color(0.15, 0.5, 0.3, 0.7),
	Color(0.5, 0.4, 0.1, 0.7),
]

# ==== STATE ====
var snake: Array[Vector2i] = []
var snake_colors: Array[Color] = []
var dir := Vector2i(1, 0)
var next_dir := Vector2i(1, 0)
var foods: Array[Dictionary] = []
var bombs: Array[Vector2i] = []
var walls: Dictionary = {}
var wall_edges: Array[Vector2i] = []
var score := 0
var stage := 0  # current stage index
var high_score := 0
var lives := 0
var is_running := false
var is_paused := false
var slow_timer := 0.0
var food_anim := 0.0
var move_progress := 0.0
var prev_head := Vector2i.ZERO
var color_eaten: Array[int] = []  # count per color index
var shield_hits := 0
var freeze_timer := 0.0
var double_timer := 0.0
var stage_time := 0.0  # remaining time for current stage
var showing_help := false

var spc_pos := Vector2i(-1, -1)
var spc_type: Spc = Spc.REVIVAL
var spc_active := false
var spc_ttl := 0.0

var shrink_foods: Array[Vector2i] = []
var map_spc: Array[Dictionary] = []  # persistent specials: {"pos": Vector2i, "type": int}
const SHRINK_COUNT := 3
const INIT_SNAKE_LEN := 3

var ftexts: Array[Dictionary] = []
var parts: Array[Dictionary] = []
var ai_snakes: Array[Dictionary] = []

# Nodes
@onready var cam: Camera2D = $Camera2D
@onready var mtimer: Timer = $MoveTimer
@onready var atimer: Timer = $AITimer
@onready var music: AudioStreamPlayer = $MusicPlayer
@onready var scr_lbl: Label = $CanvasLayer/HUD/StatsRow/ScoreLabel
@onready var lvl_lbl: Label = $CanvasLayer/HUD/StatsRow/LevelLabel
@onready var hi_lbl: Label = $CanvasLayer/HUD/StatsRow/HighLabel
@onready var lives_lbl: Label = $CanvasLayer/HUD/StatsRow/LivesLabel
@onready var timer_lbl: Label = $CanvasLayer/HUD/StatsRow/TimerLabel
@onready var eff_lbl: Label = $CanvasLayer/HUD/EffectRow/EffectLabel
@onready var ov: PanelContainer = $CanvasLayer/OverlayPanel
@onready var ov_title: Label = $CanvasLayer/OverlayPanel/OverlayVBox/OverlayTitle
@onready var ov_msg: Label = $CanvasLayer/OverlayPanel/OverlayVBox/OverlayMsg
@onready var ov_btn: Button = $CanvasLayer/OverlayPanel/OverlayVBox/StartButton
@onready var help_btn: Button = $CanvasLayer/OverlayPanel/OverlayVBox/HelpButton

# =========================================================
#  LIFECYCLE
# =========================================================
func _ready() -> void:
	high_score = _load_hs()
	hi_lbl.text = "最高分: %d" % high_score
	_show_main_menu()
	_generate_music()

func _show_main_menu() -> void:
	showing_help = false
	ov.visible = true
	ov_title.text = "霓虹蛇 NEON SERPENT"
	ov_msg.text = "方向键/WASD 移动 · 空格暂停 · ESC重开"
	ov_btn.text = "开始游戏"; ov_btn.visible = true
	help_btn.text = "帮助"; help_btn.visible = true

func _on_start_pressed() -> void:
	ov_btn.release_focus()
	if showing_help:
		# Return from help to main menu
		_show_main_menu()
		return
	if ov_btn.text == "下一关":
		_start_stage(true)  # keep length
	elif ov_btn.text == "再来一局":
		stage = 0; score = 0; lives = 0
		_start_stage(false)  # reset length
	else:
		stage = 0; score = 0; lives = 0
		_start_stage(false)  # reset length

func _on_help_pressed() -> void:
	help_btn.release_focus()
	showing_help = true
	ov_title.text = "游戏帮助"
	ov_msg.text = """操作方式:
  方向键 / WASD 控制蛇的移动方向
  空格键 暂停/继续游戏
  ESC键 返回主菜单重新开始

通关条件:
  每关需要吃够指定数量的各色食物
  每关有时间限制，超时则游戏结束
  共8关，难度逐步递增

危险物品:
  红色砖墙 — 碰到即死（护盾可挡）
  炸弹 — 碰到立即死亡，无法复活
  AI蛇 — 菱形身体的蛇，碰到即死

特殊食物（地图固定刷新）:
  ◇ 护盾(金色) — 获得2次碰撞保护
  ※ 冻结AI(冰蓝) — 冻结AI蛇6秒
  x2 双倍分(橙色) — 8秒内双倍得分
  ↓ 缩身(绿色) — 蛇身回归初始长度

随机特殊食物（吃普通食物触发）:
  ♥ 复活 — 获得1条额外生命
  ◆ +5分 — 额外加5分
  ◎ 减速 — 移动速度降低5秒

生存技巧:
  优先收集护盾，可以保命
  注意时间倒计时，合理规划路线
  利用冻结控制AI蛇的威胁
  缩身食物可帮助在狭窄地形中穿行"""
	ov_btn.text = "返回"; ov_btn.visible = true
	help_btn.visible = false

func _start_stage(keep_length: bool = false) -> void:
	var cx := WORLD_W / 2
	var cy := WORLD_H / 2
	var keep_len := INIT_SNAKE_LEN
	if keep_length:
		keep_len = maxi(snake.size(), INIT_SNAKE_LEN)
	snake.clear(); snake_colors.clear()
	for i in keep_len:
		snake.append(Vector2i(cx - i, cy))
		snake_colors.append(FCOLORS[0][1])
	dir = Vector2i(1, 0); next_dir = dir
	slow_timer = 0.0; shield_hits = 0; freeze_timer = 0.0; double_timer = 0.0
	move_progress = 1.0; prev_head = snake[0]
	is_running = true; is_paused = false
	spc_active = false; ftexts.clear(); parts.clear()
	foods.clear(); bombs.clear(); shrink_foods.clear(); map_spc.clear()
	# Reset color eaten counters
	color_eaten.clear()
	for _i in FCOLORS.size():
		color_eaten.append(0)
	_generate_walls()
	var st: Array = STAGES[stage]
	var ai_count: int = st[5]
	_spawn_ai_snakes(ai_count)
	_spawn_bombs(st[4])
	var food_count: int = st[6]
	for _i in food_count:
		_place_food()
	for _i in SHRINK_COUNT:
		_place_shrink_food()
	for mst in MAP_SPC_TYPES:
		_place_map_spc(mst)
	_hud()
	ov.visible = false; eff_lbl.text = ""
	help_btn.visible = false
	stage_time = st[7]  # time limit for this stage
	mtimer.wait_time = st[3]; mtimer.start()
	atimer.wait_time = 0.35; atimer.start()
	cam.position = Vector2(snake[0]) * CELL
	if not music.playing:
		music.play()

# =========================================================
#  INPUT
# =========================================================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up") and dir != Vector2i(0, 1):
		next_dir = Vector2i(0, -1)
	elif event.is_action_pressed("move_down") and dir != Vector2i(0, -1):
		next_dir = Vector2i(0, 1)
	elif event.is_action_pressed("move_left") and dir != Vector2i(1, 0):
		next_dir = Vector2i(-1, 0)
	elif event.is_action_pressed("move_right") and dir != Vector2i(-1, 0):
		next_dir = Vector2i(1, 0)
	elif event.is_action_pressed("pause") and is_running:
		is_paused = !is_paused
		mtimer.paused = is_paused; atimer.paused = is_paused
		queue_redraw()
	elif event.is_action_pressed("restart"):
		mtimer.stop(); atimer.stop(); is_running = false
		_show_main_menu()

# =========================================================
#  PLAYER TICK
# =========================================================
func _on_move_timer_timeout() -> void:
	if not is_running or is_paused:
		return
	# Slow countdown
	if slow_timer > 0.0:
		slow_timer -= mtimer.wait_time
		if slow_timer <= 0.0:
			slow_timer = 0.0
			mtimer.wait_time = STAGES[stage][3]; mtimer.start()
			_update_eff()
	# Double score countdown
	if double_timer > 0.0:
		double_timer -= mtimer.wait_time
		if double_timer <= 0.0:
			double_timer = 0.0; _update_eff()
	# Freeze countdown
	if freeze_timer > 0.0:
		freeze_timer -= mtimer.wait_time
		if freeze_timer <= 0.0:
			freeze_timer = 0.0; _update_eff()
	# Special TTL
	if spc_active:
		spc_ttl -= mtimer.wait_time
		if spc_ttl <= 0.0: spc_active = false

	dir = next_dir
	prev_head = snake[0]
	var head := snake[0] + dir
	move_progress = 0.0

	# Boundary / wall collision
	if head.x < 0 or head.x >= WORLD_W or head.y < 0 or head.y >= WORLD_H or walls.has(head):
		if shield_hits > 0:
			shield_hits -= 1; _update_eff()
			dir = Vector2i(-dir.x, -dir.y); next_dir = dir
			_parts(snake[0], Color(1, .85, .2), 15)
			_ftext(snake[0], "护盾!", Color(1, .85, .2))
			_hud(); queue_redraw(); return
		_handle_death(); return

	# Bomb collision — instant death, ignores revival
	for b in bombs:
		if head == b:
			_parts(head, Color(1, 0.4, 0.1), 30)
			_ftext(head, "炸弹!", Color(1, 0.3, 0.0))
			_play_bomb()
			lives = 0; shield_hits = 0
			_handle_death(); return

	# Self collision
	for i in range(snake.size()):
		if snake[i] == head:
			if shield_hits > 0:
				shield_hits -= 1; _update_eff()
				dir = Vector2i(-dir.x, -dir.y); next_dir = dir
				_parts(snake[0], Color(1, .85, .2), 15)
				_ftext(snake[0], "护盾!", Color(1, .85, .2))
				_hud(); queue_redraw(); return
			_handle_death(); return
	# AI collision
	for ai in ai_snakes:
		for seg in ai["body"]:
			if seg == head:
				if shield_hits > 0:
					shield_hits -= 1; _update_eff()
					dir = Vector2i(-dir.x, -dir.y); next_dir = dir
					_parts(snake[0], Color(1, .85, .2), 15)
					_ftext(snake[0], "护盾!", Color(1, .85, .2))
					_hud(); queue_redraw(); return
				_handle_death(); return

	snake.insert(0, head)
	snake_colors.insert(0, snake_colors[0])
	var ate := false

	# Special food
	if spc_active and head == spc_pos:
		var pts_add := 1
		if double_timer > 0.0: pts_add = 2
		score += pts_add
		var info: Dictionary = SPC_INFO[spc_type]
		snake_colors[0] = info["c"]
		_parts(head, info["c"], 18)
		_ftext(head, info["d"], info["c"])
		_apply_spc(spc_type); spc_active = false
		_play_spc(); ate = true
	# Shrink food — reset snake to initial length
	if not ate:
		for si in range(shrink_foods.size()):
			if head == shrink_foods[si]:
				var pts_add := 2
				if double_timer > 0.0: pts_add = 4
				score += pts_add
				snake_colors[0] = Color(0.5, 1.0, 0.8)
				_parts(head, Color(0.5, 1.0, 0.8), 20)
				_ftext(head, "缩身!", Color(0.5, 1.0, 0.8))
				_play_spc()
				# Trim snake to initial length
				while snake.size() > INIT_SNAKE_LEN:
					snake.pop_back(); snake_colors.pop_back()
				shrink_foods.remove_at(si)
				_place_shrink_food()
				ate = true
				break
	# Persistent map specials (Shield, Freeze, Double)
	if not ate:
		for mi in range(map_spc.size()):
			var ms: Dictionary = map_spc[mi]
			if head == ms["pos"]:
				var pts_add := 1
				if double_timer > 0.0: pts_add = 2
				score += pts_add
				var ms_type: int = ms["type"]
				var ms_spc: Spc = ms_type as Spc
				var info: Dictionary = SPC_INFO[ms_spc]
				snake_colors[0] = info["c"]
				_parts(head, info["c"], 18)
				_ftext(head, info["d"], info["c"])
				_apply_spc(ms_spc)
				_play_spc()
				map_spc.remove_at(mi)
				_place_map_spc(ms_type)
				ate = true
				break
	if not ate:
		# Normal food — check all foods
		for fi in range(foods.size()):
			var fd: Dictionary = foods[fi]
			if head == fd["pos"]:
				var pts_add := 1
				if double_timer > 0.0: pts_add = 2
				score += pts_add
				var cidx: int = fd["cidx"]
				var fc: Color = FCOLORS[cidx][1]
				snake_colors[0] = fc
				color_eaten[cidx] += 1
				_parts(head, fc, 12); _play_eat()
				_check_hs()
				foods.remove_at(fi)
				_place_food()
				_try_spc()
				_check_stage_clear()
				ate = true
				break

	if not ate:
		snake.pop_back(); snake_colors.pop_back()

	_hud(); queue_redraw()

# =========================================================
#  AI TICK
# =========================================================
func _on_ai_timer_timeout() -> void:
	if not is_running or is_paused:
		return
	if freeze_timer > 0.0:
		return  # AI frozen
	for ai in ai_snakes:
		ai["turn_cd"] -= 1
		if ai["turn_cd"] <= 0:
			_ai_pick_dir(ai)
			ai["turn_cd"] = randi_range(3, 8)
		var new_head: Vector2i = ai["body"][0] + ai["dir"]
		if new_head.x < 0 or new_head.x >= WORLD_W or new_head.y < 0 or new_head.y >= WORLD_H or walls.has(new_head):
			_ai_pick_dir(ai)
			new_head = ai["body"][0] + ai["dir"]
			if new_head.x < 0 or new_head.x >= WORLD_W or new_head.y < 0 or new_head.y >= WORLD_H or walls.has(new_head):
				new_head = ai["body"][0]
		if new_head in ai["body"]:
			_ai_pick_dir(ai)
			new_head = ai["body"][0] + ai["dir"]
		ai["body"].insert(0, new_head)
		if ai["body"].size() > ai["max_len"]:
			ai["body"].pop_back()
	queue_redraw()

func _ai_pick_dir(ai: Dictionary) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var cur: Vector2i = ai["dir"]
	var opposite := Vector2i(-cur.x, -cur.y)
	dirs.erase(opposite)
	ai["dir"] = dirs[randi() % dirs.size()]

func _spawn_ai_snakes(count: int) -> void:
	ai_snakes.clear()
	for i in count:
		var sx := randi_range(10, WORLD_W - 10)
		var sy := randi_range(10, WORLD_H - 10)
		var tries := 0
		while tries < 200:
			if abs(sx - WORLD_W/2) >= 15 or abs(sy - WORLD_H/2) >= 15:
				if _is_playable(Vector2i(sx, sy)):
					break
			sx = randi_range(10, WORLD_W - 10)
			sy = randi_range(10, WORLD_H - 10)
			tries += 1
		var d: Vector2i = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)][randi()%4]
		var body: Array[Vector2i] = []
		var alen: int = AI_LENGTHS[i % AI_LENGTHS.size()]
		for j in alen:
			body.append(Vector2i(sx - d.x * j, sy - d.y * j))
		ai_snakes.append({
			"body": body, "dir": d, "color": AI_COLORS[i % AI_COLORS.size()],
			"max_len": alen, "turn_cd": randi_range(2, 6),
		})
# =========================================================
#  WALLS & BOMBS
# =========================================================
func _generate_walls() -> void:
	walls.clear()
	# -- Solid border on all 4 edges (2 cells thick) --
	for x in WORLD_W:
		for t in 2:
			walls[Vector2i(x, t)] = true
			walls[Vector2i(x, WORLD_H - 1 - t)] = true
	for y in WORLD_H:
		for t in 2:
			walls[Vector2i(t, y)] = true
			walls[Vector2i(WORLD_W - 1 - t, y)] = true
	# -- Irregular interior boundary --
	var cx := float(WORLD_W) / 2.0
	var cy := float(WORLD_H) / 2.0
	var radii: Array[float] = []
	var base_r := minf(cx, cy) - 2.0
	var seeds: Array[float] = []
	for _i in 6:
		seeds.append(randf() * TAU)
	for deg in 360:
		var angle := float(deg) * TAU / 360.0
		var r := base_r
		r += sin(angle * 3.0 + seeds[0]) * 6.0
		r += sin(angle * 5.0 + seeds[1]) * 4.0
		r += sin(angle * 7.0 + seeds[2]) * 3.0
		r += sin(angle * 2.0 + seeds[3]) * 5.0
		r += cos(angle * 4.0 + seeds[4]) * 3.5
		r += sin(angle * 9.0 + seeds[5]) * 2.0
		radii.append(maxf(r, 15.0))
	for x in WORLD_W:
		for y in WORLD_H:
			var dx := float(x) - cx
			var dy := float(y) - cy
			var dist := sqrt(dx * dx + dy * dy)
			var angle := atan2(dy, dx)
			if angle < 0: angle += TAU
			var deg_idx := int(angle * 360.0 / TAU) % 360
			if dist > radii[deg_idx]:
				walls[Vector2i(x, y)] = true
	# Interior rock clusters (more in later stages)
	var cluster_count := 3 + stage * 2
	for _c in cluster_count:
		var rx := randi_range(15, WORLD_W - 15)
		var ry := randi_range(15, WORLD_H - 15)
		if abs(rx - int(cx)) < 12 and abs(ry - int(cy)) < 12:
			continue
		var cluster_r := randi_range(2, 4)
		for ox in range(-cluster_r, cluster_r + 1):
			for oy in range(-cluster_r, cluster_r + 1):
				if ox * ox + oy * oy <= cluster_r * cluster_r:
					var wp := Vector2i(rx + ox, ry + oy)
					if wp.x >= 0 and wp.x < WORLD_W and wp.y >= 0 and wp.y < WORLD_H:
						walls[wp] = true
	# Pre-cache edge walls
	wall_edges.clear()
	for wp2 in walls:
		var wv: Vector2i = wp2
		for nb in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var np: Vector2i = wv + nb
			if np.x >= 0 and np.x < WORLD_W and np.y >= 0 and np.y < WORLD_H and not walls.has(np):
				wall_edges.append(wv)
				break

func _is_playable(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < WORLD_W and p.y >= 0 and p.y < WORLD_H and not walls.has(p)

func _spawn_bombs(count: int) -> void:
	bombs.clear()
	var occ := _occupied_set()
	for fd in foods:
		occ[fd["pos"]] = true
	for _i in count:
		for _try in 300:
			var p := Vector2i(randi() % WORLD_W, randi() % WORLD_H)
			if _is_playable(p) and not occ.has(p):
				if abs(p.x - WORLD_W/2) < 8 and abs(p.y - WORLD_H/2) < 8:
					continue
				bombs.append(p)
				occ[p] = true
				break

func _play_bomb() -> void:
	_tone(120, 0.35, 0.18, "saw")
	get_tree().create_timer(0.05).timeout.connect(func(): _tone(80, 0.3, 0.12, "square"))

# =========================================================
#  FOOD & SPECIAL
# =========================================================
func _place_food() -> void:
	var occ := _occupied_set()
	for fd in foods:
		occ[fd["pos"]] = true
	for b in bombs:
		occ[b] = true
	var pos := Vector2i.ZERO
	# Bias toward required colors for current stage
	var req_colors: Array = STAGES[stage][1]
	var cidx: int = req_colors[randi() % req_colors.size()] if randf() < 0.7 else randi() % FCOLORS.size()
	for _i in 500:
		var p := Vector2i(randi() % WORLD_W, randi() % WORLD_H)
		if _is_playable(p) and not occ.has(p):
			pos = p; break
	foods.append({"pos": pos, "cidx": cidx})

func _try_spc() -> void:
	if spc_active or randf() > 0.45: return
	var occ := _occupied_set()
	for fd in foods:
		occ[fd["pos"]] = true
	for b in bombs:
		occ[b] = true
	for sf in shrink_foods:
		occ[sf] = true
	for ms in map_spc:
		occ[ms["pos"]] = true
	for _i in 500:
		var p := Vector2i(randi() % WORLD_W, randi() % WORLD_H)
		if _is_playable(p) and not occ.has(p):
			spc_pos = p; break
	# Only pick from REVIVAL(0), BONUS(1), SLOW(2)
	var r := randf(); var cum := 0.0; var idx := 0
	for i in SPC_W.size():
		cum += SPC_W[i]
		if r < cum: idx = i; break
	spc_type = idx as Spc; spc_active = true; spc_ttl = 15.0

func _place_shrink_food() -> void:
	var occ := _occupied_set()
	for fd in foods:
		occ[fd["pos"]] = true
	for b in bombs:
		occ[b] = true
	for sf in shrink_foods:
		occ[sf] = true
	for ms in map_spc:
		occ[ms["pos"]] = true
	if spc_active:
		occ[spc_pos] = true
	for _i in 500:
		var p := Vector2i(randi() % WORLD_W, randi() % WORLD_H)
		if _is_playable(p) and not occ.has(p):
			shrink_foods.append(p)
			return

func _place_map_spc(stype: int) -> void:
	var occ := _occupied_set()
	for fd in foods:
		occ[fd["pos"]] = true
	for b in bombs:
		occ[b] = true
	for sf in shrink_foods:
		occ[sf] = true
	for ms in map_spc:
		occ[ms["pos"]] = true
	if spc_active:
		occ[spc_pos] = true
	for _i in 500:
		var p := Vector2i(randi() % WORLD_W, randi() % WORLD_H)
		if _is_playable(p) and not occ.has(p):
			map_spc.append({"pos": p, "type": stype})
			return

func _apply_spc(t: Spc) -> void:
	match t:
		Spc.REVIVAL: lives = mini(lives + 1, 3)
		Spc.BONUS: score += 4
		Spc.SLOW:
			slow_timer = 5.0
			mtimer.wait_time = minf(STAGES[stage][3] + 0.12, 0.35); mtimer.start()
			_update_eff()
		Spc.SHIELD:
			shield_hits = mini(shield_hits + 2, 3)
			_update_eff()
		Spc.FREEZE:
			freeze_timer = 6.0
			_update_eff()
		Spc.DOUBLE:
			double_timer = 8.0
			_update_eff()

func _update_eff() -> void:
	var parts_arr: Array[String] = []
	if slow_timer > 0.0: parts_arr.append("◎减速 %.0fs" % slow_timer)
	if shield_hits > 0: parts_arr.append("◇护盾x%d" % shield_hits)
	if freeze_timer > 0.0: parts_arr.append("※冻结AI %.0fs" % freeze_timer)
	if double_timer > 0.0: parts_arr.append("x2双倍分 %.0fs" % double_timer)
	eff_lbl.text = "  ".join(parts_arr)

# =========================================================
#  COLLISION & DEATH
# =========================================================
func _handle_death() -> void:
	if lives > 0:
		lives -= 1; dir = Vector2i(-dir.x, -dir.y); next_dir = dir
		var trim := mini(3, snake.size() - 1)
		for _i in trim: snake.pop_back(); snake_colors.pop_back()
		_parts(snake[0], Color(1, .3, .65), 20)
		_ftext(snake[0], "复活!", Color(1, .3, .65))
		_play_rev(); _hud(); queue_redraw(); return
	is_running = false; mtimer.stop(); atimer.stop()
	_parts(snake[0], Color(1, .18, .48), 30); _play_die(); _hud(); queue_redraw()
	await get_tree().create_timer(0.6).timeout
	ov_title.text = "游戏结束"
	ov_msg.text = "在 %s 阵亡\n最终分数: %d" % [STAGES[stage][0], score]
	ov_btn.text = "再来一局"; ov_btn.visible = true
	help_btn.visible = false; ov.visible = true

func _handle_timeout() -> void:
	is_running = false; mtimer.stop(); atimer.stop()
	_parts(snake[0], Color(1, 0.7, 0.3), 25); _play_die(); _hud(); queue_redraw()
	await get_tree().create_timer(0.6).timeout
	ov_title.text = "时间到!"
	ov_msg.text = "在 %s 超时\n最终分数: %d" % [STAGES[stage][0], score]
	ov_btn.text = "再来一局"; ov_btn.visible = true
	help_btn.visible = false; ov.visible = true

# =========================================================
#  STAGE & HUD
# =========================================================
func _check_stage_clear() -> void:
	var st: Array = STAGES[stage]
	var req_colors: Array = st[1]
	var need: int = st[2]
	for ci in req_colors:
		if color_eaten[ci] < need:
			return
	# Stage cleared!
	_play_stage_clear()
	is_running = false; mtimer.stop(); atimer.stop()
	await get_tree().create_timer(0.8).timeout
	if stage >= STAGES.size() - 1:
		# Won the game!
		ov_title.text = "通关!"
		ov_msg.text = "恭喜通关全部 %d 关!\n最终分数: %d" % [STAGES.size(), score]
		ov_btn.text = "再来一局"; ov_btn.visible = true
		help_btn.visible = false; ov.visible = true
	else:
		stage += 1
		ov_title.text = "过关!"
		ov_msg.text = "进入 %s\n当前分数: %d\n时间限制: %d秒" % [STAGES[stage][0], score, int(STAGES[stage][7])]
		ov_btn.text = "下一关"; ov_btn.visible = true
		help_btn.visible = false; ov.visible = true

func _check_hs() -> void:
	if score > high_score: high_score = score; _save_hs()

func _hud() -> void:
	scr_lbl.text = "分数: %d" % score
	lvl_lbl.text = STAGES[stage][0]
	hi_lbl.text = "最高分: %d" % high_score
	lives_lbl.text = ("♥ " + "♥".repeat(lives)) if lives > 0 else "♥ —"

func _play_stage_clear() -> void:
	for i in 5:
		var fs := [523.0, 659.0, 784.0, 1047.0, 1318.0]
		get_tree().create_timer(i * 0.1).timeout.connect(func(): _tone(fs[i], 0.15, 0.1, "square"))

# =========================================================
#  HELPERS
# =========================================================
func _occupied_set() -> Dictionary:
	var d: Dictionary = {}
	for s in snake: d[s] = true
	for ai in ai_snakes:
		for s in ai["body"]: d[s] = true
	return d

func _load_hs() -> int:
	var f := FileAccess.open("user://hs.dat", FileAccess.READ)
	return f.get_32() if f else 0

func _save_hs() -> void:
	var f := FileAccess.open("user://hs.dat", FileAccess.WRITE)
	if f: f.store_32(high_score)
# =========================================================
#  DRAWING
# =========================================================
func _process(delta: float) -> void:
	food_anim += delta * 4.0
	if is_running and not is_paused and mtimer.wait_time > 0:
		move_progress = clampf(move_progress + delta / mtimer.wait_time, 0.0, 1.0)
	# Stage timer countdown
	if is_running and not is_paused:
		stage_time -= delta
		var mins := int(stage_time) / 60
		var secs := int(stage_time) % 60
		if stage_time <= 10.0:
			timer_lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		else:
			timer_lbl.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
		timer_lbl.text = "%d:%02d" % [mins, secs]
		if stage_time <= 0.0:
			stage_time = 0.0
			_handle_timeout()
			return
	if not snake.is_empty():
		var ease_t := move_progress * move_progress * (3.0 - 2.0 * move_progress)
		var lerped := Vector2(prev_head).lerp(Vector2(snake[0]), ease_t)
		cam.position = lerped * CELL
	for i in range(parts.size()-1, -1, -1):
		var p: Dictionary = parts[i]
		p["x"] += p["vx"] * delta * 60.0
		p["y"] += p["vy"] * delta * 60.0
		p["vx"] *= 0.96; p["vy"] *= 0.96
		p["life"] -= p["decay"] * delta * 60.0
		if p["life"] <= 0: parts.remove_at(i)
	for i in range(ftexts.size()-1, -1, -1):
		var ft: Dictionary = ftexts[i]
		ft["y"] -= 0.8 * delta * 60.0
		ft["life"] -= 0.015 * delta * 60.0
		if ft["life"] <= 0: ftexts.remove_at(i)
	queue_redraw()

func _draw() -> void:
	var cs := float(CELL)
	# -- World background --
	draw_rect(Rect2(Vector2.ZERO, Vector2(WORLD_PX, WORLD_PY)), Color(0.06, 0.02, 0.03), true)
	# -- Playable floor (visible region only) --
	var cam_min := cam.position - Vector2(450, 350)
	var cam_max := cam.position + Vector2(450, 350)
	var x0 := maxi(0, int(cam_min.x / cs) - 1)
	var y0 := maxi(0, int(cam_min.y / cs) - 1)
	var x1 := mini(WORLD_W, int(cam_max.x / cs) + 2)
	var y1 := mini(WORLD_H, int(cam_max.y / cs) + 2)
	for x in range(x0, x1):
		for y in range(y0, y1):
			if not walls.has(Vector2i(x, y)):
				var shade := 0.045 if (x + y) % 2 == 0 else 0.04
				draw_rect(Rect2(Vector2(x, y) * cs, Vector2(cs, cs)), Color(shade, shade, shade + 0.01), true)
	# -- RED BRICK WALLS --
	for wv in wall_edges:
		var wx := float(wv.x) * cs; var wy := float(wv.y) * cs
		if wx < cam_min.x - cs or wx > cam_max.x or wy < cam_min.y - cs or wy > cam_max.y:
			continue
		# Brick base
		draw_rect(Rect2(Vector2(wx, wy), Vector2(cs, cs)), Color(0.45, 0.08, 0.06), true)
		# Brick pattern: 2 rows of bricks per cell
		var half := cs / 2.0
		var mortar := Color(0.2, 0.04, 0.03)
		var brick_light := Color(0.55, 0.12, 0.08)
		var brick_dark := Color(0.35, 0.06, 0.04)
		# Top brick row
		var off_top := 0.0 if wv.y % 2 == 0 else cs * 0.4
		draw_rect(Rect2(Vector2(wx, wy), Vector2(cs, half - 1)), brick_light if (wv.x + wv.y) % 2 == 0 else brick_dark, true)
		# Bottom brick row
		draw_rect(Rect2(Vector2(wx, wy + half + 1), Vector2(cs, half - 1)), brick_dark if (wv.x + wv.y) % 2 == 0 else brick_light, true)
		# Mortar lines
		draw_rect(Rect2(Vector2(wx, wy + half - 1), Vector2(cs, 2)), mortar, true)  # horizontal
		var vx := wx + cs * (0.5 if wv.y % 2 == 0 else 0.0)
		if vx > wx and vx < wx + cs:
			draw_rect(Rect2(Vector2(vx - 1, wy), Vector2(2, half)), mortar, true)  # vertical top
		var vx2 := wx + cs * (0.0 if wv.y % 2 == 0 else 0.5)
		if vx2 > wx and vx2 < wx + cs:
			draw_rect(Rect2(Vector2(vx2 - 1, wy + half), Vector2(2, half)), mortar, true)  # vertical bottom
		# Edge glow
		draw_rect(Rect2(Vector2(wx, wy), Vector2(cs, cs)), Color(1, 0.15, 0.1, 0.08), false, 1.0)

	if snake.is_empty(): return
	var font := ThemeDB.fallback_font

	# -- AI SNAKES --
	for ai in ai_snakes:
		var ac: Color = ai["color"]
		# Frozen effect
		var frozen_tint := 1.0
		if freeze_timer > 0.0:
			frozen_tint = 0.4 + sin(food_anim * 3.0) * 0.1
		var body: Array = ai["body"]
		for i in range(body.size()-1, -1, -1):
			var s: Vector2i = body[i]
			var t := 1.0 - float(i) / maxf(body.size(), 1)
			var a := lerpf(0.25, ac.a, t) * frozen_tint
			var col := Color(ac.r, ac.g, ac.b, a)
			if freeze_timer > 0.0:
				col = Color(lerpf(ac.r, 0.5, 0.3), lerpf(ac.g, 0.8, 0.3), lerpf(ac.b, 1.0, 0.3), a)
			var pos := Vector2(s) * cs
			var cx2 := pos.x + cs/2; var cy2 := pos.y + cs/2
			var r2 := cs * 0.38 if i > 0 else cs * 0.44
			var pts := PackedVector2Array([
				Vector2(cx2, cy2 - r2), Vector2(cx2 + r2, cy2),
				Vector2(cx2, cy2 + r2), Vector2(cx2 - r2, cy2),
			])
			draw_colored_polygon(pts, col)
			if i == 0:
				for j in 4:
					draw_line(pts[j], pts[(j+1)%4], Color(ac.r, ac.g, ac.b, 0.5), 1.5)
				var ex1 := Vector2(cx2 - cs*0.12, cy2 - cs*0.05)
				var ex2 := Vector2(cx2 + cs*0.12, cy2 - cs*0.05)
				for ex in [ex1, ex2]:
					draw_line(ex + Vector2(-2,-2), ex + Vector2(2,2), Color(1,0.3,0.3,0.8), 1.5)
					draw_line(ex + Vector2(2,-2), ex + Vector2(-2,2), Color(1,0.3,0.3,0.8), 1.5)

	# -- NORMAL FOODS --
	for fdi in range(foods.size()):
		var fd: Dictionary = foods[fdi]
		var fp := Vector2(fd["pos"]) * cs
		var fc: Color = FCOLORS[fd["cidx"]][1]
		var phase := food_anim + float(fdi) * 1.5
		var fr := cs * (0.35 + sin(phase) * 0.06)
		var glow_a := 0.1 + sin(phase * 0.7) * 0.06
		draw_circle(fp + Vector2(cs/2, cs/2), cs * 0.8, Color(fc.r, fc.g, fc.b, glow_a))
		draw_circle(fp + Vector2(cs/2, cs/2), fr, fc)
		draw_string(font, fp + Vector2(cs/2 - 10, -2), FCOLORS[fd["cidx"]][0], HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(fc.r, fc.g, fc.b, 0.5))

	# -- BOMBS --
	for b in bombs:
		var bp := Vector2(b) * cs
		var bphase := food_anim * 1.5
		var bpulse := 0.6 + sin(bphase) * 0.2
		draw_circle(bp + Vector2(cs/2, cs/2), cs * 0.9, Color(1, 0.2, 0.0, 0.08 + sin(bphase) * 0.04))
		draw_circle(bp + Vector2(cs/2, cs/2), cs * 0.35, Color(0.15, 0.05, 0.05, bpulse))
		draw_string(font, bp + Vector2(cs*0.12, cs*0.78), "💣", HORIZONTAL_ALIGNMENT_LEFT, -1, int(cs*0.65), Color(1, 0.3, 0.1, bpulse))

	# -- SHRINK FOODS --
	for sfi in range(shrink_foods.size()):
		var sfp := Vector2(shrink_foods[sfi]) * cs
		var sph := food_anim + float(sfi) * 2.0
		var sf_pulse := 0.7 + sin(sph * 1.8) * 0.3
		var sf_r := cs * (0.38 + sin(sph) * 0.05)
		var sf_col := Color(0.5, 1.0, 0.8)
		var sf_center := sfp + Vector2(cs/2, cs/2)
		# Outer glow
		draw_circle(sf_center, cs * 1.0, Color(sf_col.r, sf_col.g, sf_col.b, 0.08 * sf_pulse))
		# Rotating diamond shape
		var rot := food_anim * 1.5 + float(sfi) * 1.2
		var diamond_r := cs * 0.4
		var diamond_pts := PackedVector2Array([
			sf_center + Vector2(cos(rot), sin(rot)) * diamond_r,
			sf_center + Vector2(cos(rot + PI/2), sin(rot + PI/2)) * diamond_r,
			sf_center + Vector2(cos(rot + PI), sin(rot + PI)) * diamond_r,
			sf_center + Vector2(cos(rot + PI*1.5), sin(rot + PI*1.5)) * diamond_r,
		])
		draw_colored_polygon(diamond_pts, Color(sf_col.r, sf_col.g, sf_col.b, 0.35 * sf_pulse))
		for di in 4:
			draw_line(diamond_pts[di], diamond_pts[(di+1)%4], Color(sf_col.r, sf_col.g, sf_col.b, 0.7 * sf_pulse), 1.5)
		# Inner circle
		draw_circle(sf_center, sf_r * 0.5, Color(sf_col.r, sf_col.g, sf_col.b, 0.5 * sf_pulse))
		# Arrow-down symbol (shrink)
		draw_string(font, sfp + Vector2(cs*0.15, cs*0.78), "↓", HORIZONTAL_ALIGNMENT_LEFT, -1, int(cs*0.65), Color(sf_col.r, sf_col.g, sf_col.b, sf_pulse))
		# Label above
		draw_string(font, sfp + Vector2(cs/2 - 14, -4), "缩身", HORIZONTAL_ALIGNMENT_CENTER, 36, 9, Color(sf_col.r, sf_col.g, sf_col.b, 0.6))

	# -- PERSISTENT MAP SPECIALS (Shield, Freeze, Double) --
	for msi in range(map_spc.size()):
		var ms: Dictionary = map_spc[msi]
		var ms_type: int = ms["type"]
		var ms_spc: Spc = ms_type as Spc
		var info: Dictionary = SPC_INFO[ms_spc]
		var mc: Color = info["c"]
		var msp := Vector2(ms["pos"]) * cs
		var mph := food_anim + float(msi) * 1.7
		var mpulse := 0.7 + sin(mph * 2.0) * 0.3
		var mcenter := msp + Vector2(cs/2, cs/2)
		# Outer pulsing ring
		var mring := cs * (0.65 + sin(mph * 2.5) * 0.12)
		draw_circle(mcenter, cs * 1.1, Color(mc.r, mc.g, mc.b, 0.06 * mpulse))
		draw_circle(mcenter, mring, Color(mc.r, mc.g, mc.b, 0.12 * mpulse))
		# Inner glow
		draw_circle(mcenter, cs * 0.4, Color(mc.r, mc.g, mc.b, 0.4 * mpulse))
		# Symbol
		var sym: String = info["s"]
		draw_string(font, msp + Vector2(cs*0.05, cs*0.8), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, int(cs*0.75), Color(mc.r, mc.g, mc.b, mpulse))
		# Description label
		var desc: String = info["d"]
		draw_string(font, msp + Vector2(cs/2 - 16, -4), desc, HORIZONTAL_ALIGNMENT_CENTER, 40, 9, Color(mc.r, mc.g, mc.b, 0.65))

	# -- SPECIAL FOOD --
	if spc_active:
		var si: Dictionary = SPC_INFO[spc_type]
		var sp := Vector2(spc_pos) * cs
		var blink := 1.0
		if spc_ttl < 3.0:
			blink = 1.0 if fmod(spc_ttl * 4.0, 1.0) > 0.5 else 0.3
		var sc2: Color = si["c"]
		var spc_center := sp + Vector2(cs/2, cs/2)
		# Outer pulsing ring
		var ring_r := cs * (0.7 + sin(food_anim * 2.5) * 0.15)
		draw_circle(spc_center, cs * 1.2, Color(sc2.r, sc2.g, sc2.b, 0.06 * blink))
		draw_circle(spc_center, ring_r, Color(sc2.r, sc2.g, sc2.b, 0.15 * blink))
		# Inner glow
		draw_circle(spc_center, cs * 0.45, Color(sc2.r, sc2.g, sc2.b, 0.35 * blink))
		# Symbol (larger)
		draw_string(font, sp + Vector2(cs*0.05, cs*0.8), si["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(cs*0.8), Color(sc2.r, sc2.g, sc2.b, blink))
		# Description text above
		draw_string(font, sp + Vector2(cs/2 - 16, -4), si["d"], HORIZONTAL_ALIGNMENT_CENTER, 40, 9, Color(sc2.r, sc2.g, sc2.b, 0.7 * blink))

	# -- PLAYER SNAKE --
	# Shield aura
	if shield_hits > 0 and not snake.is_empty():
		var sh_a := 0.12 + sin(food_anim * 2.0) * 0.05
		var sh_pos := Vector2(snake[0]) * cs
		draw_circle(sh_pos + Vector2(cs/2, cs/2), cs * 0.8, Color(1, 0.85, 0.2, sh_a))
	for i in range(snake.size()-1, -1, -1):
		var s := snake[i]; var scl: Color = snake_colors[i]
		var t := 1.0 - float(i) / maxf(snake.size(), 1)
		var dc := Color(lerpf(scl.r*0.5, scl.r, t), lerpf(scl.g*0.5, scl.g, t), lerpf(scl.b*0.5, scl.b, t), 1.0)
		var pad := 1.0 if i == 0 else 2.0
		var pos := Vector2(s) * cs + Vector2(pad, pad)
		var sz := cs - pad * 2.0; var rd := cs * 0.2 if i == 0 else cs * 0.1
		if i == 0:
			var pulse := 0.15 + sin(food_anim * 1.2) * 0.08
			draw_circle(pos + Vector2(sz/2, sz/2), cs * 0.6, Color(dc.r, dc.g, dc.b, pulse))
		_rrect(pos, Vector2(sz, sz), rd, dc)
		if i == 0:
			var ct := Vector2(s) * cs
			var ox := Vector2(dir) * cs * 0.1
			var e1 := ct + Vector2(cs*0.3, cs*0.35) + ox
			var e2 := ct + Vector2(cs*0.7, cs*0.35) + ox
			draw_circle(e1, cs*0.09, Color.WHITE)
			draw_circle(e2, cs*0.09, Color.WHITE)
			draw_circle(e1 + Vector2(dir)*1.5, cs*0.04, Color(0.04,0.04,0.07))
			draw_circle(e2 + Vector2(dir)*1.5, cs*0.04, Color(0.04,0.04,0.07))

	# -- PARTICLES --
	for p in parts:
		var a := clampf(p["life"], 0, 1)
		var ea := a * a
		var pc: Color = p["color"]
		draw_circle(Vector2(p["x"], p["y"]), p["r"] * ea, Color(pc.r, pc.g, pc.b, ea))

	# -- FLOATING TEXTS --
	for ft in ftexts:
		var a := clampf(ft["life"], 0, 1)
		var ftc: Color = ft["color"]
		draw_string(font, Vector2(ft["x"]-20, ft["y"]), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color(ftc.r, ftc.g, ftc.b, a))

	# -- STAGE PROGRESS (drawn in world near snake) --
	if is_running and not snake.is_empty():
		var st: Array = STAGES[stage]
		var req_colors: Array = st[1]
		var need: int = st[2]
		var base := cam.position + Vector2(-280, -200)
		draw_rect(Rect2(base - Vector2(5, 5), Vector2(180, 14.0 * req_colors.size() + 18)), Color(0, 0, 0, 0.5), true)
		draw_string(font, base, "目标:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.7, 0.8))
		for ci_idx in req_colors.size():
			var ci: int = req_colors[ci_idx]
			var eaten: int = color_eaten[ci]
			var done := eaten >= need
			var yy := base.y + 14.0 + float(ci_idx) * 14.0
			var label := "%s %d/%d" % [FCOLORS[ci][0], mini(eaten, need), need]
			var col: Color = FCOLORS[ci][1]
			if done:
				col = Color(col.r, col.g, col.b, 0.4)
				label += " ✓"
			draw_string(font, Vector2(base.x + 4, yy), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

	# -- PAUSE --
	if is_paused and is_running:
		var cp := cam.position
		draw_rect(Rect2(cp - Vector2(200, 150), Vector2(400, 300)), Color(0,0,0,0.6), true)
		draw_string(font, cp + Vector2(-40, 0), "已 暂 停", HORIZONTAL_ALIGNMENT_CENTER, 100, 28, Color(1, 0.9, 0, 1))

func _rrect(pos: Vector2, sz: Vector2, r: float, c: Color) -> void:
	r = minf(r, minf(sz.x, sz.y) / 2.0)
	draw_rect(Rect2(pos + Vector2(r, 0), sz - Vector2(r*2, 0)), c, true)
	draw_rect(Rect2(pos + Vector2(0, r), sz - Vector2(0, r*2)), c, true)
	draw_circle(pos + Vector2(r, r), r, c)
	draw_circle(pos + Vector2(sz.x-r, r), r, c)
	draw_circle(pos + Vector2(r, sz.y-r), r, c)
	draw_circle(pos + Vector2(sz.x-r, sz.y-r), r, c)
# =========================================================
#  PARTICLES & FLOATING TEXT
# =========================================================
func _parts(gp: Vector2i, col: Color, n: int) -> void:
	var cx := float(gp.x) * CELL + CELL / 2.0
	var cy := float(gp.y) * CELL + CELL / 2.0
	for _i in n:
		var ang := randf() * TAU; var spd := 1.0 + randf() * 3.0
		parts.append({"x": cx, "y": cy, "vx": cos(ang)*spd, "vy": sin(ang)*spd,
			"life": 1.0, "decay": 0.02 + randf()*0.03, "color": col, "r": 2.0 + randf()*3.0})

func _ftext(gp: Vector2i, txt: String, col: Color) -> void:
	ftexts.append({"x": float(gp.x)*CELL + CELL/2.0, "y": float(gp.y)*CELL,
		"text": txt, "color": col, "life": 1.0})

# =========================================================
#  AUDIO
# =========================================================
func _make_wav(freq: float, dur: float, vol: float = 0.15, wave: String = "sine") -> AudioStreamWAV:
	var sr := 22050; var ns := int(sr * dur)
	var data := PackedByteArray(); data.resize(ns * 2)
	for i in ns:
		var t := float(i) / sr
		var env := clampf(1.0 - t / dur, 0, 1) * vol
		var v := 0.0
		match wave:
			"sine": v = sin(t * freq * TAU) * env
			"square": v = (1.0 if fmod(t*freq,1.0) < 0.5 else -1.0) * env * 0.5
			"saw": v = (fmod(t*freq,1.0)*2.0 - 1.0) * env * 0.5
		var s := clampi(int(v * 32767), -32768, 32767)
		data[i*2] = s & 0xFF; data[i*2+1] = (s >> 8) & 0xFF
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS; st.mix_rate = sr; st.data = data
	return st

func _tone(freq: float, dur: float = 0.15, vol: float = 0.15, wave: String = "sine") -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _make_wav(freq, dur, vol, wave)
	p.volume_db = -6.0; add_child(p); p.play()
	p.finished.connect(p.queue_free)

func _play_eat() -> void: _tone(800, 0.12, 0.12, "sine")
func _play_spc() -> void: _tone(880, 0.2, 0.1, "sine")
func _play_rev() -> void:
	for i in 3:
		var fs := [523.0, 659.0, 784.0]
		get_tree().create_timer(i*0.07).timeout.connect(func(): _tone(fs[i], 0.12, 0.08, "sine"))
func _play_die() -> void: _tone(200, 0.4, 0.12, "saw")

func _generate_music() -> void:
	var sr := 22050
	var duration := 8.0
	var ns := int(sr * duration)
	var data := PackedByteArray(); data.resize(ns * 2)
	var chords := [
		[220.0, 261.6, 329.6],
		[174.6, 220.0, 261.6],
		[261.6, 329.6, 392.0],
		[196.0, 246.9, 293.7],
	]
	var chord_dur := duration / 4.0
	for i in ns:
		var t := float(i) / sr
		var chord_idx := clampi(int(t / chord_dur), 0, 3)
		var chord: Array = chords[chord_idx]
		var v := 0.0
		for note in chord:
			v += sin(t * note * TAU) * 0.04
			v += sin(t * (note * 1.003) * TAU) * 0.025
		v += sin(t * chord[0] * 0.5 * TAU) * 0.03
		v *= 0.7 + 0.3 * sin(t * 0.5 * TAU)
		var pos_in_chord := fmod(t, chord_dur) / chord_dur
		var env := 1.0
		if pos_in_chord < 0.05: env = pos_in_chord / 0.05
		elif pos_in_chord > 0.92: env = (1.0 - pos_in_chord) / 0.08
		v *= env
		var s := clampi(int(v * 32767), -32768, 32767)
		data[i*2] = s & 0xFF; data[i*2+1] = (s >> 8) & 0xFF
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = sr
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = ns
	music.stream = st

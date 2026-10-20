extends RefCounted
# 碰撞層（位元值），一律透過 preload 常數取用。

const WORLD := 1  # 地形
const PLAYER_BODY := 2  # 角色身體；不與敵人身體碰撞（PROTO1-4：可穿過敵人）
const ENEMY_BODY := 4  # 敵人身體
const PLAYER_HURT := 8  # 角色受擊判定
const ENEMY_HURT := 16  # 敵人受擊判定
const POGO := 32  # 彈跳物
const BARRIER := 64  # 木障的受擊判定（MV-PROTO-002）
const LIGHT := 128  # Boss 光源（MV-PROTO-003）：只有飛鏢的射線查得到

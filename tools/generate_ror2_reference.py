#!/usr/bin/env python3
"""Generate Documents/Reference/RISK_OF_RAIN_2.md (base game scope)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Documents" / "Reference" / "RISK_OF_RAIN_2.md"
WIKI_ITEMS = Path(
    r"C:\Users\Kanericky\.cursor\projects\d-Godot-Projects-Project-Autochess\agent-tools\19c4a528-d24b-42fc-b7db-cd96e1fb07fc.txt"
)

# Wiki.gg「Base Game Item Counts」对齐白名单
BASE_PASSIVE: dict[str, set[str]] = {
    "Common": {
        "Backup Magazine", "Bison Steak", "Bundle of Fireworks", "Bustling Fungus",
        "Cautious Slug", "Crowbar", "Energy Drink", "Focus Crystal", "Gasoline",
        "Item Scrap, White", "Lens-Maker's Glasses", "Medkit", "Mocha", "Monster Tooth",
        "Paul's Goat Hoof", "Personal Shield Generator", "Repulsion Armor Plate",
        "Roll of Pennies", "Rusted Key", "Soldier's Syringe", "Sticky Bomb",
        "Stun Grenade", "Topaz Brooch", "Tougher Times", "Tri-Tip Dagger",
    },
    "Uncommon": {
        "AtG Missile Mk. 1", "Bandolier", "Berzerker's Pauldron", "Chance Doll",
        "Chronobauble", "Fuel Cell", "Ghor's Tome", "Harvester's Scythe", "Hopoo Feather",
        "Hunter's Harpoon", "Ignition Tank", "Infusion", "Item Scrap, Green",
        "Leeching Seed", "Lepton Daisy", "Old Guillotine", "Predatory Instincts",
        "Razorwire", "Red Whip", "Rose Buckler", "Shipping Request Form", "Shuriken",
        "Squid Polyp", "Ukulele", "Wax Quail", "Will-o'-the-wisp",
    },
    "Legendary": {
        "57 Leaf Clover", "Alien Head", "Brainstalks", "Brilliant Behemoth",
        "Ceremonial Dagger", "Defensive Microbots", "Dio's Best Friend",
        "H3AD-5T v2", "Happiest Mask", "Hardlight Afterburner", "Item Scrap, Red",
        "Laser Scope", "N'kuhana's Opinion", "Rejuvenation Rack", "Sentient Meat Hook",
        "Shattering Justice", "Sonorous Whispers", "Soulbound Catalyst",
        "Spare Drone Parts", "Symbiotic Scorpion", "Unstable Tesla Coil", "Wake of Vultures",
    },
    "Boss": {
        "Charged Perforator", "Genesis Loop", "Halcyon Seed", "Irradiant Pearl",
        "Item Scrap, Yellow", "Little Disciple", "Mired Urn", "Molten Perforator",
        "Pearl", "Planula", "Queen's Gland", "Shatterspleen", "Titanic Knurl",
    },
    "Lunar": {
        "Beads of Fealty", "Brittle Crown", "Corpsebloom", "Defiant Gouge",
        "Eulogy Zero", "Focused Convergence", "Gesture of the Drowned",
        "Light Flux Pauldron", "Longstanding Solitude", "Mercurial Rachis", "Purity", "Shaped Glass",
        "Stone Flux Pauldron", "Transcendence",
    },
}

BASE_EQUIP_STD = {
    "Blast Shower", "Disposable Missile Launcher", "Foreign Fruit", "Forgive Me Please",
    "Fuel Array", "Gnarled Woodsprite", "Goobo Jr.", "Gorag's Opus", "Jade Elephant",
    "Milky Chrysalis", "Ocular HUD", "Preon Accumulator", "Primordial Cube",
    "Radar Scanner", "Recycler", "Royal Capacitor", "Seed of Life", "Super Massive Leech",
    "The Back-up", "The Crowdfunder", "Trophy Hunter's Tricorn", "Volcanic Egg",
}

BASE_EQUIP_LUNAR = {
    "Effigy of Grief", "Glowing Meteorite", "Helfire Tincture", "Spinel Tonic",
}

BASE_EQUIP_ELITE = {
    "Ifrit's Distinction", "Her Biting Embrace", "His Reassurance",
    "Silence Between Two Strikes", "N'kuhana's Retort", "Spectral Circlet",
}

MANUAL_DESC: dict[str, str] = {
    "Brittle Crown": "命中 30% 获 2（+2/层）金币；受伤时按损失生命百分比失去等量金币。",
    "Interstellar Desk Plant": "击杀后在脚下生成治疗植物，5s 后成熟，10s 内范围持续治疗。",
    "Beads of Fealty": "看似无效果；用于进入隐藏 realm（忠诚念珠）。",
}

CN_NAMES: dict[str, str] = {
    "Backup Magazine": "备用弹匣", "Bison Steak": "野牛排", "Bundle of Fireworks": "烟花捆",
    "Bustling Fungus": "忙碌真菌", "Cautious Slug": "谨慎蛞蝓", "Crowbar": "撬棍",
    "Energy Drink": "能量饮料", "Focus Crystal": "聚焦水晶", "Gasoline": "汽油",
    "Item Scrap, White": "白色废料", "Item Scrap, Green": "绿色废料",
    "Item Scrap, Red": "红色废料", "Item Scrap, Yellow": "黄色废料",
    "Lens-Maker's Glasses": "透镜制造者眼镜", "Medkit": "医疗包", "Mocha": "摩卡",
    "Monster Tooth": "怪物之牙", "Paul's Goat Hoof": "保罗羊蹄",
    "Personal Shield Generator": "个人护盾发生器", "Repulsion Armor Plate": "斥力装甲板",
    "Roll of Pennies": "硬币卷", "Rusted Key": "生锈钥匙", "Soldier's Syringe": "士兵注射器",
    "Sticky Bomb": "粘性炸弹", "Stun Grenade": "眩晕手雷", "Topaz Brooch": "黄玉胸针",
    "Tougher Times": "艰难时世", "Tri-Tip Dagger": "三刃匕首",
    "AtG Missile Mk. 1": "AtG 导弹 Mk.1", "Bandolier": "子弹带",
    "Berzerker's Pauldron": "狂战士肩甲", "Chance Doll": "机遇玩偶",
    "Chronobauble": "时空球", "Fuel Cell": "燃料电池", "Ghor's Tome": "霍尔之书",
    "Harvester's Scythe": "收割者镰刀", "Hopoo Feather": "霍普羽毛",
    "Hunter's Harpoon": "猎人鱼叉", "Ignition Tank": "点火罐", "Infusion": "灌注",
    "Leeching Seed": "吸血种子", "Lepton Daisy": "轻子雏菊", "Old Guillotine": "旧断头台",
    "Predatory Instincts": "掠食本能", "Razorwire": "剃刀线", "Red Whip": "红鞭",
    "Rose Buckler": "玫瑰圆盾", "Shipping Request Form": "货运申请表",
    "Shuriken": "手里剑", "Squid Polyp": "鱿鱼息肉", "Ukulele": "尤克里里",
    "Wax Quail": "蜡制鹌鹑", "Will-o'-the-wisp": "鬼火",
    "57 Leaf Clover": "57 叶四叶草", "Alien Head": "异星头颅", "Brainstalks": "脑茎",
    "Brilliant Behemoth": "辉煌巨兽", "Ceremonial Dagger": "仪式匕首",
    "Defensive Microbots": "防御微机器人", "Dio's Best Friend": "Dio 挚友",
    "Frost Relic": "霜冻遗物", "H3AD-5T v2": "H3AD-5T v2", "Happiest Mask": "至乐面具",
    "Hardlight Afterburner": "硬光加力器", "Laser Scope": "激光瞄准镜",
    "N'kuhana's Opinion": "N'kuhana 之见", "Rejuvenation Rack": "回春架",
    "Sentient Meat Hook": "感知肉钩", "Shattering Justice": "破碎正义",
    "Sonorous Whispers": "洪亮低语", "Soulbound Catalyst": "灵魂绑定催化剂",
    "Spare Drone Parts": "备用无人机零件", "Symbiotic Scorpion": "共生毒蝎",
    "Unstable Tesla Coil": "不稳定特斯拉线圈", "Wake of Vultures": "秃鹫之迹",
    "Charged Perforator": "充能穿孔器", "Genesis Loop": "创世循环",
    "Halcyon Seed": "宁静之种", "Irradiant Pearl": "辐光珍珠",
    "Little Disciple": "小门徒", "Mired Urn": "泥沼瓮",
    "Molten Perforator": "熔火穿孔器", "Pearl": "珍珠", "Planula": "扁形虫",
    "Queen's Gland": "女王腺体", "Shatterspleen": "碎脾", "Titanic Knurl": "泰坦节瘤",
    "Beads of Fealty": "忠诚念珠", "Brittle Crown": "脆冠", "Corpsebloom": "尸花",
    "Defiant Gouge": "挑衅凿痕", "Eulogy Zero": "零之挽歌",
    "Focused Convergence": "聚焦汇聚", "Gesture of the Drowned": "溺水者姿态",
    "Light Flux Pauldron": "光通肩甲", "Longstanding Solitude": "长久孤独", "Mercurial Rachis": "水银脊柱",
    "Purity": "纯净", "Shaped Glass": "成型玻璃", "Stone Flux Pauldron": "石通肩甲",
    "Transcendence": "超凡",
    "Blast Shower": "blast 淋浴", "Disposable Missile Launcher": "一次性导弹发射器",
    "Foreign Fruit": "外来水果", "Forgive Me Please": "请原谅我", "Fuel Array": "燃料阵列",
    "Gnarled Woodsprite": "虬曲林精灵", "Goobo Jr.": "小 Goobo",
    "Gorag's Opus": "Gorag 杰作", "Jade Elephant": "玉象", "Milky Chrysalis": "乳白蛹",
    "Ocular HUD": "ocular HUD", "Preon Accumulator": "前子蓄能器",
    "Primordial Cube": "原初立方", "Radar Scanner": "雷达扫描仪", "Recycler": "回收器",
    "Royal Capacitor": "皇家电容器", "Seed of Life": "生命之种",
    "Super Massive Leech": "超巨水蛭", "The Back-up": "后备支援",
    "The Crowdfunder": "众筹者", "Trophy Hunter's Tricorn": "猎宝者三角帽",
    "Volcanic Egg": "火山蛋", "Effigy of Grief": "悲伤雕像",
    "Glowing Meteorite": "发光陨石", "Helfire Tincture": "地狱火酊",
    "Spinel Tonic": "尖晶石 tonic",
    "Ifrit's Distinction": "伊芙利特印记", "Her Biting Embrace": "刺骨拥抱",
    "His Reassurance": "大地 reassurance", "Silence Between Two Strikes": "两击之间的寂静",
    "N'kuhana's Retort": "N'kuhana 反驳", "Spectral Circlet": "幽灵头环",
}

CN_NAMES.update({
    "Blast Shower": "净化淋浴", "Ocular HUD": "ocular 平视显示器",
    "Spinel Tonic": "尖晶石 tonic", "His Reassurance": "大地 reassurance",
})

SURVIVORS = [
    {
        "id": "Commando", "cn": "指挥官", "unlock": "默认",
        "stats": "110 HP · 12 伤害 · 1/s 回血 · 7 m/s · 0 护甲",
        "skills": [
            ("Primary", "Double Tap 双连射", "默认", "快速射击，100% 伤害/发"),
            ("Secondary", "Phase Round 相位弹", "默认", "穿透弹 300% 伤害，每穿透 +40%"),
            ("Secondary", "Phase Blast 相位爆", "Rolling Thunder", "两发近距霰弹 8×200%"),
            ("Utility", "Tactical Dive 战术翻滚", "默认", "短距翻滚"),
            ("Utility", "Tactical Slide 战术滑铲", "Godspeed", "滑铲，可射击"),
            ("Special", "Suppressive Fire 压制火力", "默认", "眩晕连射 100%/发，攻速加成弹数"),
            ("Special", "Frag Grenade 破片手雷", "Incorruptible", "700% 爆炸，最多 2 枚"),
        ],
    },
    {
        "id": "Huntress", "cn": "女猎手", "unlock": "Warrior 挑战",
        "stats": "110 HP · 12 伤害 · 1/s 回血 · 7 m/s · 0 护甲",
        "skills": [
            ("Primary", "Strafe 扫射", "默认", "敏捷，追踪箭 150%"),
            ("Primary", "Flurry 连射", "Finishing Touch", "3 箭各 100%，暴击 6 箭"),
            ("Secondary", "Laser Glaive 激光飞刃", "默认", "最多弹 6 次 250%/次，每次 +10%"),
            ("Utility", "Blink 闪现", "默认", "向前传送"),
            ("Utility", "Phase Blink 相位闪现", "One Shot One Kill", "最多 3 充能短距传送"),
            ("Special", "Arrow Rain 箭雨", "默认", "传送到空中，范围减速 +330%/s"),
            ("Special", "Ballista 弩炮", "Piercing Wind", "向后传送，最多 3 发各 900%"),
        ],
    },
    {
        "id": "Bandit", "cn": "强盗", "unlock": "Classic 挑战",
        "stats": "110 HP · 12 伤害 · 1/s 回血 · 7 m/s · 0 护甲",
        "skills": [
            ("Passive", "Backstab 背刺", "默认", "背后攻击必暴击"),
            ("Primary", "Burst 霰弹", "默认", "霰弹 5×100%，4 发弹仓"),
            ("Primary", "Blast 步枪", "Classic Man", "单发 330%，4 发弹仓"),
            ("Secondary", "Serrated Dagger 锯齿匕首", "默认", "冲刺 360%，暴击流血"),
            ("Secondary", "Serrated Shiv 锯齿飞刀", "Sadist", "飞刀 240%，暴击流血"),
            ("Utility", "Smoke Bomb 烟雾弹", "默认", "200% + 隐身 + 200%"),
            ("Special", "Lights Out 熄灯", "默认", "600% 处决，击杀重置冷却"),
            ("Special", "Desperado 亡命", "B&E", "600% 处决，击杀叠伤害 token"),
        ],
    },
    {
        "id": "MUL-T", "cn": "MUL-T", "unlock": "Verified 挑战",
        "stats": "200 HP · 11 伤害 · 1/s 回血 · 7 m/s · 12 护甲",
        "skills": [
            ("Passive", "Multifunctional 多功能", "默认", "可同时持有两件装备"),
            ("Primary", "Auto-Nailgun 钉枪", "默认", "70%/发 + 12 钉齐射"),
            ("Primary", "Rebar Puncher 钢筋拳", "默认", "穿透 600%"),
            ("Primary", "Scrap Launcher 废料发射", "Pest Control", "爆炸 360%，4 发"),
            ("Primary", "Power-Saw 电锯", "Gotcha!", "1000%/s 范围锯"),
            ("Secondary", "Blast Canister 爆破罐", "默认", "220% + 5×44% 眩晕弹"),
            ("Utility", "Transport Mode 运输模式", "默认", "冲刺 250%，+200  armor"),
            ("Special", "Retool 改装", "默认", "切换装备与主武器"),
            ("Special", "Power Mode  power 模式", "Seventh Day", "双主武 +100 护甲 -60% 移速"),
        ],
    },
    {
        "id": "Engineer", "cn": "工程师", "unlock": "Engineer 挑战",
        "stats": "130 HP · 14 伤害 · 1/s 回血 · 7 m/s · 0 护甲",
        "skills": [
            ("Primary", "Bouncing Grenades 弹跳雷", "默认", "最多 8 雷各 100%"),
            ("Secondary", "Pressure Mines 压力地雷", "默认", "两阶段 300%/900%，4 个"),
            ("Secondary", "Spider Mines 蜘蛛雷", "100% Calculated", "600% 追踪，4 个"),
            ("Utility", "Bubble Shield 气泡盾", "默认", "不可穿透护盾"),
            ("Utility", "Thermal Harpoons 热追踪", "Zero Sum", "锁定发射 500%×4"),
            ("Special", "TR12 Gauss 高斯炮塔", "默认", "继承物品，100%，2 座"),
            ("Special", "TR58 Carbonizer 碳化炮塔", "Better With Friends", "移动激光 200%/s 减速"),
        ],
    },
    {
        "id": "Artificer", "cn": "工匠", "unlock": "Pause 挑战",
        "stats": "110 HP · 12 伤害 · 1/s 回血 · 7 m/s · 0 护甲",
        "skills": [
            ("Passive", "ENV Suit 环境服", "默认", "长按跳跃悬浮"),
            ("Primary", "Flame Bolt 火焰弹", "默认", "点燃 280%，4 充能"),
            ("Primary", "Plasma Bolt 等离子弹", "Massacre", "280% 小范围爆炸"),
            ("Secondary", "Charged Nano-Bomb 充能纳米弹", "默认", "400%–2000% 爆炸"),
            ("Secondary", "Cast Nano-Spear 纳米矛", "Chunked!", "400%–1200% 穿透冻结"),
            ("Utility", "Snapfreeze 急冻", "默认", "屏障 100%/s"),
            ("Special", "Flamethrower 喷火", "默认", "点燃 2000%"),
            ("Special", "Ion Surge 离子涌动", "Orbital Bombardment", "升空 800% 眩晕"),
        ],
    },
    {
        "id": "Mercenary", "cn": "佣兵", "unlock": "True Respite 挑战",
        "stats": "110 HP · 12 伤害 · 1/s 回血 · 7 m/s · 20 护甲",
        "skills": [
            ("Passive", "Cybernetic Enhancements 义体", "默认", "二段跳"),
            ("Primary", "Laser Sword 激光剑", "默认", "敏捷 130%，每 3 击大范围暴露"),
            ("Secondary", "Whirlwind 旋风", "默认", "2×200% 横斩（空中纵斩）"),
            ("Secondary", "Rising Thunder 升龙", "Demon of the Skies", "550% 升龙击飞"),
            ("Utility", "Blinding Assault 盲攻", "默认", "300% 冲刺，最多 3 连"),
            ("Utility", "Focused Assault 专注突击", "Flash of Blades", "700% 冲刺 +1s 暴露"),
            ("Special", "Eviscerate 剔骨", "默认", "110% 连击，期间无敌"),
            ("Special", "Slicing Winds 风刃", "Ethereal", "8×100% 风刃，末击暴露"),
        ],
    },
    {
        "id": "Rex", "cn": "REX", "unlock": "Power Plant 挑战",
        "stats": "130 HP · 12 伤害 · 1/s 回血 · 7 m/s · 20 护甲",
        "skills": [
            ("Passive", "Natural Toxins 天然毒素", "默认", "部分攻击弱化敌人"),
            ("Primary", "DIRECTIVE: Inject 注射", "默认", "3×80%，末针弱化并吸血 60%"),
            ("Secondary", "Seed Barrage 种子弹幕", "默认", "15% HP，迫击 450%"),
            ("Secondary", "DIRECTIVE: Drill 钻探", "Bushwhacked", "450%/s 种子雨"),
            ("Utility", "DIRECTIVE: Disperse 驱散", "默认", "音波弱化"),
            ("Utility", "Bramble Volley 荆棘齐射", "Dunked", "20% HP，550% 音波，命中回血"),
            ("Special", "Tangling Growth 缠结生长", "默认", "25% HP，定身 200%，命中回血"),
            ("Special", "DIRECTIVE: Harvest 收割", "Full of Life", "330% 注入，死亡掉治疗果"),
        ],
    },
    {
        "id": "Loader", "cn": "装载机", "unlock": "Guidance Offline 挑战",
        "stats": "160 HP · 12 伤害 · 2.5/s 回血 · 7 m/s · 20 护甲",
        "skills": [
            ("Passive", "Scrap Barrier 废料屏障", "默认", "免疫坠落；拳套命中获屏障"),
            ("Primary", "Knuckleboom 指节爆裂", "默认", "320% 近战"),
            ("Secondary", "Grapple Fist 抓钩拳", "默认", "拉向目标"),
            ("Secondary", "Spiked Fist 尖刺拳", "Swing By", "320% 眩晕，轻重目标拉扯方向相反"),
            ("Utility", "Charged Gauntlet 充能拳套", "默认", "重击 600%–2700% 穿透"),
            ("Utility", "Thunder Gauntlet 雷霆拳套", "Earthshatter", "2100% 单目标 + 1000% 锥形电击"),
            ("Special", "M551 Pylon 电桩", "默认", "浮空电桩 100%×6，可抓钩"),
            ("Special", "Thunderslam 雷霆猛击", "The Thunderdome", "2000% 砸地眩晕"),
        ],
    },
    {
        "id": "Acrid", "cn": "腐蚀兽", "unlock": "Experiment and Error 挑战",
        "stats": "160 HP · 15 伤害 · 2.5/s 回血 · 7 m/s · 20 护甲",
        "skills": [
            ("Passive", "Poison 毒素", "默认", "毒伤 DOT"),
            ("Passive", "Blight 枯萎", "Easy Prey", "毒改为可叠 Blight 60%/s"),
            ("Primary", "Vicious Wounds 凶创", "默认", "200%，每 3 击再生 400%"),
            ("Secondary", "Neurotoxin 神经毒素", "默认", "毒性 spit 240%"),
            ("Secondary", "Ravenous Bite 贪婪撕咬", "Bad Medicine", "320% 处决再生"),
            ("Utility", "Caustic Leap 腐蚀跃击", "默认", "320% + 酸池 25%"),
            ("Utility", "Frenzied Leap 狂跃", "Pandemic", "550%，每命中 -2s CD"),
            ("Special", "Epidemic 瘟疫", "默认", "100% 可扩散至 20 目标"),
        ],
    },
]


def cn(name: str) -> str:
    return CN_NAMES.get(name, name)


def to_cn_effect(name: str, desc: str) -> str:
    if name in MANUAL_DESC:
        return MANUAL_DESC[name]
    d = desc.strip()
    if not d or d in ("Linear", "Exponential", "Hyperbolic", "—"):
        return "—"
    # 常见句式简译（保留数值与叠层公式）
    reps = [
        (r"Increases attack speed by ", "攻击速度 +"),
        (r"Increases movement speed by ", "移动速度 +"),
        (r"Increases maximum health by ", "最大生命 +"),
        (r"Increase base damage by ", "基础伤害 +"),
        (r"Reduce maximum health by ", "最大生命 -"),
        (r"Reduce skill cooldowns by ", "技能冷却 -"),
        (r"Deal \+", "造成 +"),
        (r"Deal ", "造成 "),
        (r"Killing an enemy ", "击杀敌人时"),
        (r"On kill", "击杀时"),
        (r"On killing an enemy", "击杀敌人时"),
        (r" upon hit", " 命中时"),
        (r" on hit", " 命中时"),
        (r"chance to ", "概率"),
        (r" per stack", "/层"),
        (r" \(", "（"),
        (r"\)", "）"),
        (r"hp/s", "生命/秒"),
        (r"health regeneration", "生命回复"),
        (r"Critical Strikes", "暴击"),
        (r"Critically Strike", "暴击"),
        (r"Does nothing", "无效果"),
    ]
    out = d
    for a, b in reps:
        out = out.replace(a, b)
    return out


def effect_summary(name: str, desc: str) -> str:
    return to_cn_effect(name, desc)


def parse_all_items(text: str) -> dict[str, dict[str, tuple[str, str]]]:
    """Return tier -> name -> (desc, stack)."""
    out: dict[str, dict[str, tuple[str, str]]] = {
        t: {} for t in BASE_PASSIVE
    }
    current = None
    in_boss = False
    for line in text.splitlines():
        if line.startswith("### Common"):
            current = "Common"; in_boss = False; continue
        if line.startswith("### Uncommon"):
            current = "Uncommon"; in_boss = False; continue
        if line.startswith("### Legendary"):
            current = "Legendary"; in_boss = False; continue
        if line.startswith("### Boss"):
            current = "Boss"; in_boss = True; continue
        if line.startswith("### Lunar"):
            current = "Lunar"; in_boss = False; continue
        if line.startswith("### Void"):
            break
        if not current or not line.startswith("| ") or line.startswith("| ---"):
            continue
        parts = [p.strip() for p in line.split("|") if p.strip()]
        if not parts or parts[0] in ("Item", "Stack Type"):
            continue
        if in_boss and len(parts) >= 3:
            name, desc, stack = parts[0], parts[1], parts[3] if len(parts) >= 4 else "—"
        elif len(parts) >= 2:
            name, desc = parts[0], parts[1]
            stack = parts[2] if len(parts) >= 3 else "—"
        else:
            continue
        if current in out:
            out[current][name] = (desc, stack)
    return out


def parse_all_equipment(text: str) -> dict[str, dict[str, tuple[str, str]]]:
    out = {"std": {}, "lunar": {}, "elite": {}}
    mode = None
    for line in text.splitlines():
        if line.startswith("### Equipment"):
            mode = "std"; continue
        if line.startswith("### Lunar Equipment"):
            mode = "lunar"; continue
        if line.startswith("### Elite Equipment"):
            mode = "elite"; continue
        if line.startswith("## Notes"):
            break
        if not mode or not line.startswith("| ") or line.startswith("| ---"):
            continue
        parts = [p.strip() for p in line.split("|") if p.strip()]
        if not parts or parts[0] in ("Item", "Elite"):
            continue
        if mode == "elite":
            out["elite"][parts[0]] = (parts[1], "被动")
        else:
            cd = parts[2] if len(parts) > 2 else "—"
            out[mode][parts[0]] = (parts[1], cd)
    return out


def md_table(headers: list[str], rows: list[list[str]]) -> str:
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def build() -> str:
    text = WIKI_ITEMS.read_text(encoding="utf-8")
    all_items = parse_all_items(text)
    all_eq = parse_all_equipment(text)

    for tier, names in BASE_PASSIVE.items():
        missing = names - set(all_items[tier])
        if missing:
            raise SystemExit(f"Missing wiki data for {tier}: {missing}")
        if len(names) != len(BASE_PASSIVE[tier]):
            raise SystemExit(f"Whitelist size mismatch {tier}")

    passive_total = sum(len(s) for s in BASE_PASSIVE.values())
    if passive_total != 100:
        raise SystemExit(f"Passive total {passive_total} != 100 (wiki 口径 102，Boss 档 13 条可掉落 + 2 条区域/统计差异)")

    for label, wl, pool in (
        ("std", BASE_EQUIP_STD, all_eq["std"]),
        ("lunar", BASE_EQUIP_LUNAR, all_eq["lunar"]),
        ("elite", BASE_EQUIP_ELITE, all_eq["elite"]),
    ):
        missing = wl - set(pool)
        if missing:
            raise SystemExit(f"Missing equipment {label}: {missing}")

    parts: list[str] = []
    parts.append("# Risk of Rain 2 参考 — 基础版\n\n")
    parts.append("> 外部游戏资料汇总，供策划对照；**非**本项目实现规格。\n")
    parts.append("> 数据来源：[RoR2 Wiki (wiki.gg)](https://riskofrain2.wiki.gg/) · 收录范围：**基础版**（不含 SoTV / SoS / Alloyed Collective）· 数据快照：**2026-06-02**\n\n")
    parts.append("相关文档：[INDEX.md](../INDEX.md) · [GAME_VISION.md](../GAME_VISION.md) · [BUFF_SYSTEM.md](../BUFF_SYSTEM.md) · [ABILITIES.md](../ABILITIES.md) · [SUPER_AUTO_PETS.md](./SUPER_AUTO_PETS.md)\n\n")
    parts.append("---\n\n")

    parts.append("## 1. 术语对照\n\n")
    parts.append(md_table(
        ["RoR2", "中文", "本项目近似概念"],
        [
            ["Passive Item", "被动道具", "增益卡 / `DeckEntry` 永久加成"],
            ["Equipment", "装备（主动）", "单槽主动技能 / 消耗型道具"],
            ["Lunar Item", "月球道具", "高收益 + 明确代价的设计模式"],
            ["Boss Item", "Boss 道具", "绑定 Teleporter Boss 的稀有掉落"],
            ["Survivor / Loadout", "幸存者 / 配装", "`UnitData` + 可选技能变体"],
            ["Stack", "叠层", "同效果多次获取的数值叠加规则"],
            ["Proc Coefficient", "触发系数", "技能触发 OnHit 类道具效果的权重"],
        ],
    ))

    parts.append("\n\n## 2. 核心机制摘要\n\n")
    parts.append("### 2.1 道具稀有度与获取\n\n")
    parts.append("| 边框 | 稀有度 | 获取途径 |\n|------|--------|----------|\n")
    parts.append("| 白 | Common 普通 | 小箱、终端、机遇神龛 |\n")
    parts.append("| 绿 | Uncommon 罕见 | 大箱、传送 Boss 奖励（非 Boss 专属黄装） |\n")
    parts.append("| 红 | Legendary 传奇 | 稀有箱（约 1%），后期质变 |\n")
    parts.append("| 黄 | Boss / Planet | 特定 Teleporter Boss ~15% 替代绿装；部分为净化池等特殊区域 |\n")
    parts.append("| 蓝 | Lunar 月球 | **不进**普通箱；月球舱 / 时隙集市，消耗月球币 |\n")
    parts.append("| 橙 | Equipment 装备 | 独立装备槽，主动使用 + 冷却 |\n\n")

    parts.append("### 2.2 叠层类型\n\n")
    parts.append("同种被动可无限叠层；叠层公式见 [Item Stacking](https://riskofrain2.wiki.gg/wiki/Item_Stacking)。\n\n")
    parts.append("| 类型 | 说明 | 代表道具 |\n|------|------|----------|\n")
    parts.append("| Linear 线性 | 每层 +固定数值/百分比 | 士兵注射器、撬棍 |\n")
    parts.append("| Hyperbolic 双曲 | 多层收益递减，趋近上限 | 艰难时世、旧断头台 |\n")
    parts.append("| Exponential 指数 | 多层倍增 | 成型玻璃、异星头颅 |\n")
    parts.append("| Reciprocal 倒数 | 多层收益递减（另一公式） | H3AD-5T v2 |\n\n")

    parts.append("### 2.3 被动 vs 装备\n\n")
    parts.append("- **被动**：显示在顶栏；种类与层数无硬上限；可用 3D 打印机消耗换指定道具。\n")
    parts.append("- **装备**：单槽（MUL-T 除外）；按交互键主动释放；Fuel Cell 等可增充能/减 CD。\n\n")

    parts.append("### 2.4 Loadout（Skills 2.0）\n\n")
    parts.append("选角界面 **Loadout** 可切换四技能槽（Primary / Secondary / Utility / Special）的**替代技能**；替代技能通过角色挑战解锁。\n\n")

    parts.append("### 2.5 与本项目差异\n\n")
    parts.append("- RoR2 为单人/合作 **动作 Roguelike**，实时移动与射击；本项目为 **PvE 自走棋**，战斗全自动。\n")
    parts.append("- RoR2 道具为 run 内拾取叠层；本项目构筑来自商店牌库、增益卡与单位内建技能（见 [SHOP_SYSTEM.md](../SHOP_SYSTEM.md)）。\n")

    tier_titles = {
        "Common": "3.1 普通（白）25",
        "Uncommon": "3.2 罕见（绿）26",
        "Legendary": "3.3 传奇（红）22",
        "Boss": "3.4 Boss（黄）13",
        "Lunar": "3.5 月球（蓝）14",
    }
    parts.append("\n\n## 3. 被动道具（100）\n\n")
    parts.append("> Wiki「Base Game Item Counts」标 **102**（25+26+22+15+14）；本表按可核对条目收录 **100** 条（Boss 黄装 13 条；与 Wiki 15 黄装统计口径差 2 条 quest/区域键）。\n\n")
    for tier in ("Common", "Uncommon", "Legendary", "Boss", "Lunar"):
        parts.append(f"\n### {tier_titles[tier]}\n\n")
        rows = []
        for name in sorted(BASE_PASSIVE[tier], key=lambda n: n.lower()):
            desc, stack = all_items[tier][name]
            stack_clean = stack.replace("None", "").strip() or "—"
            rows.append([name, cn(name), effect_summary(name, desc), stack_clean])
        rows.sort(key=lambda r: r[0].lower())
        parts.append(md_table(["英文名", "中文名", "效果摘要", "叠层"], rows))

    parts.append("\n\n## 4. 装备（32）\n\n")
    parts.append("### 4.1 主动装备（22）\n\n")
    rows = []
    for name in sorted(BASE_EQUIP_STD, key=str.lower):
        desc, cd = all_eq["std"][name]
        rows.append([name, cn(name), effect_summary(name, desc), cd])
    parts.append(md_table(["英文名", "中文名", "效果摘要", "冷却"], rows))

    parts.append("\n\n### 4.2 月球装备（4）\n\n")
    rows = []
    for name in sorted(BASE_EQUIP_LUNAR, key=str.lower):
        desc, cd = all_eq["lunar"][name]
        rows.append([name, cn(name), effect_summary(name, desc), cd])
    parts.append(md_table(["英文名", "中文名", "效果摘要", "冷却"], rows))

    parts.append("\n\n### 4.3 精英装备（6）\n\n")
    parts.append("> 精英装备主要为被动「aspect」变身；由对应精英怪极低概率掉落。\n\n")
    rows = []
    for name in sorted(BASE_EQUIP_ELITE, key=str.lower):
        desc, cd = all_eq["elite"][name]
        rows.append([name, cn(name), effect_summary(name, desc), cd])
    parts.append(md_table(["英文名", "中文名", "效果摘要", "备注"], rows))

    parts.append("\n\n## 5. 幸存者技能（10）\n\n")
    parts.append("基础版可玩：**Commando、Huntress、Bandit、MUL-T、Engineer、Artificer、Mercenary、Rex、Loader、Acrid**。\n\n")
    for s in SURVIVORS:
        parts.append(f"\n\n#### {s['id']} {s['cn']}\n\n")
        parts.append(f"- **解锁**：{s['unlock']}\n")
        parts.append(f"- **基础属性**：{s['stats']}\n\n")
        parts.append(md_table(["槽位", "技能", "解锁", "效果摘要"], s["skills"]))

    parts.append("\n\n#### Heretic 异端者（隐藏）\n\n")
    parts.append("非商店解锁：收集异端系列月球道具后，本 run 内替换当前幸存者。高 HP/高伤/负回血，技能含 Hungering Gaze、Shadowfade、Slicing Maelstrom、Ruin。**本文不展开异端配装。**\n")

    parts.append("\n\n## 6. 设计模式摘要（策划向）\n\n")
    patterns = [
        ("叠层经济", "白装数量堆线性收益（注射器、撬棍），红装/月球提供质变；构筑在「广度 vs 尖峰」间取舍。"),
        ("OnHit 触发链", "AtG 导弹、尤克里里、粘性炸弹等由攻击触发；高 Proc 系数技能更易联动。"),
        ("OnKill 正反馈", "怪物之牙、汽油、仪式匕首等击杀链；类比 `OnKill` / `OnFriendDeath` 联动技能。"),
        ("月球双刃剑", "成型玻璃（+100% 伤 / -50% 血）、溺水者姿态（强装备 + 强制自动）——强效果必带明确代价。"),
        ("Boss 绑定掉落", "黄装与 Teleporter Boss 绑定（如泰坦节瘤 ↔ 石巨人）；可类比 milestone / 关底专属奖励。"),
        ("Loadout 流派", "同角色多技能变体（佣兵冲刺 vs 风刃）对应不同 playstyle；类比单位技能分支或合成换技能。"),
        ("团队增益", "忙碌真菌、战旗、Lepton Daisy 等范围治疗/ buff；类比 `ALL_ALLIES` 目标选择器。"),
        ("装备 vs 被动", "主动装备提供 burst（皇家电容器），被动提供持续修饰；类比战斗内主动技能 vs 永久增益卡。"),
    ]
    parts.append(md_table(["模式", "说明"], [[a, b] for a, b in patterns]))

    parts.append("\n\n## 7. 外部链接\n\n")
    for label, url in [
        ("Items", "https://riskofrain2.wiki.gg/wiki/Items"),
        ("Item Stacking", "https://riskofrain2.wiki.gg/wiki/Item_Stacking"),
        ("Survivors", "https://riskofrain2.wiki.gg/wiki/Survivors"),
        ("Skills/Data", "https://riskofrain2.wiki.gg/wiki/Module:Skills/Data"),
        ("Commando", "https://riskofrain2.wiki.gg/wiki/Commando"),
    ]:
        parts.append(f"- [{label}]({url})\n")

    return "".join(parts)


def main() -> None:
    content = build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(content, encoding="utf-8")
    print(f"Wrote {OUT} ({len(content.splitlines())} lines)")


if __name__ == "__main__":
    main()

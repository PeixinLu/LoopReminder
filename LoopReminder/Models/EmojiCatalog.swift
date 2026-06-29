import Foundation

struct EmojiCatalogItem: Identifiable, Equatable {
    var id: String { symbol }
    let symbol: String
    let unicodeName: String
    let group: EmojiCatalogGroup
    let keywords: [String]

    func matches(_ query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }

        if symbol.contains(normalized) { return true }
        if unicodeName.lowercased().contains(normalized) { return true }
        if group.title.lowercased().contains(normalized) { return true }
        return keywords.contains { $0.lowercased().contains(normalized) }
    }
}

struct EmojiCatalogSection: Identifiable, Equatable {
    var id: EmojiCatalogGroup { group }
    let group: EmojiCatalogGroup
    let items: [EmojiCatalogItem]
}

enum EmojiCatalogGroup: String, CaseIterable, Identifiable {
    case recommended
    case people
    case health
    case work
    case life
    case activity
    case nature
    case food
    case travel
    case objects
    case symbols

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: return "推荐"
        case .people: return "表情"
        case .health: return "健康"
        case .work: return "工作"
        case .life: return "生活"
        case .activity: return "活动"
        case .nature: return "自然"
        case .food: return "饮食"
        case .travel: return "出行"
        case .objects: return "物品"
        case .symbols: return "符号"
        }
    }
}

enum EmojiCatalog {
    static func search(_ query: String, in group: EmojiCatalogGroup? = nil) -> [EmojiCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            if let group, item.group != group {
                return false
            }
            return item.matches(trimmed)
        }
    }

    static func items(in group: EmojiCatalogGroup) -> [EmojiCatalogItem] {
        items.filter { $0.group == group }
    }

    static func sections() -> [EmojiCatalogSection] {
        EmojiCatalogGroup.allCases.map { group in
            EmojiCatalogSection(group: group, items: items(in: group))
        }
    }

    static let items: [EmojiCatalogItem] = [
        item("🔔", "bell", .recommended, ["提醒", "通知", "闹钟", "铃声"]),
        item("⏰", "alarm clock", .recommended, ["闹钟", "定时", "提醒"]),
        item("⏱️", "stopwatch", .recommended, ["计时", "秒表", "番茄钟"]),
        item("⌛️", "hourglass done", .recommended, ["时间", "等待", "计时"]),
        item("💧", "droplet", .recommended, ["喝水", "饮水", "补水", "水"]),
        item("☕️", "hot beverage", .recommended, ["咖啡", "休息", "饮品"]),
        item("💊", "pill", .recommended, ["吃药", "药", "健康"]),
        item("🍽️", "fork and knife with plate", .recommended, ["吃饭", "用餐", "饮食"]),
        item("🧘", "person in lotus position", .recommended, ["冥想", "放松", "休息"]),
        item("🏃", "person running", .recommended, ["跑步", "运动", "锻炼"]),
        item("👀", "eyes", .recommended, ["眼睛", "护眼", "休息"]),
        item("🛌", "person in bed", .recommended, ["睡觉", "休息", "睡眠"]),
        item("😀", "grinning face", .people, ["开心", "笑脸"]),
        item("😃", "grinning face with big eyes", .people, ["开心", "笑脸"]),
        item("😄", "grinning face with smiling eyes", .people, ["开心", "大笑"]),
        item("😁", "beaming face with smiling eyes", .people, ["开心", "笑"]),
        item("😊", "smiling face with smiling eyes", .people, ["开心", "微笑"]),
        item("🙂", "slightly smiling face", .people, ["微笑", "开心"]),
        item("😌", "relieved face", .people, ["放松", "安心"]),
        item("😍", "smiling face with heart-eyes", .people, ["喜欢", "开心"]),
        item("🥰", "smiling face with hearts", .people, ["喜欢", "开心"]),
        item("🤩", "star-struck", .people, ["兴奋", "喜欢"]),
        item("😎", "smiling face with sunglasses", .people, ["酷", "自信"]),
        item("🥳", "partying face", .people, ["庆祝", "完成"]),
        item("😴", "sleeping face", .people, ["睡觉", "困", "休息"]),
        item("😪", "sleepy face", .people, ["困", "睡觉"]),
        item("😮‍💨", "face exhaling", .people, ["呼气", "放松", "休息"]),
        item("🤔", "thinking face", .people, ["思考", "想"]),
        item("🫡", "saluting face", .people, ["收到", "执行"]),
        item("👏", "clapping hands", .people, ["鼓掌", "完成"]),
        item("👍", "thumbs up", .people, ["好", "确认", "完成"]),
        item("👌", "OK hand", .people, ["好的", "确认"]),
        item("🙌", "raising hands", .people, ["完成", "庆祝"]),
        item("🙏", "folded hands", .people, ["感谢", "祈祷"]),
        item("💪", "flexed biceps", .health, ["力量", "运动", "坚持"]),
        item("🫀", "anatomical heart", .health, ["心脏", "健康"]),
        item("🫁", "lungs", .health, ["呼吸", "健康"]),
        item("🦷", "tooth", .health, ["牙齿", "刷牙"]),
        item("🪥", "toothbrush", .health, ["刷牙", "牙齿", "清洁"]),
        item("🧠", "brain", .health, ["大脑", "专注"]),
        item("🩺", "stethoscope", .health, ["检查", "医生"]),
        item("🌡️", "thermometer", .health, ["体温", "健康"]),
        item("🩹", "adhesive bandage", .health, ["伤口", "护理"]),
        item("🩸", "drop of blood", .health, ["血液", "检查"]),
        item("💉", "syringe", .health, ["注射", "疫苗", "健康"]),
        item("🧼", "soap", .health, ["洗手", "清洁"]),
        item("🚰", "potable water", .health, ["喝水", "饮水"]),
        item("🚶", "person walking", .health, ["散步", "活动"]),
        item("🧎", "person kneeling", .health, ["拉伸", "活动"]),
        item("💻", "laptop", .work, ["电脑", "工作"]),
        item("🖥️", "desktop computer", .work, ["桌面", "电脑"]),
        item("⌨️", "keyboard", .work, ["键盘", "工作"]),
        item("🖱️", "computer mouse", .work, ["鼠标", "工作"]),
        item("📧", "e-mail", .work, ["邮件", "邮箱"]),
        item("📞", "telephone receiver", .work, ["电话", "通话"]),
        item("💬", "speech balloon", .work, ["消息", "沟通"]),
        item("📣", "megaphone", .work, ["通知", "公告"]),
        item("📅", "calendar", .work, ["日历", "会议", "安排"]),
        item("📆", "tear-off calendar", .work, ["日历", "日期", "安排"]),
        item("📝", "memo", .work, ["笔记", "记录", "待办"]),
        item("📋", "clipboard", .work, ["清单", "待办"]),
        item("📊", "bar chart", .work, ["统计", "数据"]),
        item("📁", "file folder", .work, ["文件", "资料"]),
        item("✅", "check mark button", .work, ["完成", "确认", "打卡"]),
        item("📌", "pushpin", .work, ["固定", "重点"]),
        item("🏠", "house", .life, ["家", "生活"]),
        item("🛏️", "bed", .life, ["睡觉", "休息"]),
        item("🚿", "shower", .life, ["洗澡", "清洁"]),
        item("🧹", "broom", .life, ["打扫", "清洁"]),
        item("🧺", "basket", .life, ["洗衣", "家务"]),
        item("🛒", "shopping cart", .life, ["购物", "买菜"]),
        item("🧾", "receipt", .life, ["账单", "收据"]),
        item("💰", "money bag", .life, ["记账", "钱"]),
        item("💡", "light bulb", .life, ["想法", "灵感"]),
        item("🎵", "musical note", .life, ["音乐", "放松"]),
        item("🎧", "headphone", .life, ["音乐", "听歌"]),
        item("📖", "open book", .life, ["阅读", "学习"]),
        item("🎮", "video game", .life, ["游戏", "娱乐"]),
        item("🧴", "lotion bottle", .life, ["护肤", "洗手"]),
        item("⚽️", "soccer ball", .activity, ["足球", "运动"]),
        item("🏀", "basketball", .activity, ["篮球", "运动"]),
        item("🏈", "american football", .activity, ["橄榄球", "运动"]),
        item("🎾", "tennis", .activity, ["网球", "运动"]),
        item("🏓", "ping pong", .activity, ["乒乓球", "运动"]),
        item("🏸", "badminton", .activity, ["羽毛球", "运动"]),
        item("🏋️", "person lifting weights", .activity, ["健身", "力量"]),
        item("🚴", "person biking", .activity, ["骑车", "运动"]),
        item("🏊", "person swimming", .activity, ["游泳", "运动"]),
        item("🧗", "person climbing", .activity, ["攀岩", "运动"]),
        item("🤸", "person cartwheeling", .activity, ["体操", "运动"]),
        item("🧩", "puzzle piece", .activity, ["拼图", "思考"]),
        item("🎯", "bullseye", .activity, ["目标", "专注"]),
        item("🌱", "seedling", .nature, ["植物", "成长"]),
        item("🌿", "herb", .nature, ["植物", "自然"]),
        item("🌳", "deciduous tree", .nature, ["树", "自然"]),
        item("🌞", "sun with face", .nature, ["太阳", "早晨"]),
        item("☀️", "sun", .nature, ["太阳", "晴天"]),
        item("🌤️", "sun behind small cloud", .nature, ["天气", "晴天"]),
        item("🌧️", "cloud with rain", .nature, ["下雨", "天气"]),
        item("🌙", "crescent moon", .nature, ["月亮", "晚上"]),
        item("⭐️", "star", .nature, ["星星", "重要"]),
        item("✨", "sparkles", .nature, ["闪光", "灵感"]),
        item("🔥", "fire", .nature, ["热", "能量"]),
        item("🌈", "rainbow", .nature, ["彩虹", "天气"]),
        item("🍎", "red apple", .food, ["苹果", "水果"]),
        item("🍌", "banana", .food, ["香蕉", "水果"]),
        item("🍊", "tangerine", .food, ["橘子", "水果"]),
        item("🍓", "strawberry", .food, ["草莓", "水果"]),
        item("🥑", "avocado", .food, ["牛油果", "健康饮食"]),
        item("🥗", "green salad", .food, ["沙拉", "健康饮食"]),
        item("🍚", "cooked rice", .food, ["米饭", "吃饭"]),
        item("🍜", "steaming bowl", .food, ["面", "吃饭"]),
        item("🥪", "sandwich", .food, ["三明治", "吃饭"]),
        item("🥚", "egg", .food, ["鸡蛋", "早餐"]),
        item("🥛", "glass of milk", .food, ["牛奶", "饮品"]),
        item("🫖", "teapot", .food, ["茶", "饮品"]),
        item("🧃", "beverage box", .food, ["饮料", "饮品"]),
        item("🚌", "bus", .travel, ["公交", "通勤"]),
        item("🚇", "metro", .travel, ["地铁", "通勤"]),
        item("🚗", "automobile", .travel, ["开车", "出行"]),
        item("🚕", "taxi", .travel, ["出租车", "出行"]),
        item("🚲", "bicycle", .travel, ["自行车", "骑车"]),
        item("🛵", "motor scooter", .travel, ["电动车", "出行"]),
        item("🚆", "train", .travel, ["火车", "出行"]),
        item("✈️", "airplane", .travel, ["飞机", "旅行"]),
        item("🚪", "door", .travel, ["出门", "门"]),
        item("🧳", "luggage", .travel, ["行李", "旅行"]),
        item("🎒", "backpack", .objects, ["背包", "出门"]),
        item("🔑", "key", .objects, ["钥匙", "出门"]),
        item("📱", "mobile phone", .objects, ["手机", "电话"]),
        item("⌚️", "watch", .objects, ["手表", "时间"]),
        item("🔋", "battery", .objects, ["电量", "充电"]),
        item("🔌", "electric plug", .objects, ["插头", "充电"]),
        item("💳", "credit card", .objects, ["银行卡", "付款"]),
        item("🪪", "identification card", .objects, ["证件", "身份证"]),
        item("☂️", "umbrella", .objects, ["雨伞", "下雨"]),
        item("🕶️", "sunglasses", .objects, ["墨镜", "出门"]),
        item("🎁", "wrapped gift", .objects, ["礼物", "生日"]),
        item("🧯", "fire extinguisher", .objects, ["安全", "灭火器"]),
        item("⚠️", "warning", .symbols, ["警告", "注意"]),
        item("❗️", "exclamation mark", .symbols, ["重要", "提醒"]),
        item("❓", "question mark", .symbols, ["问题", "确认"]),
        item("💯", "hundred points", .symbols, ["满分", "完成"]),
        item("❤️", "red heart", .symbols, ["爱心", "喜欢"]),
        item("💙", "blue heart", .symbols, ["爱心", "喜欢"]),
        item("💚", "green heart", .symbols, ["爱心", "健康"]),
        item("🔒", "locked", .symbols, ["锁定", "安全"]),
        item("🔓", "unlocked", .symbols, ["解锁", "开放"]),
        item("♻️", "recycling symbol", .symbols, ["循环", "重复"]),
        item("🔁", "repeat button", .symbols, ["重复", "循环"]),
        item("🔄", "counterclockwise arrows button", .symbols, ["刷新", "循环"]),
        item("⏳", "hourglass not done", .symbols, ["等待", "时间"]),
        item("🚫", "prohibited", .symbols, ["禁止", "停止"])
    ]

    private static func item(_ symbol: String, _ unicodeName: String, _ group: EmojiCatalogGroup, _ keywords: [String]) -> EmojiCatalogItem {
        EmojiCatalogItem(symbol: symbol, unicodeName: unicodeName, group: group, keywords: keywords)
    }
}

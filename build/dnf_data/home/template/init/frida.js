//绝望之塔金币，门票修复，跳过每10层玩家，镶嵌，怪物攻城，时装潜能，勇士归来，战力前三站街

//本地时间戳
function get_timestamp()
{
    var date = new Date();
    date = new Date(date.setHours(date.getHours() + 0)); //转换到本地时间
    var year = date.getFullYear().toString();
    var month = (date.getMonth() + 1).toString();
    var day = date.getDate().toString();
    var hour = date.getHours().toString();
    var minute = date.getMinutes().toString();
    var second = date.getSeconds().toString();
    var ms = date.getMilliseconds().toString();
    return year + '-' + month + '-' + day + ' ' + hour + ':' + minute + ':' + second;
}

//linux创建文件夹
function api_mkdir(path)
{
    var opendir = new NativeFunction(Module.getExportByName(null, 'opendir'), 'int', ['pointer'], {"abi":"sysv"});
    var mkdir = new NativeFunction(Module.getExportByName(null, 'mkdir'), 'int', ['pointer', 'int'], {"abi":"sysv"});
    var path_ptr = Memory.allocUtf8String(path);
    if(opendir(path_ptr))
        return true;
    return mkdir(path_ptr, 0x1FF);
}

//服务器环境
var G_CEnvironment = new NativeFunction(ptr(0x080CC181), 'pointer', [], {"abi":"sysv"});
//获取当前服务器配置文件名
var CEnvironment_get_file_name = new NativeFunction(ptr(0x80DA39A), 'pointer', ['pointer'], {"abi":"sysv"});
//获取当前频道名
function api_CEnvironment_get_file_name()
{
    var filename = CEnvironment_get_file_name(G_CEnvironment());
    return filename.readUtf8String(-1);
}

//文件记录日志
var frida_log_dir_path = './frida_log/'
var f_log = null;
var log_day = null;
function log(msg)
{
    var date = new Date();
    date = new Date(date.setHours(date.getHours() + 0)); //转换到本地时间
    var year = date.getFullYear().toString();
    var month = (date.getMonth() + 1).toString();
    var day = date.getDate().toString();
    var hour = date.getHours().toString();
    var minute = date.getMinutes().toString();
    var second = date.getSeconds().toString();
    var ms = date.getMilliseconds().toString();
    //日志按日期记录
    if((f_log == null) || (log_day != day))
    {
        api_mkdir(frida_log_dir_path);
        f_log = new File(frida_log_dir_path + 'frida_' + api_CEnvironment_get_file_name() + '_' + year + '_' + month + '_' + day + '.log', 'a+');
        log_day = day;
    }
    //时间戳
    var timestamp = year + '-' + month + '-' + day + ' ' + hour + ':' + minute + ':' + second + '.' + ms;
    //控制台日志
    console.log('[' + timestamp + ']' + msg + '\n');
    //文件日志
    f_log.write('[' + timestamp + ']' + msg + '\n');
    //立即写日志到文件中
    f_log.flush();
}

//内存十六进制打印
function bin2hex(p, len)
{
    var hex = '';
    for(var i = 0; i < len; i++)
    {
        var s = p.add(i).readU8().toString(16);
        if(s.length == 1)
            s = '0' + s;
        hex += s;
        if (i != len - 1)
            hex += ' ';
    }
    return hex;
}

//设置角色属性改变脏标记(角色上线时把所有属性从数据库缓存到内存中, 只有设置了脏标记, 角色下线时才能正确存档到数据库, 否则变动的属性下线后可能会回档)
var CUserCharacInfo_enableSaveCharacStat = new NativeFunction(ptr(0x819A870), 'int', ['pointer'], {"abi":"sysv"});
//获取角色状态
var CUser_get_state = new NativeFunction(ptr(0x80DA38C), 'int', ['pointer'], { "abi": "sysv" });
//获取角色账号id
var CUser_get_acc_id = new NativeFunction(ptr(0x80DA36E), 'int', ['pointer'], { "abi": "sysv" });
//获取当前角色id
var CUserCharacInfo_getCurCharacNo = new NativeFunction(ptr(0x80CBC4E), 'int', ['pointer'], { "abi": "sysv" });
//获取角色等级
var CUserCharacInfo_get_charac_level = new NativeFunction(ptr(0x80DA2B8), 'int', ['pointer'], { "abi": "sysv" });
//获取角色名字
var CUserCharacInfo_getCurCharacName = new NativeFunction(ptr(0x8101028), 'pointer', ['pointer'], { "abi": "sysv" });
//获取角色当前等级升级所需经验
var CUserCharacInfo_get_level_up_exp = new NativeFunction(ptr(0x0864E3BA), 'int', ['pointer', 'int'], { "abi": "sysv" });
//获取角色背包
var CUserCharacInfo_getCurCharacInvenW = new NativeFunction(ptr(0x80DA28E), 'pointer', ['pointer'], { "abi": "sysv" });
//获取副本id
var CDungeon_get_index = new NativeFunction(ptr(0x080FDCF0), 'int', ['pointer'], { "abi": "sysv" });
//获取背包槽中的道具
var CInventory_GetInvenRef = new NativeFunction(ptr(0x84FC1DE), 'pointer', ['pointer', 'int', 'int'], { "abi": "sysv" });
//道具是否是装备
var Inven_Item_isEquipableItemType = new NativeFunction(ptr(0x08150812), 'int', ['pointer'], {"abi":"sysv"});
//获取装备品级
var CItem_get_rarity = new NativeFunction(ptr(0x080F12D6), 'int', ['pointer'], {"abi":"sysv"});
//获取装备可穿戴等级
var CItem_getUsableLevel = new NativeFunction(ptr(0x80F12EE), 'int', ['pointer'], {"abi":"sysv"});
//获取装备[item group name]
var CItem_getItemGroupName = new NativeFunction(ptr(0x80F1312), 'int', ['pointer'], {"abi":"sysv"});
//检查背包中道具是否为空
var Inven_Item_isEmpty = new NativeFunction(ptr(0x811ED66), 'int', ['pointer'], { "abi": "sysv" });
//获取背包中道具item_id
var Inven_Item_getKey = new NativeFunction(ptr(0x850D14E), 'int', ['pointer'], { "abi": "sysv" });
//获取道具附加信息
var Inven_Item_get_add_info = new NativeFunction(ptr(0x80F783A), 'int', ['pointer'], { "abi": "sysv" });
//获取时装插槽数据
var WongWork_CAvatarItemMgr_getJewelSocketData = new NativeFunction(ptr(0x82F98F8), 'pointer', ['pointer', 'int'], { "abi": "sysv" });
//获取GameWorld实例
var G_GameWorld = new NativeFunction(ptr(0x80DA3A7), 'pointer', [], { "abi": "sysv" });
//获取DataManager实例
var G_CDataManager = new NativeFunction(ptr(0x80CC19B), 'pointer', [], { "abi": "sysv" });
//获取时装管理器
var CInventory_GetAvatarItemMgrR = new NativeFunction(ptr(0x80DD576), 'pointer', ['pointer'], { "abi": "sysv" });
//获取装备pvf数据
var CDataManager_find_item = new NativeFunction(ptr(0x835FA32), 'pointer', ['pointer', 'int'], { "abi": "sysv" });
//从pvf中获取任务数据
var CDataManager_find_quest = new NativeFunction(ptr(0x835FDC6), 'pointer', ['pointer', 'int'], { "abi": "sysv" });
//获取消耗品类型
var CStackableItem_GetItemType = new NativeFunction(ptr(0x8514A84), 'int', ['pointer'], { "abi": "sysv" });
//获取徽章支持的镶嵌槽类型
var CStackableItem_getJewelTargetSocket = new NativeFunction(ptr(0x0822CA28), 'int', ['pointer'], { "abi": "sysv" });
//背包道具
var Inven_Item_Inven_Item = new NativeFunction(ptr(0x80CB854), 'pointer', ['pointer'], { "abi": "sysv" });
//获取角色点券余额
var CUser_GetCera = new NativeFunction(ptr(0x080FDF7A), 'int', ['pointer'], { "abi": "sysv" });
//获取玩家任务信息
var CUser_getCurCharacQuestW = new NativeFunction(ptr(0x814AA5E), 'pointer', ['pointer'], { "abi": "sysv" });
//获取系统时间
var CSystemTime_getCurSec = new NativeFunction(ptr(0x80CBC9E), 'int', ['pointer'], { "abi": "sysv" });
var GlobalData_s_systemTime_ = ptr(0x941F714);
//本次登录时间
var CUserCharacInfo_GetLoginTick = new NativeFunction(ptr(0x822F692),  'int', ['pointer'], {"abi":"sysv"});
//道具是否被锁
var CUser_CheckItemLock = new NativeFunction(ptr(0x8646942), 'int', ['pointer', 'int', 'int'], { "abi": "sysv" });
//道具是否为消耗品
var CItem_is_stackable = new NativeFunction(ptr(0x80F12FA), 'int', ['pointer'], { "abi": "sysv" });
//任务是否已完成
var WongWork_CQuestClear_isClearedQuest = new NativeFunction(ptr(0x808BAE0), 'int', ['pointer', 'int'], { "abi": "sysv" });
//根据账号查找已登录角色
var GameWorld_find_user_from_world_byaccid = new NativeFunction(ptr(0x86C4D40), 'pointer', ['pointer', 'int'], { "abi": "sysv" });
//任务相关操作(第二个参数为协议编号: 33=接受任务, 34=放弃任务, 35=任务完成条件已满足, 36=提交任务领取奖励)
var CUser_quest_action = new NativeFunction(ptr(0x0866DA8A), 'int', ['pointer', 'int', 'int', 'int', 'int'], { "abi": "sysv" });
//设置GM完成任务模式(无条件完成任务)
var CUser_setGmQuestFlag = new NativeFunction(ptr(0x822FC8E), 'int', ['pointer', 'int'], { "abi": "sysv" });
//删除背包槽中的道具
var Inven_Item_reset = new NativeFunction(ptr(0x080CB7D8), 'int', ['pointer'], { "abi": "sysv" });
//减少金币
var CInventory_use_money = new NativeFunction(ptr(0x84FF54C), 'int', ['pointer', 'int', 'int', 'int'], { "abi": "sysv" });
//背包中删除道具(背包指针, 背包类型, 槽, 数量, 删除原因, 记录删除日志)
var CInventory_delete_item = new NativeFunction(ptr(0x850400C), 'int', ['pointer', 'int', 'int', 'int', 'int', 'int'], { "abi": "sysv" });
//角色增加经验
var CUser_gain_exp_sp = new NativeFunction(ptr(0x866A3FE), 'int', ['pointer', 'int', 'pointer', 'pointer', 'int', 'int', 'int'], { "abi": "sysv" });
//时装镶嵌数据存盘
var DB_UpdateAvatarJewelSlot_makeRequest = new NativeFunction(ptr(0x843081C), 'pointer', ['int', 'int', 'pointer'], { "abi": "sysv" });
//发包给客户端
var CUser_Send = new NativeFunction(ptr(0x86485BA), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
//给角色发消息
var CUser_SendNotiPacketMessage = new NativeFunction(ptr(0x86886CE), 'int', ['pointer', 'pointer', 'int'], { "abi": "sysv" });
//将协议发给所有在线玩家(慎用! 广播类接口必须限制调用频率, 防止CC攻击)
//除非必须使用, 否则改用对象更加明确的CParty::send_to_party/GameWorld::send_to_area
var GameWorld_send_all = new NativeFunction(ptr(0x86C8C14), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
var GameWorld_send_all_with_state = new NativeFunction(ptr(0x86C9184), 'int', ['pointer', 'pointer', 'int'], { "abi": "sysv" });
//通知客户端道具更新(客户端指针, 通知方式[仅客户端=1, 世界广播=0, 小队=2, war room=3], itemSpace[装备=0, 时装=1], 道具所在的背包槽)
var CUser_SendUpdateItemList = new NativeFunction(ptr(0x867C65A), 'int', ['pointer', 'int', 'int', 'int'], { "abi": "sysv" });
//通知客户端更新已完成任务列表
var CUser_send_clear_quest_list = new NativeFunction(ptr(0x868B044), 'int', ['pointer'], { "abi": "sysv" });
//通知客户端更新角色任务列表
var UserQuest_get_quest_info = new NativeFunction(ptr(0x86ABBA8), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
//获取在线玩家数量
var GameWorld_get_UserCount_InWorld = new NativeFunction(ptr(0x86C4550), 'int', ['pointer'], { "abi": "sysv" });
//在线玩家列表(用于std::map遍历)
var gameworld_user_map_begin = new NativeFunction(ptr(0x80F78A6), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
var gameworld_user_map_end = new NativeFunction(ptr(0x80F78CC), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
var gameworld_user_map_not_equal = new NativeFunction(ptr(0x80F78F2), 'bool', ['pointer', 'pointer'], { "abi": "sysv" });
var gameworld_user_map_get = new NativeFunction(ptr(0x80F7944), 'pointer', ['pointer'], { "abi": "sysv" });
var gameworld_user_map_next = new NativeFunction(ptr(0x80F7906), 'pointer', ['pointer', 'pointer'], { "abi": "sysv" });
//发系统邮件(多道具)
var WongWork_CMailBoxHelper_ReqDBSendNewSystemMultiMail = new NativeFunction(ptr(0x8556B68), 'int', ['pointer', 'pointer', 'int', 'int', 'int', 'pointer', 'int', 'int', 'int', 'int'], { "abi": "sysv" });
var WongWork_CMailBoxHelper_MakeSystemMultiMailPostal = new NativeFunction(ptr(0x8556A14), 'int', ['pointer', 'pointer', 'int'], { "abi": "sysv" });
//发系统邮件(时装)(仅支持在线角色发信)
var WongWork_CMailBoxHelper_ReqDBSendNewAvatarMail = new NativeFunction(ptr(0x85561B0), 'pointer', ['pointer', 'int', 'int', 'int', 'int', 'int', 'int', 'pointer', 'int'], { "abi": "sysv" });
//vector相关操作
var std_vector_std_pair_int_int_vector = new NativeFunction(ptr(0x81349D6), 'pointer', ['pointer'], { "abi": "sysv" });
var std_vector_std_pair_int_int_clear = new NativeFunction(ptr(0x817A342), 'pointer', ['pointer'], { "abi": "sysv" });
var std_make_pair_int_int = new NativeFunction(ptr(0x81B8D41), 'pointer', ['pointer', 'pointer', 'pointer'], { "abi": "sysv" });
var std_vector_std_pair_int_int_push_back = new NativeFunction(ptr(0x80DD606), 'pointer', ['pointer', 'pointer'], { "abi": "sysv" });
//点券充值
var WongWork_IPG_CIPGHelper_IPGInput = new NativeFunction(ptr(0x80FFCA4), 'int', ['pointer', 'pointer', 'int', 'int', 'pointer', 'pointer', 'pointer', 'pointer', 'pointer', 'pointer'], { "abi": "sysv" });
//同步点券数据库
var WongWork_IPG_CIPGHelper_IPGQuery = new NativeFunction(ptr(0x8100790), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
//代币充值
var WongWork_IPG_CIPGHelper_IPGInputPoint = new NativeFunction(ptr(0x80FFFC0),  'int', ['pointer', 'pointer','int', 'int', 'pointer', 'pointer'], {"abi":"sysv"});
//从客户端封包中读取数据
var PacketBuf_get_byte = new NativeFunction(ptr(0x858CF22), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
var PacketBuf_get_short = new NativeFunction(ptr(0x858CFC0), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
var PacketBuf_get_int = new NativeFunction(ptr(0x858D27E), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
var PacketBuf_get_binary = new NativeFunction(ptr(0x858D3B2), 'int', ['pointer', 'pointer', 'int'], { "abi": "sysv" });
//服务器组包
var PacketGuard_PacketGuard = new NativeFunction(ptr(0x858DD4C), 'int', ['pointer'], { "abi": "sysv" });
var InterfacePacketBuf_put_header = new NativeFunction(ptr(0x80CB8FC), 'int', ['pointer', 'int', 'int'], { "abi": "sysv" });
var InterfacePacketBuf_put_byte = new NativeFunction(ptr(0x80CB920), 'int', ['pointer', 'uint8'], { "abi": "sysv" });
var InterfacePacketBuf_put_short = new NativeFunction(ptr(0x80D9EA4), 'int', ['pointer', 'uint16'], { "abi": "sysv" });
var InterfacePacketBuf_put_int = new NativeFunction(ptr(0x80CB93C), 'int', ['pointer', 'int'], { "abi": "sysv" });
var InterfacePacketBuf_put_binary = new NativeFunction(ptr(0x811DF08), 'int', ['pointer', 'pointer', 'int'], { "abi": "sysv" });
var InterfacePacketBuf_finalize = new NativeFunction(ptr(0x80CB958), 'int', ['pointer', 'int'], { "abi": "sysv" });
var Destroy_PacketGuard_PacketGuard = new NativeFunction(ptr(0x858DE80), 'int', ['pointer'], { "abi": "sysv" });
//linux读本地文件
var fopen = new NativeFunction(Module.getExportByName(null, 'fopen'), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
var fread = new NativeFunction(Module.getExportByName(null, 'fread'), 'int', ['pointer', 'int', 'int', 'int'], { "abi": "sysv" });
var fclose = new NativeFunction(Module.getExportByName(null, 'fclose'), 'int', ['int'], { "abi": "sysv" });
//MYSQL操作
//游戏中已打开的数据库索引(游戏数据库非线程安全 谨慎操作)
var TAIWAN_CAIN = 2;
var DBMgr_GetDBHandle = new NativeFunction(ptr(0x83F523E), 'pointer', ['pointer', 'int', 'int'], { "abi": "sysv" });
var MySQL_MySQL = new NativeFunction(ptr(0x83F3AC8), 'pointer', ['pointer'], { "abi": "sysv" });
var MySQL_init = new NativeFunction(ptr(0x83F3CE4), 'int', ['pointer'], { "abi": "sysv" });
var MySQL_open = new NativeFunction(ptr(0x83F4024), 'int', ['pointer', 'pointer', 'int', 'pointer', 'pointer', 'pointer'], { "abi": "sysv" });
var MySQL_close = new NativeFunction(ptr(0x83F3E74), 'int', ['pointer'], { "abi": "sysv" });
var MySQL_set_query_2 = new NativeFunction(ptr(0x83F41C0), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
var MySQL_set_query_3 = new NativeFunction(ptr(0x83F41C0), 'int', ['pointer', 'pointer', 'int'], { "abi": "sysv" });
var MySQL_set_query_4 = new NativeFunction(ptr(0x83F41C0), 'int', ['pointer', 'pointer', 'int', 'int'], { "abi": "sysv" });
var MySQL_set_query_5 = new NativeFunction(ptr(0x83F41C0), 'int', ['pointer', 'pointer', 'int', 'int', 'int'], { "abi": "sysv" });
var MySQL_set_query_6 = new NativeFunction(ptr(0x83F41C0), 'int', ['pointer', 'pointer', 'int', 'int', 'int', 'int'], { "abi": "sysv" });
var MySQL_exec = new NativeFunction(ptr(0x83F4326), 'int', ['pointer', 'int'], { "abi": "sysv" });
var MySQL_exec_query = new NativeFunction(ptr(0x083F5348), 'int', ['pointer'], { "abi": "sysv" });
var MySQL_get_n_rows = new NativeFunction(ptr(0x80E236C), 'int', ['pointer'], { "abi": "sysv" });
var MySQL_fetch = new NativeFunction(ptr(0x83F44BC), 'int', ['pointer'], { "abi": "sysv" });
var MySQL_get_int = new NativeFunction(ptr(0x811692C), 'int', ['pointer', 'int', 'pointer'], { "abi": "sysv" });
var MySQL_get_short = new NativeFunction(ptr(0x0814201C), 'int', ['pointer', 'int', 'pointer'], { "abi": "sysv" });
var MySQL_get_uint = new NativeFunction(ptr(0x80E22F2), 'int', ['pointer', 'int', 'pointer'], { "abi": "sysv" });
var MySQL_get_ulonglong = new NativeFunction(ptr(0x81754C8), 'int', ['pointer', 'int', 'pointer'], { "abi": "sysv" });
var MySQL_get_ushort = new NativeFunction(ptr(0x8116990), 'int', ['pointer'], { "abi": "sysv" });
var MySQL_get_float = new NativeFunction(ptr(0x844D6D0), 'int', ['pointer', 'int', 'pointer'], { "abi": "sysv" });
var MySQL_get_binary = new NativeFunction(ptr(0x812531A), 'int', ['pointer', 'int', 'pointer', 'int'], { "abi": "sysv" });
var MySQL_get_binary_length = new NativeFunction(ptr(0x81253DE), 'int', ['pointer', 'int'], { "abi": "sysv" });
var MySQL_get_str = new NativeFunction(ptr(0x80ECDEA), 'int', ['pointer', 'int', 'pointer', 'int'], { "abi": "sysv" });
var MySQL_blob_to_str = new NativeFunction(ptr(0x83F452A), 'pointer', ['pointer', 'int', 'pointer', 'int'], { "abi": "sysv" });
var compress_zip = new NativeFunction(ptr(0x86B201F), 'int', ['pointer', 'pointer', 'pointer', 'int'], { "abi": "sysv" });
var uncompress_zip = new NativeFunction(ptr(0x86B2102), 'int', ['pointer', 'pointer', 'pointer', 'int'], { "abi": "sysv" });
var CUserCharacInfo_get_charac_job = new NativeFunction(ptr(0x80FDF20), 'int', ['pointer'], { "abi": "sysv" });
var CUserCharacInfo_getCurCharacGrowType = new NativeFunction(ptr(0x815741C), 'int', ['pointer'], { "abi": "sysv" });
var CUserCharacInfo_get_charac_guildkey = new NativeFunction(ptr(0x822F46C), 'int', ['pointer'], { "abi": "sysv" });
var CUser_GetGuildName = new NativeFunction(ptr(0x869742A), 'pointer', ['pointer'], { "abi": "sysv" });
//线程安全锁
var Guard_Mutex_Guard = new NativeFunction(ptr(0x810544C), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
var Destroy_Guard_Mutex_Guard = new NativeFunction(ptr(0x8105468), 'int', ['pointer'], { "abi": "sysv" });
//服务器内置定时器队列
var G_TimerQueue = new NativeFunction(ptr(0x80F647C), 'pointer', [], { "abi": "sysv" });
//需要在dispatcher线程执行的任务队列(热加载后会被清空)
var timer_dispatcher_list = [];
var INVENTORY_TYPE_BODY = 0; //身上穿的装备
var INVENTORY_TYPE_ITEM = 1; //物品栏
var INVENTORY_TYPE_AVARTAR = 2; //时装栏
//已打开的数据库句柄
var mysql_taiwan_cain = null;
var mysql_taiwan_cain_2nd = null;
var mysql_taiwan_billing = null;
var mysql_frida = null;
//怪物攻城活动当前状态
const VILLAGEATTACK_STATE_P1 = 0; //一阶段
const VILLAGEATTACK_STATE_P2 = 1; //二阶段
const VILLAGEATTACK_STATE_P3 = 2; //三阶段
const VILLAGEATTACK_STATE_END = 3; //活动已结束

const TAU_CAPTAIN_MONSTER_ID = 50071; //牛头统帅id(P1阶段击杀该怪物可提升活动难度等级)
const GBL_POPE_MONSTER_ID = 262; //GBL教主教(P2/P3阶段城镇存在该怪物 持续减少PT点数)
const TAU_META_COW_MONSTER_ID = 17; //机械牛(P3阶段世界BOSS)

const EVENT_VILLAGEATTACK_START_HOUR = 12; //每日北京时间20点开启活动
const EVENT_VILLAGEATTACK_TARGET_SCORE = [100, 200, 300]; //各阶段目标PT
const EVENT_VILLAGEATTACK_TOTAL_TIME = 3600; //活动总时长(秒)

//怪物攻城活动数据
var villageAttackEventInfo =
{
    'state': VILLAGEATTACK_STATE_END, //活动当前状态
    'score': 0, //当前阶段频道内总PT
    'start_time': 0, //活动开始时间(UTC)
    'difficult': 0, //活动难度(0-4)
    'next_village_monster_id': 0, //下次刷新的攻城怪物id
    'last_killed_monster_id': 0, //上次击杀的攻城怪物id
    'p2_last_killed_monster_time': 0, //P2阶段上次击杀攻城怪物时间
    'p2_kill_combo': 0, //P2阶段连续击杀相同攻城怪物数量
    'gbl_cnt': 0, //城镇中存活的GBL主教数量
    'defend_success': 0, //怪物攻城活动防守成功
    'user_pt_info': {}, //角色个人pt数据
}

//获取角色所在队伍
const CUser_GetParty = new NativeFunction(ptr(0x0865514C), 'pointer', ['pointer'], { "abi": "sysv" });
//获取队伍中玩家
const CParty_get_user = new NativeFunction(ptr(0x08145764), 'pointer', ['pointer', 'int'], { "abi": "sysv" });
//获取角色扩展数据
const CUser_GetCharacExpandData = new NativeFunction(ptr(0x080DD584), 'pointer', ['pointer', 'int'], { "abi": "sysv" });
//绝望之塔层数
const TOD_Layer_TOD_Layer = new NativeFunction(ptr(0x085FE7B4), 'pointer', ['pointer', 'int'], { "abi": "sysv" });
//设置绝望之塔层数
const TOD_UserState_setEnterLayer = new NativeFunction(ptr(0x086438FC), 'pointer', ['pointer', 'pointer'], { "abi": "sysv" });
//获取角色当前持有金币数量
var CInventory_get_money = new NativeFunction(ptr(0x81347D6), 'int', ['pointer'], { "abi": "sysv" });
//通知客户端更新角色身上装备
const CUser_SendNotiPacket = new NativeFunction(ptr(0x0867BA5C), 'int', ['pointer', 'int', 'int', 'int'], { "abi": "sysv" });
//开启怪物攻城
const Inter_VillageAttackedStart_dispatch_sig = new NativeFunction(ptr(0x84DF47A), 'pointer', ['pointer', 'pointer', 'pointer'], { "abi": "sysv" });
//结束怪物攻城
const village_attacked_CVillageMonsterMgr_OnDestroyVillageMonster = new NativeFunction(ptr(0x086B43D4), 'pointer', ['pointer', 'int'], { "abi": "sysv" });
const GlobalData_s_villageMonsterMgr = ptr(0x941F77C);
const nullptr = Memory.alloc(4);
var Inven_Item = new NativeFunction(ptr(0x080CB854), 'void', ['pointer'], { "abi": "sysv" });
var GetItem_index = new NativeFunction(ptr(0x08110C48), 'int', ['pointer'], { "abi": "sysv" });
var GetCurCharacNo = new NativeFunction(ptr(0x80CBC4E), 'int', ['pointer'], { "abi": "sysv" });
var GetServerGroup = new NativeFunction(ptr(0x080CBC90), 'int', ['pointer'], { "abi": "sysv" });
var GetCurVAttackCount = new NativeFunction(ptr(0x084EC216), 'int', ['pointer'], { "abi": "sysv" });
var ReqDBSendNewSystemMail = new NativeFunction(ptr(0x085555E8), 'int', ['pointer', 'pointer', 'int', 'int', 'pointer', 'int', 'int', 'int', 'char', 'char'], { "abi": "sysv" });

//测试系统API
var strlen = new NativeFunction(ptr(0x0807E3B0), 'int', ['pointer'], { "abi": "sysv" }); //获取字符串长度
var global_config = {};

//获取随机数
function get_random_int(min, max)
{
    return Math.floor(Math.random() * (max - min)) + min;
}

//读取文件
function api_read_file(path, mode, len)
{
    var path_ptr = Memory.allocUtf8String(path);
    var mode_ptr = Memory.allocUtf8String(mode);
    var f = fopen(path_ptr, mode_ptr);
    if (f == 0)
        return null;
    var data = Memory.alloc(len);
    var fread_ret = fread(data, 1, len, f);
    fclose(f);
    //返回字符串
    if (mode == 'r')
        return data.readUtf8String(fread_ret);
    //返回二进制buff指针
    return data;
}

//加载本地配置文件(json格式)
function load_config(path)
{
    var data = api_read_file(path, 'r', 10 * 1024 * 1024);
    global_config = JSON.parse(data);
}

//获取系统UTC时间(秒)
function api_CSystemTime_getCurSec()
{
    return GlobalData_s_systemTime_.readInt();
}

//获取道具数据
function find_item(item_id)
{
    return CDataManager_find_item(G_CDataManager(), item_id);
}

//邮件函数封装
function CMailBoxHelperReqDBSendNewSystemMail(User, item_id, item_count)
{
    var retitem = find_item(item_id);
    if (retitem)
    {
        var Inven_ItemPr = Memory.alloc(100);
        Inven_Item(Inven_ItemPr); //清空道具
        var itemid = GetItem_index(retitem);
        var itemtype = retitem.add(8).readU8();
        Inven_ItemPr.writeU8(itemtype);
        Inven_ItemPr.add(2).writeInt(itemid);
        Inven_ItemPr.add(7).writeInt(item_count);
        // set_add_info(Inven_ItemPr, item_count);
        var GoldValue = 0;
        var TitlePr = Memory.allocUtf8String('居民代表');
        var TxtValue = '击杀怪物奖励：';
        var UserID = GetCurCharacNo(User);
        var TxtValuePr = Memory.allocUtf8String(TxtValue);
        var TxtValueLength = toString(TxtValue).length;
        var ServerGroup = GetServerGroup(User);
        var MailDate = 30;
        ReqDBSendNewSystemMail(TitlePr, Inven_ItemPr, GoldValue, UserID, TxtValuePr, TxtValueLength, MailDate, ServerGroup, 0, 0);
    }
}

//获取角色名字
function api_CUserCharacInfo_getCurCharacName(user)
{
    var p = CUserCharacInfo_getCurCharacName(user);
    if (p.isNull())
    {
        return '';
    }
    return p.readUtf8String(-1);
}

//点券充值 (禁止直接修改billing库所有表字段, 点券相关操作务必调用数据库存储过程!)
function api_recharge_cash_cera(user, amount)
{
    //充值
    WongWork_IPG_CIPGHelper_IPGInput(ptr(0x941F734).readPointer(), user, 5, amount, ptr(0x8C7FA20), ptr(0x8C7FA20),
        Memory.allocUtf8String('GM'), ptr(0), ptr(0), ptr(0));
    //通知客户端充值结果
    WongWork_IPG_CIPGHelper_IPGQuery(ptr(0x941F734).readPointer(), user);
}

//代币充值 (禁止直接修改billing库所有表字段, 点券相关操作务必调用数据库存储过程!)
function api_recharge_cash_cera_point(user, amount)
{
    //充值
    WongWork_IPG_CIPGHelper_IPGInputPoint(ptr(0x941F734).readPointer(), user, amount, 4, ptr(0), ptr(0));
    //通知客户端充值结果
    WongWork_IPG_CIPGHelper_IPGQuery(ptr(0x941F734).readPointer(), user);
}

//在线奖励
function enable_online_reward()
{
    //在线每5min发一次奖, 在线时间越长, 奖励越高
    //CUser::WorkPerFiveMin
    Interceptor.attach(ptr(0x8652F0C),
    {
        onEnter: function (args)
        {
            var user = args[0];
            //当前系统时间
            var cur_time = api_CSystemTime_getCurSec();
            //本次登录时间
            var login_tick = CUserCharacInfo_GetLoginTick(user);
            if(login_tick > 0)
            {
                //在线时长(分钟)
                var diff_time = Math.floor((cur_time - login_tick) / 60);
                //在线30min后开始计算
                if(diff_time < 30)
                    return;
                //在线奖励最多发送半天
                if(diff_time > 1*12*60)
                    return;
                //奖励: 每分钟0.1点券
                var REWARD_CASH_CERA_PER_MIN = 0.1;
                //计算奖励
                var reward_cash_cera = Math.floor(diff_time*REWARD_CASH_CERA_PER_MIN);
                //发点券
                api_recharge_cash_cera(user, reward_cash_cera);
                //发消息通知客户端奖励已发送
                api_CUser_SendNotiPacketMessage(user, '[' + get_timestamp() + '] 在线奖励已发送(当前阶段点券奖励:' + reward_cash_cera + ')', 6);
            }
        },
        onLeave: function (retval)
        {
        }
    });
}

//给角色发经验
function api_CUser_gain_exp_sp(user, exp)
{
    var a2 = Memory.alloc(4);
    var a3 = Memory.alloc(4);
    CUser_gain_exp_sp(user, exp, a2, a3, 0, 0, 0);
}

//获取在线玩家列表表头
function api_gameworld_user_map_begin()
{
    var begin = Memory.alloc(4);
    gameworld_user_map_begin(begin, G_GameWorld().add(308));
    return begin;
}

//获取在线玩家列表表尾
function api_gameworld_user_map_end()
{
    var end = Memory.alloc(4);
    gameworld_user_map_end(end, G_GameWorld().add(308));
    return end;
}

//获取当前正在遍历的玩家
function api_gameworld_user_map_get(it)
{
    return gameworld_user_map_get(it).add(4).readPointer();
}

//遍历在线玩家列表
function api_gameworld_user_map_next(it)
{
    var next = Memory.alloc(4);
    gameworld_user_map_next(next, it);
    return next;
}

//对全服在线玩家执行回调函数
function api_gameworld_foreach(f, args)
{
    //遍历在线玩家列表
    var it = api_gameworld_user_map_begin();
    var end = api_gameworld_user_map_end();

    //判断在线玩家列表遍历是否已结束
    while (gameworld_user_map_not_equal(it, end))
    {
        //当前被遍历到的玩家
        var user = api_gameworld_user_map_get(it);

        //只处理已登录角色
        if (CUser_get_state(user) >= 3)
        {
            //执行回调函数
            f(user, args);
        }
        //继续遍历下一个玩家
        api_gameworld_user_map_next(it);
    }
}

//设置角色当前绝望之塔层数
function api_TOD_UserState_setEnterLayer(user, layer)
{
    var tod_layer = Memory.alloc(100);
    TOD_Layer_TOD_Layer(tod_layer, layer);
    var expand_data = CUser_GetCharacExpandData(user, 13);
    TOD_UserState_setEnterLayer(expand_data, tod_layer);
}

//根据角色id查询角色名
function api_get_charac_name_by_charac_no(charac_no)
{
    //从数据库中查询角色名
    if (api_MySQL_exec(mysql_taiwan_cain, "select charac_name from charac_info where charac_no=" + charac_no + ";"))
    {
        if (MySQL_get_n_rows(mysql_taiwan_cain) == 1)
        {
            if (MySQL_fetch(mysql_taiwan_cain))
            {
                var charac_name = api_MySQL_get_str(mysql_taiwan_cain, 0);
                return charac_name;
            }
        }
    }
    return charac_no.toString();
}

//发系统邮件(多道具)(角色charac_no, 邮件标题, 邮件正文, 金币数量, 道具列表)
function api_WongWork_CMailBoxHelper_ReqDBSendNewSystemMultiMail(target_charac_no, title, text, gold, item_list)
{
    //添加道具附件
    var vector = Memory.alloc(100);
    std_vector_std_pair_int_int_vector(vector);
    std_vector_std_pair_int_int_clear(vector);

    for (var i = 0; i < item_list.length; ++i)
    {
        var item_id = Memory.alloc(4); //道具id
        var item_cnt = Memory.alloc(4); //道具数量
        item_id.writeInt(item_list[i][0]);
        item_cnt.writeInt(item_list[i][1]);
        var pair = Memory.alloc(100);
        std_make_pair_int_int(pair, item_id, item_cnt);
        std_vector_std_pair_int_int_push_back(vector, pair);
    }
    //邮件支持10个道具附件格子
    var addition_slots = Memory.alloc(1000);
    for (var i = 0; i < 10; ++i)
    {
        Inven_Item_Inven_Item(addition_slots.add(i * 61));
    }
    WongWork_CMailBoxHelper_MakeSystemMultiMailPostal(vector, addition_slots, 10);
    var title_ptr = Memory.allocUtf8String(title); //邮件标题
    var text_ptr = Memory.allocUtf8String(text); //邮件正文
    var text_len = strlen(text_ptr); //邮件正文长度
    //发邮件给角色
    WongWork_CMailBoxHelper_ReqDBSendNewSystemMultiMail(title_ptr, addition_slots, item_list.length, gold, target_charac_no, text_ptr, text_len, 0, 99, 1);
}

//全服在线玩家发信
function api_gameworld_send_mail(title, text, gold, item_list)
{
    //遍历在线玩家列表
    var it = api_gameworld_user_map_begin();
    var end = api_gameworld_user_map_end();

    //判断在线玩家列表遍历是否已结束
    while (gameworld_user_map_not_equal(it, end))
    {
        //当前被遍历到的玩家
        var user = api_gameworld_user_map_get(it);

        //只处理已登录角色
        if (CUser_get_state(user) >= 3)
        {
            //角色uid
            var charac_no = CUserCharacInfo_getCurCharacNo(user);
            //给角色发信
            api_WongWork_CMailBoxHelper_ReqDBSendNewSystemMultiMail(charac_no, title, text, gold, item_list);
        }
        //继续遍历下一个玩家
        api_gameworld_user_map_next(it);
    }
}

//服务器组包
function api_PacketGuard_PacketGuard()
{
    var packet_guard = Memory.alloc(0x20000);
    PacketGuard_PacketGuard(packet_guard);
    return packet_guard;
}

//从客户端封包中读取数据(失败会抛异常, 调用方必须做异常处理)
function api_PacketBuf_get_byte(packet_buf)
{
    var data = Memory.alloc(1);
    if (PacketBuf_get_byte(packet_buf, data))
    {
        return data.readU8();
    }
    throw new Error('PacketBuf_get_byte Fail!');
}

function api_CUser_GetGuildName(user) {
    var p = CUser_GetGuildName(user);
    if (p.isNull()) {
        return '';
    }
    return p.readUtf8String(-1);
}

function api_PacketBuf_get_short(packet_buf)
{
    var data = Memory.alloc(2);

    if (PacketBuf_get_short(packet_buf, data))
    {
        return data.readShort();
    }
    throw new Error('PacketBuf_get_short Fail!');
}

function api_PacketBuf_get_int(packet_buf)
{
    var data = Memory.alloc(4);

    if (PacketBuf_get_int(packet_buf, data))
    {
        return data.readInt();
    }
    throw new Error('PacketBuf_get_int Fail!');
}

function api_PacketBuf_get_binary(packet_buf, len)
{
    var data = Memory.alloc(len);

    if (PacketBuf_get_binary(packet_buf, data, len))
    {
        return data.readByteArray(len);
    }
    throw new Error('PacketBuf_get_binary Fail!');
}

//获取原始封包数据
function api_PacketBuf_get_buf(packet_buf)
{
    return packet_buf.add(20).readPointer().add(13);
}

//给角色发消息
function api_CUser_SendNotiPacketMessage(user, msg, msg_type)
{
    var p = Memory.allocUtf8String(msg);
    CUser_SendNotiPacketMessage(user, p, msg_type);
    return;
}

//发送字符串给客户端
function api_InterfacePacketBuf_put_string(packet_guard, s)
{
    var p = Memory.allocUtf8String(s);
    var len = strlen(p);
    InterfacePacketBuf_put_int(packet_guard, len);
    InterfacePacketBuf_put_binary(packet_guard, p, len);
    return;
}

//世界广播(频道内公告)
function api_GameWorld_SendNotiPacketMessage(msg, msg_type)
{
    var packet_guard = api_PacketGuard_PacketGuard();
    InterfacePacketBuf_put_header(packet_guard, 0, 12);
    InterfacePacketBuf_put_byte(packet_guard, msg_type);
    InterfacePacketBuf_put_short(packet_guard, 0);
    InterfacePacketBuf_put_byte(packet_guard, 0);
    api_InterfacePacketBuf_put_string(packet_guard, msg);
    InterfacePacketBuf_finalize(packet_guard, 1);
    GameWorld_send_all_with_state(G_GameWorld(), packet_guard, 3); //只给state >= 3 的玩家发公告
    Destroy_PacketGuard_PacketGuard(packet_guard);
}

//打开数据库
function api_MYSQL_open(db_name, db_ip, db_port, db_account, db_password)
{
    //mysql初始化
    var mysql = Memory.alloc(0x80000);
    MySQL_MySQL(mysql);
    MySQL_init(mysql);
    //连接数据库
    var db_ip_ptr = Memory.allocUtf8String(db_ip);
    var db_port = db_port;
    var db_name_ptr = Memory.allocUtf8String(db_name);
    var db_account_ptr = Memory.allocUtf8String(db_account);
    var db_password_ptr = Memory.allocUtf8String(db_password);
    var ret = MySQL_open(mysql, db_ip_ptr, db_port, db_name_ptr, db_account_ptr, db_password_ptr);
    if (ret)
    {
        //log('Connect MYSQL DB <' + db_name + '> SUCCESS!');
        return mysql;
    }
    return null;
}

//mysql查询(返回mysql句柄)(注意线程安全)
function api_MySQL_exec(mysql, sql)
{
    var sql_ptr = Memory.allocUtf8String(sql);
    MySQL_set_query_2(mysql, sql_ptr);
    return MySQL_exec(mysql, 1);
}

//查询sql结果
//使用前务必保证api_MySQL_exec返回0
//并且MySQL_get_n_rows与预期一致
function api_MySQL_get_int(mysql, field_index)
{
    var v = Memory.alloc(4);
    if (1 == MySQL_get_int(mysql, field_index, v))
        return v.readInt();
    //log('api_MySQL_get_int Fail!!!');
    return null;
}

function api_MySQL_get_uint(mysql, field_index)
{
    var v = Memory.alloc(4);
    if (1 == MySQL_get_uint(mysql, field_index, v))
        return v.readUInt();
    //log('api_MySQL_get_uint Fail!!!');
    return null;
}

function api_MySQL_get_short(mysql, field_index)
{
    var v = Memory.alloc(4);
    if (1 == MySQL_get_short(mysql, field_index, v))
        return v.readShort();
    //log('MySQL_get_short Fail!!!');
    return null;
}

function api_MySQL_get_float(mysql, field_index)
{
    var v = Memory.alloc(4);
    if (1 == MySQL_get_float(mysql, field_index, v))
        return v.readFloat();
    //log('MySQL_get_float Fail!!!');
    return null;
}

function api_MySQL_get_str(mysql, field_index)
{
    var binary_length = MySQL_get_binary_length(mysql, field_index);
    if (binary_length > 0)
    {
        var v = Memory.alloc(binary_length);
        if (1 == MySQL_get_binary(mysql, field_index, v, binary_length))
            return v.readUtf8String(binary_length);
    }
    //log('MySQL_get_str Fail!!!');
    return null;
}

function api_MySQL_get_binary(mysql, field_index)
{
    var binary_length = MySQL_get_binary_length(mysql, field_index);
    if (binary_length > 0)
    {
        var v = Memory.alloc(binary_length);
        if (1 == MySQL_get_binary(mysql, field_index, v, binary_length))
            return v.readByteArray(binary_length);
    }
    //log('api_MySQL_get_binary Fail!!!');
    return null;
}

//初始化数据库(打开数据库/建库建表/数据库字段扩展)
function init_db()
{
    //配置文件
    var config = global_config['db_config'];
    //打开数据库连接
    if (mysql_taiwan_cain == null)
    {
        mysql_taiwan_cain = api_MYSQL_open('taiwan_cain', '127.0.0.1', 3306, config['account'], config['password']);
    }
    if (mysql_taiwan_cain_2nd == null)
    {
        mysql_taiwan_cain_2nd = api_MYSQL_open('taiwan_cain_2nd', '127.0.0.1', 3306, config['account'], config['password']);
    }
    if (mysql_taiwan_billing == null)
    {
        mysql_taiwan_billing = api_MYSQL_open('taiwan_billing', '127.0.0.1', 3306, config['account'], config['password']);
    }
    //建库frida
    api_MySQL_exec(mysql_taiwan_cain, 'create database if not exists frida default charset utf8;');
    if (mysql_frida == null)
    {
        mysql_frida = api_MYSQL_open('frida', '127.0.0.1', 3306, config['account'], config['password']);
    }
    //建表frida.game_event
    api_MySQL_exec(mysql_frida, 'CREATE TABLE game_event (\
        event_id varchar(30) NOT NULL, event_info mediumtext NULL,\
        PRIMARY KEY  (event_id)\
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;');
    //载入活动数据
    event_villageattack_load_from_db();
}

//关闭数据库（卸载插件前调用）
function uninit_db()
{
    //活动数据存档
    event_villageattack_save_to_db();
    //关闭数据库连接
    if (mysql_taiwan_cain)
    {
        MySQL_close(mysql_taiwan_cain);
        mysql_taiwan_cain = null;
    }
    if (mysql_taiwan_cain_2nd)
    {
        MySQL_close(mysql_taiwan_cain_2nd);
        mysql_taiwan_cain_2nd = null;
    }
    if (mysql_taiwan_billing)
    {
        MySQL_close(mysql_taiwan_billing);
        mysql_taiwan_billing = null;
    }
    if (mysql_frida)
    {
        MySQL_close(mysql_frida);
        mysql_frida = null;
    }
}

//怪物攻城活动数据存档
function event_villageattack_save_to_db()
{
    api_MySQL_exec(mysql_frida, "replace into game_event (event_id, event_info) values ('villageattack', '" + JSON.stringify(villageAttackEventInfo) + "');");
}

//从数据库载入怪物攻城活动数据
function event_villageattack_load_from_db()
{
    if (api_MySQL_exec(mysql_frida, "select event_info from game_event where event_id = 'villageattack';"))
    {
        if (MySQL_get_n_rows(mysql_frida) == 1)
        {
            MySQL_fetch(mysql_frida);
            var info = api_MySQL_get_str(mysql_frida, 0);
            villageAttackEventInfo = JSON.parse(info);
        }
    }
}

//处理到期的自定义定时器
function do_timer_dispatch()
{
    //当前待处理的定时器任务列表
    var task_list = [];

    //线程安全
    var guard = api_Guard_Mutex_Guard();
    //依次取出队列中的任务
    while (timer_dispatcher_list.length > 0)
    {
        //先入先出
        var task = timer_dispatcher_list.shift();
        task_list.push(task);
    }
    Destroy_Guard_Mutex_Guard(guard);
    //执行任务
    for (var i = 0; i < task_list.length; ++i)
    {
        var task = task_list[i];

        var f = task[0];
        var args = task[1];
        f.apply(null, args);
    }
}

//申请锁(申请后务必手动释放!!!)
function api_Guard_Mutex_Guard()
{
    var a1 = Memory.alloc(100);
    Guard_Mutex_Guard(a1, G_TimerQueue().add(16));

    return a1;
}

//挂接消息分发线程 确保代码线程安全
function hook_TimerDispatcher_dispatch()
{
    //hook TimerDispatcher::dispatch
    //服务器内置定时器 每秒至少执行一次
    Interceptor.attach(ptr(0x8632A18),
    {
        onEnter: function(args) {},
        onLeave: function(retval)
        {
            //清空等待执行的任务队列
            do_timer_dispatch();
        }
    });
}

//在dispatcher线程执行(args为函数f的参数组成的数组, 若f无参数args可为null)
function api_scheduleOnMainThread(f, args)
{
    //线程安全
    var guard = api_Guard_Mutex_Guard();
    timer_dispatcher_list.push([f, args]);
    Destroy_Guard_Mutex_Guard(guard);
    return;
}

//设置定时器 到期后在dispatcher线程执行
function api_scheduleOnMainThread_delay(f, args, delay)
{
    setTimeout(api_scheduleOnMainThread, delay, f, args);
}

//重置活动数据
function reset_villageattack_info()
{
    villageAttackEventInfo.state = VILLAGEATTACK_STATE_P1;
    villageAttackEventInfo.score = 0;
    villageAttackEventInfo.difficult = 0;
    villageAttackEventInfo.next_village_monster_id = TAU_CAPTAIN_MONSTER_ID;
    villageAttackEventInfo.last_killed_monster_id = 0;
    villageAttackEventInfo.p2_kill_combo = 0;
    villageAttackEventInfo.user_pt_info = {};
    set_villageattack_dungeon_difficult(villageAttackEventInfo.difficult);
    villageAttackEventInfo.start_time = api_CSystemTime_getCurSec();
}

//怪物攻城活动计时器(每5秒触发一次)
function event_villageattack_timer()
{
    if (villageAttackEventInfo.state == VILLAGEATTACK_STATE_END)
        return;
    //活动结束检测
    var remain_time = event_villageattack_get_remain_time();
    if (remain_time <= 0)
    {
        //活动结束
        on_end_event_villageattack();
        return;
    }
    //当前应扣除的PT
    var damage = 0;
    //P2/P3阶段GBL主教扣PT
    if ((villageAttackEventInfo.state == VILLAGEATTACK_STATE_P2) || (villageAttackEventInfo.state == VILLAGEATTACK_STATE_P3))
    {
        for (var i = 0; i < villageAttackEventInfo.gbl_cnt; ++i)
        {
            if (get_random_int(0, 100) < (4 + villageAttackEventInfo.difficult))
            {
                damage += 1;
            }
        }
    }
    //P3阶段世界BOSS自身回血
    if (villageAttackEventInfo.state == VILLAGEATTACK_STATE_P3)
    {
        if (get_random_int(0, 100) < (6 + villageAttackEventInfo.difficult))
        {
            damage += 1;
        }
    }
    //扣除PT
    if (damage > 0)
    {
        villageAttackEventInfo.score -= damage;
        if (villageAttackEventInfo.score < EVENT_VILLAGEATTACK_TARGET_SCORE[villageAttackEventInfo.state - 1])
        {
            villageAttackEventInfo.score = EVENT_VILLAGEATTACK_TARGET_SCORE[villageAttackEventInfo.state - 1]
        }
        //更新PT
        gameworld_update_villageattack_score();
    }
    //重复触发计时器
    if (villageAttackEventInfo.state != VILLAGEATTACK_STATE_END)
    {
        api_scheduleOnMainThread_delay(event_villageattack_timer, null, 5000);
    }
}

//开启怪物攻城活动
function start_villageattack()
{
    console.log('start_villageattack-------------');
    var a3 = Memory.alloc(100);
    a3.add(10).writeInt(EVENT_VILLAGEATTACK_TOTAL_TIME); //活动剩余时间
    a3.add(14).writeInt(villageAttackEventInfo.score); //当前频道PT点数
    a3.add(18).writeInt(EVENT_VILLAGEATTACK_TARGET_SCORE[2]); //成功防守所需点数
    Inter_VillageAttackedStart_dispatch_sig(ptr(0), ptr(0), a3);
}

//开始怪物攻城活动
function on_start_event_villageattack()
{
    //重置活动数据
    reset_villageattack_info();
    //通知全服玩家活动开始 并刷新城镇怪物
    start_villageattack();
    //开启活动计时器
    api_scheduleOnMainThread_delay(event_villageattack_timer, null, 5000);
    //公告通知当前活动进度
    event_villageattack_broadcast_diffcult();
}

//开启怪物攻城活动定时器
function start_event_villageattack_timer()
{
    //获取当前系统时间
    var cur_time = api_CSystemTime_getCurSec();
    //计算距离下次开启怪物攻城活动的时间
    var delay_time = (3600 * EVENT_VILLAGEATTACK_START_HOUR) - (cur_time % (3600 * 24));
    if (delay_time <= 0)
        delay_time += 3600 * 24;
    //delay_time = 10;
    console.log('-------------------- <countdown time>:' + delay_time);
    //log('距离下次开启<怪物攻城活动>还有:' + delay_time / 3600 + '小时');
    //log('距离下次开启<怪物攻城活动>还有:' + delay_time * 1000);
    //定时开启活动
    api_scheduleOnMainThread_delay(on_start_event_villageattack, null, delay_time * 1000);
}

//开启怪物攻城活动
function start_event_villageattack()
{
    //patch相关函数, 修复活动流程
    hook_VillageAttack();
    console.log('-------------------- start_event_villageattack-----------------');
    if (villageAttackEventInfo.state == VILLAGEATTACK_STATE_END)
    {
        //开启怪物攻城活动定时器
        start_event_villageattack_timer();
    }
    else
    {
        //开启活动计时器
        api_scheduleOnMainThread_delay(event_villageattack_timer, null, 5000);
    }
}

//设置怪物攻城副本难度(0-4: 普通-英雄)
function set_villageattack_dungeon_difficult(difficult)
{
    Memory.protect(ptr(0x085B9605), 4, 'rwx'); //修改内存保护属性为可写
    ptr(0x085B9605).writeInt(difficult);
}

//世界广播怪物攻城活动当前进度/难度
function event_villageattack_broadcast_diffcult()
{
    if (villageAttackEventInfo.state != VILLAGEATTACK_STATE_END)
    {
        api_GameWorld_SendNotiPacketMessage('<怪物攻城活动> 当前阶段:' + (villageAttackEventInfo.state + 1) + ', 当前难度等级: ' + villageAttackEventInfo.difficult, 14);
    }
}

//计算活动剩余时间
function event_villageattack_get_remain_time()
{
    var cur_time = api_CSystemTime_getCurSec();
    var event_end_time = villageAttackEventInfo.start_time + EVENT_VILLAGEATTACK_TOTAL_TIME;
    var remain_time = event_end_time - cur_time;
    return remain_time;
}

//更新怪物攻城当前进度(广播给频道内在线玩家)
function gameworld_update_villageattack_score()
{
    //计算活动剩余时间
    var remain_time = event_villageattack_get_remain_time();
    if ((remain_time <= 0) || (villageAttackEventInfo.state == VILLAGEATTACK_STATE_END))
        return;
    var packet_guard = api_PacketGuard_PacketGuard();
    InterfacePacketBuf_put_header(packet_guard, 0, 247); //协议: ENUM_NOTIPACKET_UPDATE_VILLAGE_ATTACKED
    InterfacePacketBuf_put_int(packet_guard, remain_time); //活动剩余时间
    InterfacePacketBuf_put_int(packet_guard, villageAttackEventInfo.score); //当前频道PT点数
    InterfacePacketBuf_put_int(packet_guard, EVENT_VILLAGEATTACK_TARGET_SCORE[2]); //成功防守所需点数
    InterfacePacketBuf_finalize(packet_guard, 1);
    GameWorld_send_all(G_GameWorld(), packet_guard);
    Destroy_PacketGuard_PacketGuard(packet_guard);
}

//通知玩家怪物攻城进度
function notify_villageattack_score(user)
{
    //玩家当前PT点
    var charac_no = CUserCharacInfo_getCurCharacNo(user).toString();
    var villageattack_pt = 0;
    if (charac_no in villageAttackEventInfo.user_pt_info)
        villageattack_pt = villageAttackEventInfo.user_pt_info[charac_no][1];
    //计算活动剩余时间
    var remain_time = event_villageattack_get_remain_time();
    //log("remain_time=" + remain_time);
    if ((remain_time <= 0) || (villageAttackEventInfo.state == VILLAGEATTACK_STATE_END))
        return;
    //发包通知角色打开怪物攻城UI并更新当前进度
    var packet_guard = api_PacketGuard_PacketGuard();
    InterfacePacketBuf_put_header(packet_guard, 0, 248); //协议: ENUM_NOTIPACKET_STARTED_VILLAGE_ATTACKED
    InterfacePacketBuf_put_int(packet_guard, remain_time); //活动剩余时间
    InterfacePacketBuf_put_int(packet_guard, villageAttackEventInfo.score); //当前频道PT点数
    InterfacePacketBuf_put_int(packet_guard, EVENT_VILLAGEATTACK_TARGET_SCORE[2]); //成功防守所需点数
    InterfacePacketBuf_put_int(packet_guard, villageattack_pt); //个人PT点数
    InterfacePacketBuf_finalize(packet_guard, 1);
    CUser_Send(user, packet_guard);
    Destroy_PacketGuard_PacketGuard(packet_guard);
}

//怪物攻城活动相关patch
function hook_VillageAttack()
{
    //怪物攻城副本回调
    Interceptor.attach(ptr(0x086B34A0),
    {
        onEnter: function(args)
        {
            //保存函数参数
            //var CVillageMonster = args[0];
            this.user = args[1];
        },
        onLeave: function(retval)
        {
            if (retval == 0 && this.user.isNull() == false)
            {
                VillageAttackedRewardSendReward(this.user);
            }
        }
    });
    //hook挑战攻城怪物副本结束事件, 更新怪物攻城活动各阶段状态
    //village_attacked::CVillageMonster::SendVillageMonsterFightResult
    Interceptor.attach(ptr(0x086B330A),
    {
        onEnter: function(args)
        {
            this.village_monster = args[0]; //当前挑战的攻城怪物
            this.user = args[1]; //当前挑战的角色
            this.result = args[2].toInt32(); //挑战结果: 1==成功
        },
        onLeave: function(retval)
        {
            //玩家杀死了攻城怪物
            if (this.result == 1)
            {
                if (villageAttackEventInfo.state == VILLAGEATTACK_STATE_END) //攻城活动已结束
                    return;
                //当前杀死的攻城怪物id
                var village_monster_id = this.village_monster.add(2).readUShort();
                //当前阶段杀死每只攻城怪物PT点数奖励: (1, 2, 4, 8, 16)
                var bonus_pt = 2 ** villageAttackEventInfo.difficult;
                //玩家所在队伍
                var party = CUser_GetParty(this.user);
                if (party.isNull())
                    return;
                //更新队伍中的所有玩家PT点数
                for (var i = 0; i < 4; ++i)
                {
                    var user = CParty_get_user(party, i);
                    if (!user.isNull())
                    {
                        //角色当前PT点数(游戏中的原始PT数据记录在village_attack_dungeon表中)
                        var charac_no = CUserCharacInfo_getCurCharacNo(user).toString();
                        if (!(charac_no in villageAttackEventInfo.user_pt_info))
                            villageAttackEventInfo.user_pt_info[charac_no] = [CUser_get_acc_id(user), 0]; //记录角色accid, 方便离线充值
                        //更新角色当前PT点数
                        villageAttackEventInfo.user_pt_info[charac_no][1] += bonus_pt;

                        //击杀世界BOSS, 额外获得PT奖励
                        if ((village_monster_id == TAU_META_COW_MONSTER_ID) && (villageAttackEventInfo.state == VILLAGEATTACK_STATE_P3))
                        {
                            villageAttackEventInfo.user_pt_info[charac_no][1] += 1000 * (1 + villageAttackEventInfo.difficult);
                        }
                    }
                }
                if (villageAttackEventInfo.state == VILLAGEATTACK_STATE_P1) //怪物攻城一阶段
                {
                    //更新频道内总PT
                    villageAttackEventInfo.score += bonus_pt;

                    //P1阶段未完成
                    if (villageAttackEventInfo.score < EVENT_VILLAGEATTACK_TARGET_SCORE[0])
                    {
                        //若杀死了牛头统帅, 则攻城难度+1
                        if (village_monster_id == TAU_CAPTAIN_MONSTER_ID)
                        {
                            if (villageAttackEventInfo.difficult < 4)
                            {
                                villageAttackEventInfo.difficult += 1;
                                //怪物攻城副本难度
                                set_villageattack_dungeon_difficult(villageAttackEventInfo.difficult);
                                //下次刷新出的攻城怪物为: 牛头统帅
                                villageAttackEventInfo.next_village_monster_id = TAU_CAPTAIN_MONSTER_ID;
                                //公告通知客户端活动进度
                                event_villageattack_broadcast_diffcult();
                            }
                        }
                    } else
                    {
                        //P1阶段已结束, 进入P2
                        villageAttackEventInfo.state = VILLAGEATTACK_STATE_P2;
                        villageAttackEventInfo.score = EVENT_VILLAGEATTACK_TARGET_SCORE[0];
                        villageAttackEventInfo.p2_last_killed_monster_time = 0;
                        villageAttackEventInfo.last_killed_monster_id = 0;
                        villageAttackEventInfo.p2_kill_combo = 0;
                        //公告通知客户端活动进度
                        event_villageattack_broadcast_diffcult();
                    }
                } else if (villageAttackEventInfo.state == VILLAGEATTACK_STATE_P2) //怪物攻城二阶段
                {
                    //计算连杀时间
                    var cur_time = api_CSystemTime_getCurSec();
                    var diff_time = cur_time - villageAttackEventInfo.p2_last_killed_monster_time;

                    //1分钟内连续击杀相同攻城怪物
                    if ((diff_time < 60) && (village_monster_id == villageAttackEventInfo.last_killed_monster_id))
                    {
                        //连杀点数+1
                        villageAttackEventInfo.p2_kill_combo += 1;
                        if (villageAttackEventInfo.p2_kill_combo >= 3)
                        {
                            //三连杀增加当前阶段总PT
                            villageAttackEventInfo.score += 33;
                            //重新计算连杀
                            villageAttackEventInfo.last_killed_monster_id = 0;
                            villageAttackEventInfo.p2_kill_combo = 0;
                        }
                    } else
                    {
                        //重新计算连杀
                        villageAttackEventInfo.last_killed_monster_id = village_monster_id;
                        villageAttackEventInfo.p2_kill_combo = 1;
                    }
                    //保存本次击杀时间
                    villageAttackEventInfo.p2_last_killed_monster_time = cur_time;
                    //P2阶段已结束, 进入P3
                    if (villageAttackEventInfo.score >= EVENT_VILLAGEATTACK_TARGET_SCORE[1])
                    {
                        //P2阶段已结束, 进入P3
                        villageAttackEventInfo.state = VILLAGEATTACK_STATE_P3;
                        villageAttackEventInfo.score = EVENT_VILLAGEATTACK_TARGET_SCORE[1];
                        villageAttackEventInfo.next_village_monster_id = TAU_META_COW_MONSTER_ID;
                        //公告通知客户端活动进度
                        event_villageattack_broadcast_diffcult();
                    }
                } else if (villageAttackEventInfo.state == VILLAGEATTACK_STATE_P3) //怪物攻城三阶段
                {
                    //击杀世界boss
                    if (village_monster_id == TAU_META_COW_MONSTER_ID)
                    {
                        //更新世界BOSS血量(PT)
                        villageAttackEventInfo.score += 25;
                        //继续刷新世界BOSS
                        villageAttackEventInfo.next_village_monster_id = TAU_META_COW_MONSTER_ID;

                        //世界广播
                        api_GameWorld_SendNotiPacketMessage('<怪物攻城活动> 世界BOSS已被【' + api_CUserCharacInfo_getCurCharacName(this.user) + '】击杀!', 14);

                        //P3阶段已结束
                        if (villageAttackEventInfo.score >= EVENT_VILLAGEATTACK_TARGET_SCORE[2])
                        {
                            //怪物攻城活动防守成功, 立即结束活动
                            villageAttackEventInfo.defend_success = 1;
                            api_scheduleOnMainThread(on_end_event_villageattack, null);
                            return;
                        }
                    }
                }
                //世界广播当前活动进度
                gameworld_update_villageattack_score();
                //通知队伍中的所有玩家更新PT点数
                for (var i = 0; i < 4; ++i)
                {
                    var user = CParty_get_user(party, i);
                    if (!user.isNull())
                    {
                        notify_villageattack_score(user);
                    }
                }
                //更新存活GBL主教数量
                if (village_monster_id == GBL_POPE_MONSTER_ID)
                {
                    if (villageAttackEventInfo.gbl_cnt > 0)
                    {
                        villageAttackEventInfo.gbl_cnt -= 1;
                    }
                }
            }
        }
    });
    //hook 刷新攻城怪物函数, 控制下一只刷新的攻城怪物id
    //village_attacked::CVillageMonsterArea::GetAttackedMonster
    Interceptor.attach(ptr(0x086B3AEA),
    {
        onEnter: function(args) {},
        onLeave: function(retval)
        {
            //返回值为下一次刷新的攻城怪物
            if (retval != 0)
            {
                //下一只刷新的攻城怪物
                var next_village_monster = ptr(retval);
                var next_village_monster_id = next_village_monster.readUShort();

                //当前刷新的怪物为机制怪物
                if ((next_village_monster_id == TAU_META_COW_MONSTER_ID) || (next_village_monster_id == TAU_CAPTAIN_MONSTER_ID))
                {
                    //替换为随机怪物
                    next_village_monster.writeUShort(get_random_int(1, 17));
                }
                //如果需要刷新指定怪物
                if (villageAttackEventInfo.next_village_monster_id)
                {
                    if ((villageAttackEventInfo.state == VILLAGEATTACK_STATE_P1) || (villageAttackEventInfo.state == VILLAGEATTACK_STATE_P2))
                    {
                        //P1 P2阶段立即刷新怪物
                        next_village_monster.writeUShort(villageAttackEventInfo.next_village_monster_id);
                        villageAttackEventInfo.next_village_monster_id = 0;
                    } else if (villageAttackEventInfo.state == VILLAGEATTACK_STATE_P3)
                    {
                        //P3阶段 几率刷新出世界BOSS
                        if (get_random_int(0, 100) < 44)
                        {
                            next_village_monster.writeUShort(villageAttackEventInfo.next_village_monster_id);
                            villageAttackEventInfo.next_village_monster_id = 0;
                            //世界广播
                            api_GameWorld_SendNotiPacketMessage('<怪物攻城活动> 世界BOSS已刷新, 请勇士们前往挑战!', 14);
                        }
                    }
                }
                //统计存活GBL主教数量
                if (next_village_monster.readUShort() == GBL_POPE_MONSTER_ID)
                {
                    villageAttackEventInfo.gbl_cnt += 1;
                }
            }
        }
    });
    //当前正在处理挑战的攻城怪物请求
    var state_on_fighting = false;
    //当前正在被挑战的怪物id
    var on_fighting_village_monster_id = 0;
    //hook 挑战攻城怪物函数 控制副本刷怪流程
    //CParty::OnFightVillageMonster
    Interceptor.attach(ptr(0x085B9596),
    {
        onEnter: function(args)
        {
            state_on_fighting = true;
            on_fighting_village_monster_id = 0;
        },
        onLeave: function(retval)
        {
            on_fighting_village_monster_id = 0;
            state_on_fighting = false;
        }
    });
    //village_attacked::CVillageMonster::OnFightVillageMonster
    Interceptor.attach(ptr(0x086B3240),
    {
        onEnter: function(args)
        {
            if (state_on_fighting)
            {
                var village_monster = args[0];

                //记录当前正在挑战的攻城怪物id
                on_fighting_village_monster_id = village_monster.add(2).readU16();
            }
        },
        onLeave: function(retval) {}
    });
    //hook 副本刷怪函数 控制副本内怪物的数量和属性
    //MapInfo::Add_Mob
    var read_f = new NativeFunction(ptr(0x08151612), 'int', ['pointer', 'pointer'], { "abi": "sysv" });
    Interceptor.replace(ptr(0x08151612), new NativeCallback(function(map_info, monster)
    {
        //当前刷怪的副本id
        //var map_id = map_info.add(4).readUInt();
        //怪物攻城副本
        //if((map_id >= 40001) && (map_id <= 40095))
        if (state_on_fighting)
        {
            //怪物攻城活动未结束
            if (villageAttackEventInfo != VILLAGEATTACK_STATE_END)
            {
                //正在挑战世界BOSS
                if (on_fighting_village_monster_id == TAU_META_COW_MONSTER_ID)
                {
                    //P3阶段
                    if (villageAttackEventInfo.state == VILLAGEATTACK_STATE_P3)
                    {
                        //副本中有几率刷新出世界BOSS, 当前PT点数越高, 活动难度越大, 刷新出世界BOSS概率越大
                        if (get_random_int(0, 100) < ((villageAttackEventInfo.score - EVENT_VILLAGEATTACK_TARGET_SCORE[1]) + (6 * villageAttackEventInfo.difficult)))
                        {
                            monster.add(0xc).writeUInt(TAU_META_COW_MONSTER_ID);
                        }
                    }
                }
                if (villageAttackEventInfo.difficult == 0)
                {
                    //难度0: 无变化
                    return read_f(map_info, monster);
                } else if (villageAttackEventInfo.difficult == 1)
                {
                    //难度1: 怪物等级提升至100级
                    monster.add(16).writeU8(100);
                    return read_f(map_info, monster);
                } else if (villageAttackEventInfo.difficult == 2)
                {
                    //难度2: 怪物等级提升至110级; 随机刷新紫名怪
                    monster.add(16).writeU8(110);
                    //非BOSS怪
                    if (monster.add(8).readU8() != 3)
                    {
                        if (get_random_int(0, 100) < 50)
                        {
                            monster.add(8).writeU8(1); //怪物类型: 0-3
                        }
                    }
                    return read_f(map_info, monster);
                } else if (villageAttackEventInfo.difficult == 3)
                {
                    //难度3: 怪物等级提升至120级; 随机刷新不灭粉名怪; 怪物数量*2
                    monster.add(16).writeU8(120);
                    //非BOSS怪
                    if (monster.add(8).readU8() != 3)
                    {
                        if (get_random_int(0, 100) < 75)
                        {
                            monster.add(8).writeU8(2); //怪物类型: 0-3
                        }
                    }
                    //执行原始刷怪流程
                    read_f(map_info, monster);
                    //刷新额外的怪物(同一张地图内, 怪物index和怪物uid必须唯一, 这里为怪物分配新的index和uid)
                    //额外刷新怪物数量
                    var cnt = 1;
                    //新的怪物uid偏移
                    var uid_offset = 1000;
                    //返回值
                    var ret = 0;
                    while (cnt > 0)
                    {
                        --cnt;
                        //新增怪物index
                        monster.writeUInt(monster.readUInt() + uid_offset);
                        //新增怪物uid
                        monster.add(4).writeUInt(monster.add(4).readUInt() + uid_offset);

                        //为当前地图刷新额外的怪物
                        ret = read_f(map_info, monster);
                    }
                    return ret;
                } else if (villageAttackEventInfo.difficult == 4)
                {
                    //难度4: 怪物等级提升至127级; 随机刷新橙名怪; 怪物数量*4
                    monster.add(16).writeU8(127);
                    //非BOSS怪
                    if (monster.add(8).readU8() != 3)
                    {
                        //英雄级副本精英怪类型等于2的怪为橙名怪
                        monster.add(8).writeU8(get_random_int(1, 3)); //怪物类型: 0-3
                    }
                    //执行原始刷怪流程
                    read_f(map_info, monster);
                    //刷新额外的怪物(同一张地图内, 怪物index和怪物uid必须唯一, 这里为怪物分配新的index和uid)
                    //额外刷新怪物数量
                    var cnt = 3;
                    //新的怪物uid偏移
                    var uid_offset = 1000;
                    //返回值
                    var ret = 0;
                    while (cnt > 0)
                    {
                        --cnt;
                        //新增怪物index
                        monster.writeUInt(monster.readUInt() + uid_offset);
                        //新增怪物uid
                        monster.add(4).writeUInt(monster.add(4).readUInt() + uid_offset);

                        //为当前地图刷新额外的怪物
                        ret = read_f(map_info, monster);
                    }
                    return ret;
                }
            }
        }
        //执行原始刷怪流程
        return read_f(map_info, monster);
    }, 'int', ['pointer', 'pointer']));
    //每次通关额外获取当前等级升级所需经验的0%-0.1%
    //village_attacked::CVillageMonsterMgr::OnKillVillageMonster
    Interceptor.attach(ptr(0x086B4866),
    {
        onEnter: function(args)
        {
            this.user = args[1];
            this.result = args[2].toInt32();
        },
        onLeave: function(retval)
        {
            if (retval == 0)
            {
                //挑战成功
                if (this.result)
                {
                    //玩家所在队伍
                    var party = CUser_GetParty(this.user);
                    //怪物攻城挑战成功, 给队伍中所有成员发送额外通关发经验
                    for (var i = 0; i < 4; ++i)
                    {
                        var user = CParty_get_user(party, i);
                        if (!user.isNull())
                        {
                            //随机经验奖励
                            var cur_level = CUserCharacInfo_get_charac_level(user);
                            var reward_exp = Math.floor(CUserCharacInfo_get_level_up_exp(user, cur_level) * get_random_int(0, 1000) / 1000000);
                            //发经验
                            api_CUser_gain_exp_sp(user, reward_exp);
                            //通知玩家获取额外奖励
                            api_CUser_SendNotiPacketMessage(user, '怪物攻城挑战成功, 获取额外经验奖励' + reward_exp, 0);
                        }
                    }
                }
            }
        }
    });
}

//结束怪物攻城活动(立即销毁攻城怪物, 不开启逆袭之谷, 不发送活动奖励)
function end_villageattack()
{
    village_attacked_CVillageMonsterMgr_OnDestroyVillageMonster(GlobalData_s_villageMonsterMgr.readPointer(), 2);
}

//结束怪物攻城活动
function on_end_event_villageattack()
{
    if (villageAttackEventInfo.state == VILLAGEATTACK_STATE_END)
        return;
    //设置活动状态
    villageAttackEventInfo.state = VILLAGEATTACK_STATE_END;
    //立即结束怪物攻城活动
    end_villageattack();
    //防守成功
    if (villageAttackEventInfo.defend_success)
    {
        //频道内在线玩家发奖
        //发信奖励: 金币+道具
        var reward_gold = 1000000 * (1 + villageAttackEventInfo.difficult); //金币
        var reward_item_list =
        [
            [7745, 5 * (1 + villageAttackEventInfo.difficult)], //士气冲天
            [2600028, 5 * (1 + villageAttackEventInfo.difficult)], //天堂痊愈
            [42, 5 * (1 + villageAttackEventInfo.difficult)], //复活币
            [3314, 1 + villageAttackEventInfo.difficult], //绝望之塔通关奖章
        ];
        api_gameworld_send_mail('<怪物攻城活动>', '恭喜勇士!', reward_gold, reward_item_list);

        //特殊奖励
        api_gameworld_foreach(function(user, args)
        {
            //设置绝望之塔当前层数为100层
            api_TOD_UserState_setEnterLayer(user, 99);
            //随机选择一件穿戴中的装备
            var inven = CUserCharacInfo_getCurCharacInvenW(user);
            var slot = get_random_int(10, 21); //12件装备slot范围10-21
            var equ = CInventory_GetInvenRef(inven, INVENTORY_TYPE_BODY, slot);
            if (Inven_Item_getKey(equ))
            {
                //读取装备强化等级
                var upgrade_level = equ.add(6).readU8();
                if (upgrade_level < 31)
                {
                    //提升装备的强化/增幅等级
                    var bonus_level = get_random_int(1, 1 + villageAttackEventInfo.difficult);
                    upgrade_level += bonus_level;
                    if (upgrade_level >= 31)
                        upgrade_level = 31;
                    //提升强化/增幅等级
                    equ.add(6).writeU8(upgrade_level);
                    //通知客户端更新装备
                    CUser_SendUpdateItemList(user, 1, 3, slot);
                }
            }
        }, null);
        //榜一大哥
        var rank_first_charac_no = 0;
        var rank_first_account_id = 0;
        var max_pt = 0;
        //论功行赏
        for (var charac_no in villageAttackEventInfo.user_pt_info)
        {
            //发点券
            var account_id = villageAttackEventInfo.user_pt_info[charac_no][0];
            var pt = villageAttackEventInfo.user_pt_info[charac_no][1];
            var reward_cera = pt * 10; //点券奖励 = 个人PT * 10
            var user_pr = GameWorld_find_user_from_world_byaccid(G_GameWorld(), account_id);
            api_recharge_cash_cera(user_pr, reward_cera);
            //找出榜一大哥
            if (pt > max_pt)
            {
                rank_first_charac_no = charac_no;
                rank_first_account_id = account_id;
                max_pt = pt;
            }
        }
        //频道内公告活动已结束
        api_GameWorld_SendNotiPacketMessage('<怪物攻城活动> 防守成功, 奖励已发送!', 14);
        if (rank_first_charac_no)
        {
            //个人积分排行榜第一名 额外获得10倍点券奖励
            var user_pr = GameWorld_find_user_from_world_byaccid(G_GameWorld(), rank_first_account_id);
            api_recharge_cash_cera(user_pr, max_pt * 10);

            //频道内广播本轮活动排行榜第一名玩家名字
            var rank_first_charac_name = api_get_charac_name_by_charac_no(rank_first_charac_no);
            api_GameWorld_SendNotiPacketMessage('<怪物攻城活动> 恭喜勇士 【' + rank_first_charac_name + '】 成为个人积分排行榜第一名(' + max_pt + 'pt)!', 14);
        }
    } else
    {
        //防守失败
        api_gameworld_foreach(function(user, args)
        {
            //获取角色背包
            var inven = CUserCharacInfo_getCurCharacInvenW(user);
            //在线玩家被攻城怪物随机掠夺一件穿戴中的装备
            if (get_random_int(0, 100) < 7)
            {
                //随机删除一件穿戴中的装备
                var slot = get_random_int(10, 21); //12件装备slot范围10-21
                var equ = CInventory_GetInvenRef(inven, INVENTORY_TYPE_BODY, slot);

                if (Inven_Item_getKey(equ))
                {
                    Inven_Item_reset(equ);
                    //通知客户端更新装备
                    CUser_SendNotiPacket(user, 1, 2, 3);
                }
            }
            //在线玩家被攻城怪物随机掠夺1%-10%所持金币
            var rate = get_random_int(1, 11);
            var cur_gold = CInventory_get_money(inven);
            var tax = Math.floor((rate / 100) * cur_gold);
            CInventory_use_money(inven, tax, 0, 0);
            //通知客户端更新金币数量
            CUser_SendUpdateItemList(user, 1, 0, 0);
        }, null);
        //频道内公告活动已结束
        api_GameWorld_SendNotiPacketMessage('<怪物攻城活动> 防守失败, 请勇士们再接再厉!', 14);
    }
    //释放空间
    villageAttackEventInfo.user_pt_info = {};
    //存档
    event_villageattack_save_to_db();
    //开启怪物攻城活动定时器
    start_event_villageattack_timer();
}

//无条件完成指定任务并领取奖励
function api_force_clear_quest(user, quest_id)
{
    //设置GM完成任务模式(无条件完成任务)
    CUser_setGmQuestFlag(user, 1);
    //接受任务
    CUser_quest_action(user, 33, quest_id, 0, 0);
    //完成任务
    CUser_quest_action(user, 35, quest_id, 0, 0);
    //领取任务奖励(倒数第二个参数表示领取奖励的编号, -1=领取不需要选择的奖励; 0=领取可选奖励中的第1个奖励; 1=领取可选奖励中的第二个奖励)
    CUser_quest_action(user, 36, quest_id, -1, 1);

    //服务端有反作弊机制: 任务完成时间间隔不能小于1秒.  这里将上次任务完成时间清零 可以连续提交任务
    user.add(0x79644).writeInt(0);

    //关闭GM完成任务模式(不需要材料直接完成)
    CUser_setGmQuestFlag(user, 0);
    return;
}

//完成指定任务并领取奖励
function clear_doing_questEx(user, quest_id)
{ //完成指定任务并领取奖励1
    //玩家任务信息
    var user_quest = CUser_getCurCharacQuestW(user);
    //玩家已完成任务信息
    var WongWork_CQuestClear = user_quest.add(4);
    //pvf数据
    var data_manager = G_CDataManager();
    //跳过已完成的任务
    if (!WongWork_CQuestClear_isClearedQuest(WongWork_CQuestClear, quest_id))
    {
        //获取pvf任务数据
        var quest = CDataManager_find_quest(data_manager, quest_id);
        if (!quest.isNull())
        {
            //无条件完成指定任务并领取奖励
            api_force_clear_quest(user, quest_id);
            //通知客户端更新已完成任务列表
            CUser_send_clear_quest_list(user);
            //通知客户端更新任务列表
            var packet_guard = api_PacketGuard_PacketGuard();
            UserQuest_get_quest_info(user_quest, packet_guard);
            CUser_Send(user, packet_guard);
            Destroy_PacketGuard_PacketGuard(packet_guard);
        }
    } else
    {
        //公告通知客户端本次自动完成任务数据
        api_CUser_SendNotiPacketMessage(user, '当前任务已完成: ', 14);
    }
}

//修复绝望之塔 skip_user_apc: 为true时, 跳过每10层的UserAPC
function fix_TOD(skip_user_apc)
{
    //挑战成功后可以继续使用门票挑战
    Interceptor.attach(ptr(0x0864387E),
    {
        onEnter: function (args)
        {
        },
        onLeave: function (retval)
        {
            retval.replace(0);
        }
    });

    //每10层挑战玩家APC 服务器内角色不足10个无法进入
    if(skip_user_apc)
    {
        //跳过10/20/.../90层
        //TOD_UserState::getTodayEnterLayer
        Interceptor.attach(ptr(0x0864383E),
        {

            onEnter: function (args)
            {
                //绝望之塔当前层数
                var today_enter_layer = args[1].add(0x14).readShort();

                if(((today_enter_layer%10) == 9) && (today_enter_layer > 0) && (today_enter_layer < 99))
                {
                    //当前层数为10的倍数时  直接进入下一层
                    args[1].add(0x14).writeShort(today_enter_layer + 1);
                }
            },
            onLeave: function (retval)
            {
            }
        });
    }

    //修复金币异常
    //CParty::UseAncientDungeonItems
    var CParty_UseAncientDungeonItems_ptr = ptr(0x859EAC2);
    var CParty_UseAncientDungeonItems = new NativeFunction(CParty_UseAncientDungeonItems_ptr, 'int', ['pointer', 'pointer', 'pointer', 'pointer'], { "abi": "sysv" });
    Interceptor.replace(CParty_UseAncientDungeonItems_ptr, new NativeCallback(function(party, dungeon, inven_item, a4)
    {
        //当前进入的地下城id
        var dungeon_index = CDungeon_get_index(dungeon);
        //根据地下城id判断是否为绝望之塔
        if ((dungeon_index >= 11008) && (dungeon_index <= 11107))
        {
            //绝望之塔 不再扣除金币
            return 1;
        }
        //其他副本执行原始扣除道具逻辑
        return CParty_UseAncientDungeonItems(party, dungeon, inven_item, a4);
    }, 'int', ['pointer', 'pointer', 'pointer', 'pointer']));
}

//获取时装在数据库中的uid
function api_get_avartar_ui_id(avartar)
{
    return avartar.add(7).readInt();
}

//设置时装插槽数据(时装插槽数据指针, 插槽, 徽章id)
//jewel_type: 红=0x1, 黄=0x2, 绿=0x4, 蓝=0x8, 白金=0x10
function api_set_JewelSocketData(jewelSocketData, slot, emblem_item_id)
{
    if (!jewelSocketData.isNull())
    {
        //每个槽数据长6个字节: 2字节槽类型+4字节徽章item_id
        //镶嵌不改变槽类型, 这里只修改徽章id
        jewelSocketData.add(slot * 6 + 2).writeInt(emblem_item_id);
    }
    return;
}

//修复时装镶嵌
function fix_use_emblem()
{
    //Dispatcher_UseJewel::dispatch_sig
    Interceptor.attach(ptr(0x8217BD6),
    {
        onEnter: function(args)
        {
            try
            {
                var user = args[1];
                var packet_buf = args[2];
                //校验角色状态是否允许镶嵌
                var state = CUser_get_state(user);
                if (state != 3)
                {
                    return;
                }
                //解析packet_buf
                //时装所在的背包槽
                var avartar_inven_slot = api_PacketBuf_get_short(packet_buf);
                //时装item_id
                var avartar_item_id = api_PacketBuf_get_int(packet_buf);
                //本次镶嵌徽章数量
                var emblem_cnt = api_PacketBuf_get_byte(packet_buf);
                //获取时装道具
                var inven = CUserCharacInfo_getCurCharacInvenW(user);
                var avartar = CInventory_GetInvenRef(inven, INVENTORY_TYPE_AVARTAR, avartar_inven_slot);
                //校验时装 数据是否合法
                if (Inven_Item_isEmpty(avartar) || (Inven_Item_getKey(avartar) != avartar_item_id) || CUser_CheckItemLock(user, 2, avartar_inven_slot))
                {
                    return;
                }
                //获取时装插槽数据
                var avartar_add_info = Inven_Item_get_add_info(avartar);
                var inven_avartar_mgr = CInventory_GetAvatarItemMgrR(inven);
                var jewel_socket_data = WongWork_CAvatarItemMgr_getJewelSocketData(inven_avartar_mgr, avartar_add_info);

                if (jewel_socket_data.isNull())
                {
                    return;
                }
                //最多只支持3个插槽
                if (emblem_cnt <= 3)
                {
                    var emblems = {};
                    for (var i = 0; i < emblem_cnt; i++)
                    {
                        //徽章所在的背包槽
                        var emblem_inven_slot = api_PacketBuf_get_short(packet_buf);
                        //徽章item_id
                        var emblem_item_id = api_PacketBuf_get_int(packet_buf);
                        //该徽章镶嵌的时装插槽id
                        var avartar_socket_slot = api_PacketBuf_get_byte(packet_buf);
                        //log('emblem_inven_slot=' + emblem_inven_slot + ', emblem_item_id=' + emblem_item_id + ', avartar_socket_slot=' + avartar_socket_slot);
                        //获取徽章道具
                        var emblem = CInventory_GetInvenRef(inven, INVENTORY_TYPE_ITEM, emblem_inven_slot);
                        //校验徽章及插槽数据是否合法
                        if (Inven_Item_isEmpty(emblem) || (Inven_Item_getKey(emblem) != emblem_item_id) || (avartar_socket_slot >= 3))
                        {
                            return;
                        }
                        //校验徽章是否满足时装插槽颜色要求
                        //获取徽章pvf数据
                        var citem = CDataManager_find_item(G_CDataManager(), emblem_item_id);
                        if (citem.isNull())
                        {
                            return;
                        }
                        //校验徽章类型
                        if (!CItem_is_stackable(citem) || (CStackableItem_GetItemType(citem) != 20))
                        {
                            return;
                        }
                        //获取徽章支持的插槽
                        var emblem_socket_type = CStackableItem_getJewelTargetSocket(citem);
                        //获取要镶嵌的时装插槽类型
                        var avartar_socket_type = jewel_socket_data.add(avartar_socket_slot * 6).readShort()
                        if (!(emblem_socket_type & avartar_socket_type))
                        {
                            //插槽类型不匹配
                            //log('socket type not match!');
                            return;
                        }
                        emblems[avartar_socket_slot] = [emblem_inven_slot, emblem_item_id];
                    }
                    //开始镶嵌
                    for (var avartar_socket_slot in emblems)
                    {
                        //删除徽章
                        var emblem_inven_slot = emblems[avartar_socket_slot][0];
                        CInventory_delete_item(inven, 1, emblem_inven_slot, 1, 8, 1);
                        //设置时装插槽数据
                        var emblem_item_id = emblems[avartar_socket_slot][1];
                        api_set_JewelSocketData(jewel_socket_data, avartar_socket_slot, emblem_item_id);
                        //log('徽章item_id=' + emblem_item_id + '已成功镶嵌进avartar_socket_slot=' + avartar_socket_slot + '的槽内!');
                    }
                    //时装插槽数据存档
                    DB_UpdateAvatarJewelSlot_makeRequest(CUserCharacInfo_getCurCharacNo(user), api_get_avartar_ui_id(avartar), jewel_socket_data);
                    //通知客户端时装数据已更新
                    CUser_SendUpdateItemList(user, 1, 1, avartar_inven_slot);
                    //回包给客户端
                    var packet_guard = api_PacketGuard_PacketGuard();
                    InterfacePacketBuf_put_header(packet_guard, 1, 204);
                    InterfacePacketBuf_put_int(packet_guard, 1);
                    InterfacePacketBuf_finalize(packet_guard, 1);
                    CUser_Send(user, packet_guard);
                    Destroy_PacketGuard_PacketGuard(packet_guard);
                    //log('镶嵌请求已处理完成!');
                }
            } catch (error)
            {
                console.log('fix_use_emblem throw Exception:' + error);
            }
        },
        onLeave: function(retval)
        {
            //返回值改为0  不再踢线
            retval.replace(0);
        }
    });
}

//TODO排行榜前三名数组 默认数据   战力榜
var ranklist =
{
    "1":
    {
        "rank": 100,
        "characname": "虚位以待",
        "job": 0,
        "lev": 85,
        "Grow": 17,
        "Guilkey": 1,
        "Guilname": "",
        "str": "111！",
        "equip": [101531433, 101551558, 101501731, 101571413, 101561697, 101521488, 101511859, 101541622, 0, -1, 101040146]
    },

    "2":
    {
        "rank": 90,
        "characname": "虚位以待",
        "job": 1,
        "lev": 85,
        "Grow": 17,
        "Guilkey": 1,
        "Guilname": "",
        "str": "222！",
        "equip": [45486, 43101, 44757, 43879, 43541, 44283, 45155, 45935, 0, -1, 102040100]
    },
    "3":
    {
        "rank": 80,
        "characname": "虚位以待",
        "job": 4,
        "lev": 85,
        "Grow": 17,
        "Guilkey": 1,
        "Guilname": "",
        "str": "333！",
        "equip": [57519, 55153, 56754, 55922, 55533, 56332, 57147, 57946, 0, -1, 108030043]
    },
};

/**
 * 获得rank分（排名分数）
 * 适配花枝战力值数据库，其他请按照实际表进行适配
 * 本地：var insertQuery = "SELECT ZLZ FROM frida.battle WHERE CID='" + charac_no + "';";
 * 暴雨：var insertQuery = "SELECT ZLZ FROM d_starsky.zhanli WHERE CID='" + charac_no + "';";
 * 暴雨：var insertQuery = "SELECT ZLZ FROM d_baoyu.zhanli WHERE CID='" + charac_no + "';";
 * RS：var insertQuery = "SELECT ZLZ FROM Rslogin.battle WHERE ZID='" + charac_no + "';";
 * @param {string} characno
 * @returns 返回对应的战力值
 */
function GetRankNumber(charac_no) {
    var insertQuery = "SELECT ZLZ FROM frida.battle WHERE CID='" + charac_no + "';";
    if (api_MySQL_exec(mysql_taiwan_cain, insertQuery)) {
        if (MySQL_get_n_rows(mysql_taiwan_cain) == 1) {
            MySQL_fetch(mysql_taiwan_cain);
            return parseInt(api_MySQL_get_str(mysql_taiwan_cain, 0));
        }
    }
}

/**
 * 获取自身排行版数据
 * 角色名处多家个空格用于屏蔽客户端内排行榜对显示框修改
 * 若要允许自行修改，请删除，并且删除默认初始中空格字符
 * @param {pointer} user 
 * @returns 
 */
function GetMyEquInfo(user) {
    var MyRanklist =
    {
        "rank": 0,
        "characname": "",
        "job": 0,
        "lev": 0,
        "Grow": 0,
        "Guilkey": 0,
        "Guilname": "",
        "str": "",
        "equip": []
    };
    var charac_no = CUserCharacInfo_getCurCharacNo(user);
    MyRanklist.rank = GetRankNumber(charac_no);
    console.log(MyRanklist.rank);
    MyRanklist.characname = api_CUserCharacInfo_getCurCharacName(user) + ""; //多个空格是为了屏蔽客户端自定义设置显示字符串
    MyRanklist.job = CUserCharacInfo_get_charac_job(user);
    MyRanklist.lev = CUserCharacInfo_get_charac_level(user);
    MyRanklist.Grow = CUserCharacInfo_getCurCharacGrowType(user);
    MyRanklist.Guilkey = CUserCharacInfo_get_charac_guildkey(user);
    MyRanklist.Guilname = api_CUser_GetGuildName(user);
    if (!MyRanklist.Guilname) {
        MyRanklist.Guilname = '未加入公会'; //当公会不存在时，设置默认公会名字
    }
    var InvenW = CUserCharacInfo_getCurCharacInvenW(user);
    for (var i = 0; i <= 10; i++) {
        if (i != 9) {
            var inven_item = CInventory_GetInvenRef(InvenW, INVENTORY_TYPE_BODY, i);
            var item_id = Inven_Item_getKey(inven_item);
            MyRanklist.equip.push(item_id);
        }
        else {
            MyRanklist.equip.push(-1);
        }
    }
    return MyRanklist;
}

/**
 * 玩家下线时，保存自身信息并且和排行版进行排名
 * 调用方法：api_scheduleOnMainThread(SetRanking, [user]);//更新个人信息到排行榜
 * @param {pointer} user 
 */
function SetRanking(user) {
    var MyRanklist = GetMyEquInfo(user);
    var existingIndex = Object.values(ranklist).findIndex(item => item.characname === MyRanklist.characname);//

    if (MyRanklist.rank) {
        if (existingIndex !== -1) {
            // 如果用户已经在排行榜中，更新他们的信息
            ranklist[existingIndex + 1] = MyRanklist;
        }
        else {
            // 如果用户不在排行榜中，将他们添加到排行榜
            ranklist["4"] = MyRanklist;
        }
        // 对排行榜进行排序
        const rankArray = Object.values(ranklist);
        rankArray.sort((a, b) => b.rank - a.rank);

        // 获取前三名玩家的信息
        const topThree = rankArray.slice(0, 3);

        const tmp = {};
        // 重新构建排行榜对象，仅包括前三名
        topThree.forEach((item, index) => {
            tmp[(index + 1).toString()] = item;
        });

        // 删除排行榜中排名为 "4" 的条目
        delete ranklist["4"];
        console.log(JSON.stringify(ranklist));
        ranklist = tmp;
    }
}

/**
 * //TODO排行榜下发 
 * api_scheduleOnMainThread(SendRankLits, [this.user, true]);//发送排行版到个人
 * @param {pointer} user
 * @param {boolean} all turn 全体下发 flash 单体下发
 */
function SendRankLits(user, all) {
    var packet_guard = api_PacketGuard_PacketGuard();
    InterfacePacketBuf_put_header(packet_guard, 0, 182);
    InterfacePacketBuf_put_byte(packet_guard, Object.keys(ranklist).length); //雕像数量
    for (var key in ranklist) {
        if (ranklist.hasOwnProperty(key)) {
            var charac_level = ranklist[key].lev; //等级
            var charac_job = ranklist[key].job; //职业
            var characGrowType = ranklist[key].Grow; //pvp段位
            var charac_name = ranklist[key].characname; //角色名
            var charac_Guilname = ranklist[key].Guilname; //公会名
            var charac_Guilkey = ranklist[key].Guilkey; //公会ID
            var equip = ranklist[key].equip; //装扮代码组
            api_InterfacePacketBuf_put_string(packet_guard, charac_name); //角色名
            InterfacePacketBuf_put_byte(packet_guard, charac_level); //等级
            InterfacePacketBuf_put_byte(packet_guard, charac_job); //职业
            InterfacePacketBuf_put_byte(packet_guard, characGrowType); //pvp段位
            api_InterfacePacketBuf_put_string(packet_guard, charac_Guilname); //公会名
            InterfacePacketBuf_put_int(packet_guard, charac_Guilkey); //公会ID
            for (var i = 0; i < equip.length; i++) {
                if (i != 9) {
                    var item_id = equip[i]; //装扮id
                }
                else {
                    item_id = -1
                }
                InterfacePacketBuf_put_int(packet_guard, item_id); //装扮id
            }
        }
    }
    InterfacePacketBuf_finalize(packet_guard, 1);
    if (all) {
        GameWorld_send_all(G_GameWorld(), packet_guard);
    }
    else {
        CUser_Send(user, packet_guard);
    }
    Destroy_PacketGuard_PacketGuard(packet_guard);
}

/**热载脚本时，加载排行版数据*/
function event_rankinfo_load_from_db() {
    console.log(api_MySQL_exec(mysql_frida, "select event_info from game_event where event_id = 'rankinfo';"));
    if (api_MySQL_exec(mysql_frida, "select event_info from game_event where event_id = 'rankinfo';")) {
        if (MySQL_get_n_rows(mysql_frida) == 1) {
            MySQL_fetch(mysql_frida);
            var info = api_MySQL_get_str(mysql_frida, 0);
            ranklist = JSON.parse(info);
        }
    }
}

/**热载脚本时，存储排行版数据 */
function event_rankinfo_save_to_db() {
    try {
        api_MySQL_exec(mysql_frida, "replace into game_event (event_id, event_info) values ('rankinfo', '" + JSON.stringify(ranklist) + "');");
    } catch (error) {
    }
}

//角色登入登出处理
function hook_user_inout_game_world()
{
    //选择角色处理函数 Hook GameWorld::reach_game_world
    Interceptor.attach(ptr(0x86C4E50),
    {
        //函数入口, 拿到函数参数args
        onEnter: function(args)
        {
            //保存函数参数
            this.user = args[1];
            //console.log('[GameWorld::reach_game_world] this.user=' + this.user);
        },
        //原函数执行完毕, 这里可以得到并修改返回值retval
        onLeave: function(retval)
        {
            var user = this.user;
            api_scheduleOnMainThread(SendRankLits, [user, true]); //战力榜相关
            console.log('hook_user_inout_game_world-villageAttackEventInfo.state=' + villageAttackEventInfo.state);
            //怪物攻城活动更新进度
            if (villageAttackEventInfo.state != VILLAGEATTACK_STATE_END)
            {
                //通知客户端打开活动UI
                notify_villageattack_score(this.user);
                //公告通知客户端活动进度
                event_villageattack_broadcast_diffcult();
            }
            //给角色发消息问候
            api_CUser_SendNotiPacketMessage(this.user, 'Hello : ' + api_CUserCharacInfo_getCurCharacName(this.user), 2);
        }
    });
    //角色退出时处理函数 Hook GameWorld::leave_game_world
    Interceptor.attach(ptr(0x86C5288),
    {
        onEnter: function(args)
        {
            var user = args[1];
            SetRanking(user); //战力榜相关
            //console.log('[GameWorld::leave_game_world] user=' + user);
        },
        onLeave: function(retval) {}
    });
}

//怪物攻城副本回调奖励处理函数
function VillageAttackedRewardSendReward(user)
{
    var VAttackCount = GetCurVAttackCount(user);
    switch (VAttackCount)
    {
        case 1:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3037, 5);
            break;
        case 2:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3037, 5);
            break;
        case 3:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3037, 5);
            break;
        case 4:
            CMailBoxHelperReqDBSendNewSystemMail(user, 1085, 2);
            break;
        case 5:
            CMailBoxHelperReqDBSendNewSystemMail(user, 1085, 5);
            break;
        case 6:
            CMailBoxHelperReqDBSendNewSystemMail(user, 1085, 2);
            break;
        case 7:
            CMailBoxHelperReqDBSendNewSystemMail(user, 8, 2);
            break;
        case 8:
            CMailBoxHelperReqDBSendNewSystemMail(user, 8, 5);
            break;
        case 9:
            CMailBoxHelperReqDBSendNewSystemMail(user, 8, 2);
            break;
        case 10:
            CMailBoxHelperReqDBSendNewSystemMail(user, 36, 1);
            break;
        case 11:
            CMailBoxHelperReqDBSendNewSystemMail(user, 36, 1);
            break;
        case 12:
            CMailBoxHelperReqDBSendNewSystemMail(user, 15, 1);
            break;
        case 13:
            CMailBoxHelperReqDBSendNewSystemMail(user, 15, 1);
            break;
        case 14:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3037, 10);
            break;
        case 15:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3262, 2);
            break;
        case 16:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3262, 3);
            break;
        case 17:
            CMailBoxHelperReqDBSendNewSystemMail(user, 2600261, 1);
            break;
        case 18:
            CMailBoxHelperReqDBSendNewSystemMail(user, 2600261, 1);
            break;
        case 19:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3037, 5);
            break;
        case 20:
            CMailBoxHelperReqDBSendNewSystemMail(user, 1031, 2);
            break;
        case 21:
            CMailBoxHelperReqDBSendNewSystemMail(user, 8, 2);
            break;
        case 22:
            CMailBoxHelperReqDBSendNewSystemMail(user, 1085, 2);
            break;
        case 23:
            CMailBoxHelperReqDBSendNewSystemMail(user, 8, 5);
            break;
        case 24:
            CMailBoxHelperReqDBSendNewSystemMail(user, 15, 1);
            break;
        case 25:
            CMailBoxHelperReqDBSendNewSystemMail(user, 15, 2);
            break;
        case 26:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3262, 5);
            break;
        case 27:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3262, 2);
            break;
        case 28:
            CMailBoxHelperReqDBSendNewSystemMail(user, 8, 5);
            break;
        case 29:
            CMailBoxHelperReqDBSendNewSystemMail(user, 1085, 2);
            break;
        case 30:
            CMailBoxHelperReqDBSendNewSystemMail(user, 10000160, 1);
            break;
        case 31:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3037, 5);
            break;
        case 32:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3037, 5);
            break;
        case 33:
            CMailBoxHelperReqDBSendNewSystemMail(user, 8, 2);
            break;
        case 34:
            CMailBoxHelperReqDBSendNewSystemMail(user, 1085, 2);
            break;
        case 35:
            CMailBoxHelperReqDBSendNewSystemMail(user, 2600261, 1);
            break;
        case 36:
            CMailBoxHelperReqDBSendNewSystemMail(user, 10000161, 1);
            break;
        default:
            CMailBoxHelperReqDBSendNewSystemMail(user, 3037, 5);
    }
}

// 回归勇士时间设置
function set_return_user(day)
{
    var time = day * 86400;
    Memory.protect(ptr(0x84C753D), 32, 'rwx');
    ptr(0x84C753D).writeU32(time);
}

/**-------------------------------------------------------时装潜能开始--------------------------------------------**/
function get_random_int(min, max)
{
	return Math.floor(Math.random() * (max - min)) + min;
}

function hidden_option()
{
	//关闭系统分配属性
	Memory.protect(ptr(0x08509D49), 3, 'rwx');
	ptr(0x08509D49).writeByteArray([0xEB]);

	//下发时装潜能属性
	Memory.protect(ptr(0x08509D34), 3, 'rwx');
	ptr(0x08509D34).writeUShort(get_random_int(1, 64)); //属性(1 ~ 63)
}

function start_hidden_option()
{
	Interceptor.attach(ptr(0x08509B9E),
	{
		onEnter: function (args)
		{
			hidden_option(); //go~~~
		},
		onLeave: function (retval) {}
	});

	Interceptor.attach(ptr(0x0817EDEC),
	{
		onEnter: function (args) {},
		onLeave: function (retval)
		{
			retval.replace(1); //return 1;
		}
	});
}
/**-------------------------------------------------------时装潜能结束--------------------------------------------**/

//加载主功能
function start()
{
    console.log('++++++++++++++++++++ frida init ++++++++++++++++++++');
    fix_TOD(true);    //绝望之塔修复
    fix_use_emblem();    //镶嵌
    start_hidden_option();    //装扮潜能
    hook_user_inout_game_world()    //怪物攻城，//玩家上下线处理(站街战力排行)
    set_return_user(15);    //勇士归来时间设置
    //enable_online_reward();    //在线奖励
    load_config('frida_config.json');    //加载本地配置文件
    api_scheduleOnMainThread(init_db, null);    //初始化数据库
    hook_TimerDispatcher_dispatch();    //挂接消息分发线程 执行需要在主线程运行的代码
    api_scheduleOnMainThread(start_event_villageattack, null);    //开启怪物攻城活动
    console.log('++++++++++++++++++++ fffffffffffffffff ++++++++++++++++++++'); //如果你在控制台看见这个表示所有功能开启成功
}

//延迟加载插件
function awake()
{
    //Hook check_argv
    Interceptor.attach(ptr(0x829EA5A),
    {
        onEnter: function(args) {},
        onLeave: function(retval)
        {
            //等待check_argv函数执行结束 再加载插件
            start();
        }
    });
}

//框架入口
rpc.exports =
{
    init: function(stage, parameters)
    { //脚本加载时执行
        if (stage == 'early')
        {
            //首次加载插件 等待服务器初始化后再加载
            awake();
        } else
        {
            //热重载:  直接加载
            start();
        }
    },
    dispose: function()
    { //脚本卸载时执行
        uninit_db();
        console.log('-------------------- frida dispose -----------------');
    }
};
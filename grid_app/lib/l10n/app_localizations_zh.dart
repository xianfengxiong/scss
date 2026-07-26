// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get ok => '确定';

  @override
  String get rename => '改名';

  @override
  String get save => '保存';

  @override
  String get name => '名称';

  @override
  String get export => '导出';

  @override
  String get templatesTitle => 'SCSS 模版';

  @override
  String get exportAllPdf => '导出全部 PDF';

  @override
  String get exportTemplatePdf => '导出该模版 PDF';

  @override
  String get sync => '同步';

  @override
  String get surveysTooltip => '全部调查表';

  @override
  String get noTemplatesYet => '还没有模版。点 + 新建一个。';

  @override
  String templateSubtitle(int pages, int surveys) {
    return '$pages 页 · $surveys 份调查表';
  }

  @override
  String get editDesign => '编辑设计';

  @override
  String confirmDeleteTitle(String name) {
    return '删除「$name」?';
  }

  @override
  String get surveysAreKept => '已填写的调查表会保留。';

  @override
  String get newTemplate => '新建模版';

  @override
  String get renameTemplate => '模版改名';

  @override
  String get language => '语言 / Language';

  @override
  String get followSystem => '跟随系统';

  @override
  String get exportTo => '导出到:';

  @override
  String get changeDirectory => '更改目录…';

  @override
  String get exportHint => '每个模版一个文件夹,每份调查表一个多页 PDF。\n增量导出:内容未变化的调查表自动跳过。';

  @override
  String get preparing => '准备中…';

  @override
  String exportingProgress(int done, int total) {
    return '导出中 $done/$total';
  }

  @override
  String get exporting => '导出中…';

  @override
  String get chooseExportDirectory => '选择导出目录';

  @override
  String exportDirUnwritable(String error) {
    return '导出失败:目录不可写($error)';
  }

  @override
  String exportResult(int written, int skipped) {
    return '导出完成:新导出 $written 份 · 跳过 $skipped 份(未变化)';
  }

  @override
  String exportErrors(int count) {
    return ' · $count 份出错';
  }

  @override
  String surveysCount(int count) {
    return '$count 份调查表';
  }

  @override
  String get noSurveysInTemplate => '这个模版还没有调查表。点 + 新建一份。';

  @override
  String get newSurvey => '新建调查表';

  @override
  String get renameSurvey => '调查表改名';

  @override
  String get allSurveysTitle => '全部调查表';

  @override
  String get noSurveysYet => '还没有调查表。打开一个模版新建。';

  @override
  String get templateNotFound => '找不到这份调查表对应的模版。';

  @override
  String fieldsCount(int count) {
    return '$count 项已填';
  }

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int n) {
    return '$n 分钟前';
  }

  @override
  String hoursAgo(int n) {
    return '$n 小时前';
  }

  @override
  String daysAgo(int n) {
    return '$n 天前';
  }

  @override
  String get cols => '列';

  @override
  String get rows => '行';

  @override
  String builderSubtitle(int cols, int rows, int pages) {
    return '$cols × $rows 网格 · $pages 页';
  }

  @override
  String get previousPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String get addPageTooltip => '新增页(沿用本页网格)';

  @override
  String get deletePageTooltip => '删除本页';

  @override
  String deletePageTitle(int n) {
    return '删除第 $n 页?';
  }

  @override
  String deletePageContent(int count) {
    return '该页上的 $count 个控件将一并删除。';
  }

  @override
  String get templateSaved => '模版已保存。';

  @override
  String get preview => '预览';

  @override
  String get selectControlHint => '点击画布上的控件以编辑属性';

  @override
  String get controlsDock => '控件';

  @override
  String get propertiesDock => '属性';

  @override
  String collapseDock(String title) {
    return '收起$title';
  }

  @override
  String widthLabel(int n) {
    return '宽度:$n';
  }

  @override
  String get expand => '展开';

  @override
  String get collapse => '收起';

  @override
  String get syncHostTitle => '同步(本机作为服务端)';

  @override
  String get syncHostIntro => '手机与本机连接同一 WiFi,打开手机端「同步」页,输入以下地址和配对码:';

  @override
  String get thisMachineAddress => '本机地址';

  @override
  String get noLanAddress => '未发现局域网地址——请确认已连接 WiFi/网线';

  @override
  String get pairingCode => '配对码';

  @override
  String serverRunning(int port) {
    return '服务运行中(端口 $port)——保持本页面打开,在手机上点「同步」';
  }

  @override
  String get activityLog => '活动记录';

  @override
  String get waitingForPhone => '等待手机连接…';

  @override
  String syncServerStartFailed(String error) {
    return '同步服务启动失败:$error';
  }

  @override
  String get syncClientIntro => '在电脑上打开「同步」页面,然后填入其显示的地址和配对码。首次成功后会自动记住。';

  @override
  String get computerAddress => '电脑地址';

  @override
  String get addressHint => '例如 192.168.1.5';

  @override
  String get startSync => '开始同步';

  @override
  String get syncing => '同步中…';

  @override
  String get fillAddressAndCode => '请填写电脑地址和配对码';

  @override
  String syncFailedMsg(String error) {
    return '同步失败:$error';
  }

  @override
  String connectingTo(String hostPort) {
    return '连接 $hostPort…';
  }

  @override
  String get upToDate => '已是最新,无需同步';

  @override
  String syncDone(String parts) {
    return '同步完成:$parts';
  }

  @override
  String pulledTemplatesN(int n) {
    return '拉取模版 $n';
  }

  @override
  String pushedTemplatesN(int n) {
    return '推送模版 $n';
  }

  @override
  String pulledSurveysN(int n) {
    return '拉取调查表 $n';
  }

  @override
  String pushedSurveysN(int n) {
    return '推送调查表 $n';
  }

  @override
  String filesTransferredN(int n) {
    return '传输图片 $n';
  }

  @override
  String deletionsSyncedN(int n) {
    return '同步删除 $n';
  }

  @override
  String get syncFetchingManifest => '获取对方清单…';

  @override
  String get syncingTemplates => '同步模版…';

  @override
  String get syncingSurveys => '同步调查表…';

  @override
  String pullingItem(String id) {
    return '拉取 $id…';
  }

  @override
  String pushingItem(String id) {
    return '推送 $id…';
  }

  @override
  String protocolMismatch(int local, int remote) {
    return '协议版本不匹配(本机 v$local,对方 v$remote),请把两端应用升到同一版本';
  }

  @override
  String requestTimeout(String what) {
    return '$what超时——请确认电脑上的同步页面开着、两台设备在同一 WiFi,且地址无误';
  }

  @override
  String get wrongPairingCode => '配对码不正确';

  @override
  String requestFailed(String what, int status) {
    return '$what失败(HTTP $status)';
  }

  @override
  String get reqConnect => '连接';

  @override
  String get reqManifest => '获取清单';

  @override
  String get reqTombstones => '同步删除';

  @override
  String get reqDownloadImage => '下载图片';

  @override
  String get reqUploadImage => '上传图片';

  @override
  String get reqPull => '拉取数据';

  @override
  String get reqPush => '推送数据';

  @override
  String get camera => '拍照';

  @override
  String get gallery => '相册';

  @override
  String get clear => '清除';

  @override
  String get addPhoto => '添加照片';

  @override
  String get openMap => '打开地图';

  @override
  String atLeastNPhotos(int min, int count) {
    return '至少 $min 张,当前 $count';
  }

  @override
  String atMostNPhotos(int max, int count) {
    return '最多 $max 张,当前 $count';
  }

  @override
  String get satelliteTitle => '卫星示意图';

  @override
  String get saveSnapshot => '保存快照';

  @override
  String get mapHint => '点地图落钉 · 点钉编辑/删除 · 保存生成快照。';

  @override
  String get myLocation => '定位到当前位置';

  @override
  String get locateFailed => '定位失败——请确认已开启定位权限与 GPS';

  @override
  String get pinTitle => '图钉';

  @override
  String get pinLabelOptional => '标签(可选)';

  @override
  String get deviceNameHint => '设备名';

  @override
  String pageIndicator(int current, int total) {
    return '$current / $total';
  }
}

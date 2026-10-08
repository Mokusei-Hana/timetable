# 课程表（iPhone App）

把学校教务系统里的课表搬到你 iPhone 上，不用每次开浏览器登录。

- 主体是一张 **一周课表**：左边是节次，上面是周一到周日，课块按你学校的实际时间摆位置。
- 顶部左右箭头翻周，点中间的「第几周」可以直接跳到任意一周。
- 今天那一列会高亮；不在本周时会出现「回到本周」。
- 点任意一格课，弹出这门课的详细信息：老师、地点、时间、节次、周次、班级、考核方式。
- 底部可以切换 **五天 / 七天**；如果这周周末有课而你在五天模式，会提醒你。
- 课表数据是**离线**存在手机里的：不联网也能看，也不用把学号密码给 App。

---

## 一、文件都是干什么的

```
CourseTable/
├─ CourseTableApp.swift          程序入口，很短
├─ Models/TimetableModels.swift  数据长什么样（课程、大节、学期）
├─ Store/TimetableStore.swift   读数据、换周次、导入新数据
├─ Views/
│  ├─ TimetableView.swift        主界面：课表网格
│  ├─ CourseBlockView.swift      一格课长什么样
│  ├─ CourseDetailView.swift     点开一课之后的详情
│  ├─ WeekPickerView.swift       选周次的弹窗
│  └─ Theme.swift                颜色
└─ Resources/
   ├─ timetable.dat              ★ 你的课表数据（混淆过的，不是明文）
   └─ Assets.xcassets/           图标

project.yml                     给「云端打包」看的工程描述
.github/workflows/build-ipa.yml  云端打包的流程
tools/export-from-web.js         从学校网页导出课表数据的脚本
```

想改外观，改 `Views/` 和 `Theme.swift`；想换数据，只动 `timetable.dat`（用 `tools/pack-data.js` 生成）。

---

## 二、从改代码到装进手机

### 第 1 步：把这份代码传到 GitHub

先在 GitHub 网站上建一个**空仓库**（不要勾选自动生成 README），名字随便，比如 `timetable`。
然后在这个文件夹里执行（把地址换成你自己的）：

```bash
git init
git add .
git commit -m "课程表 App 第一版"
git branch -M main
git remote add origin https://github.com/你的用户名/timetable.git
git push -u origin main
```

> 建议用**公开仓库**：GitHub 免费账号跑苹果打包机器不扣时长。用私有仓库也能跑，但会消耗每月额度。

### 第 2 步：让云端帮你打包

代码推上去之后：

1. 打开仓库页面 → 上方 **Actions** 选项卡。
2. 左边选「打包成 iPhone 安装包」，右边点 **Run workflow** → 绿色按钮。
3. 等两三分钟，出现绿勾就成功了。
4. 点进那次运行，页面最下方 **Artifacts** 里下载 `CourseTable-ipa`，解开里面有 `CourseTable.ipa`。

> 如果报错说找不到 `macos-15` 机器，把 `.github/workflows/build-ipa.yml` 里的
> `runs-on: macos-15` 改成 `runs-on: macos-latest` 再跑一次。

### 第 3 步：装到 iPhone 上

打包出来的是**没签名**的安装包，还要用你自己的苹果账号签一次名才能装。两种做法：

**做法 A：免费（不用花钱，但要每 7 天续一次）**

1. 电脑上装 **iTunes** 和 **iCloud**，一定要去苹果官网下载安装版，**别用微软商店版**（商店版接口不一样，AltServer 连不上）。
2. 装 **AltServer**（altstore.io 下载），运行后它会缩在右下角托盘里。
3. iPhone 用数据线插在电脑上，手机上点「信任此电脑」。
4. 点托盘里的 AltServer 图标 → **Install AltStore** → 选你的 iPhone → 输入你的 Apple ID 和密码。
   - 这里只把苹果的「签名资格」用在你自己账号上，密码走的是苹果官方通道。
5. 手机上会出现 **AltStore**。用数据线再连一次电脑，打开 AltStore → 右上角 **+** → 选刚才下载的 `CourseTable.ipa`。
6. 第一次打开 App 会被拦，去 设置 → 通用 → VPN与设备管理 → 信任你的账号，就能开了。

之后手机和电脑在同一个 WiFi 下，AltServer 会自动帮你续签，基本不用管。
免费账号的限制：签名 7 天有效、同时最多 3 个自签 App、必须定期续。

**做法 B：花钱省心（苹果开发者账号，一年 688 元）**

有账号之后签名有效期是一年，不用每周续签，可以用 AltStore 装，也可以用其他签名工具装。适合确定要长期用的情况。

---

## 三、下学期课表变了怎么办

不用改代码，只换数据：

1. 在浏览器里登录你学校的教务系统，打开平时看课表的那个页面。
2. 按 F12 打开开发者工具 → 切到「控制台 / Console」。
3. 把 `tools/export-from-web.js` 里的整段代码粘进去，回车。
   会自动下载一个 `timetable.json`。
4. 两个选择：
   - **不重新打包**：把这个文件通过微信/网盘/AirDrop 发到手机，存进「文件」App，
     在课表 App 右上角菜单里点「导入课表文件」选它。立刻就更新了。
   - **重新打包**：把下载到的 `timetable.json` 放到仓库根目录，跑一句
     `node tools/pack-data.js`，它会把内容混淆后写成 `CourseTable/Resources/timetable.dat`。
     然后推上去再跑一次云端打包，重新装一次。

> 学期换了要注意：导出脚本里有一行 `const firstMonday = '2026-09-07';`
> 这是**第 1 周周一的日期**，用来算每一周对应的实际日期。换学期时改成新学期的第一周周一。

---

## 四、已知的限制

- **数据要手动更新一次**。App 不会自己登录学校系统去取数据（那样就得把学号密码存在手机上，
  而且登录时可能会出现图片验证码）。如果你以后想要自动更新，可以再加。
- 只做了主界面，**没有做主屏幕小组件**。
- 一行只能显示一门课。如果你的课表里**同一个时间段撞了两门课**，只会画出一个（学校网页也是这个行为）。
- 横竖屏都支持，但界面是照竖屏设计的。

---

## 五、常见问题

**打包报错找不到 bundle id？**
改 `project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER`，换成任何别的字符串（比如 `com.你的名字.coursetable2`）。

**装完 App 打不开、图标是灰的？**
说明签名过期或没信任证书。重新在 AltStore 里装一次，并去 设置 → 通用 → VPN与设备管理 里信任。

**App 里显示「还没读到课表数据」？**
说明自带的数据文件没被打进包里。检查 `CourseTable/Resources/timetable.json` 还在不在、格式有没有被改坏。

---

## 六、关于隐私

这个仓库里刻意不留能指向你本人的东西：

- **学校网址、校名、学校代码**：没有写进任何文件。导出脚本是粘在「已经登录的课表页」里运行的，
  它自己不需要知道学校地址。
- **课表数据**（里面有老师名字、班级、教室）：放在 `timetable.dat` 里，经过混淆处理，
  直接打开是一串乱码。
  ⚠️ 说清楚：这只是**不让人一眼看懂，不是加密**，懂技术的人仍然能还原。真要藏住，就别把它传上去。
- **App 的包名**用的是通用占位名，不含你的名字。
- **Swift 代码里出现的课程、老师、教室都是编造的示例**，跟你的真实课表无关。

数据文件的生成与自检：

```bash
node tools/pack-data.js          # 读根目录的 timetable.json，写出混淆后的 CourseTable/Resources/timetable.dat
node tools/pack-data.js --check  # 只检查现有的 timetable.dat 能不能正常还原
```

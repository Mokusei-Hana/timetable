# 课程表 · iPhone

SwiftUI 离线课程表，最低 iOS 17，无第三方依赖。

## 使用

- 顶部「今天」显示日期、教学周和当天课程数量，优先展示正在上课的课程，否则展示下一节。点「查看今日安排」查看当天全部课程。
- 周课表保留六个大节，按 `startBlock` 与 `span` 定位。左侧节次固定，右侧可横向滑动；同一时段有多门课程时并排展示，不互相覆盖。
- 左右箭头翻周，点周次标题直接跳转，点「本周」回到今天所在周。学期开始前显示第一周，结束后显示最后一周，并在今日区域说明状态。
- 「五天 / 七天」选择会保存。五天模式下遇到周末课程，会显示可点的提醒。
- 课程详情展示完整地点、教师、时间、节次、原始周次、班级、考核方式、总学时、课程编号和课程 ID。
- 右上角进入「数据管理」，使用文件选择器导入 JSON 或 DAT，或恢复自带课表。文件最大 10 MB。

## 数据与持久化

自带资源使用 `Bundle.main.url(forResource: "timetable", withExtension: "dat")` 读取。先解码明文 JSON；结构解码失败时再尝试移除空白后的 base64。base64 只是混淆，不是加密。

导入文件使用系统的安全作用域访问权限。格式检查通过后，原子写入 App 文稿目录中的 `timetable.json`，成功写入才替换当前课表。重启优先读取导入副本；损坏时尝试回退自带数据并提示。恢复操作先读取自带资源，再移除导入副本。

文件格式版本为 1，字段沿用项目说明第三节。`termStartDate` 为第一周周一，`day` 为 1 到 7，`startBlock` 为 0 到 5，`span` 不得跨出当天六个大节。按 `weeks` 过滤；`weeksText` 仅用于展示。`hours` 可为整数、null 或省略。课程 ID 必须唯一，`time` 为当天的 `HH:mm-HH:mm`。

App 不联网、不登录、不收集账号信息。选择云盘文件时，文件提供方可能需要先下载文件；离线使用时请选择已经下载到本机的文件。

## 文件结构

```text
project.yml
.github/workflows/build-ipa.yml
.gitignore
CourseTable/
  CourseTableApp.swift
  Models/Timetable.swift
  Store/TimetableStore.swift
  Views/
    ContentView.swift
    Design.swift
    WeekGrid.swift
    DetailViews.swift
  Resources/
    timetable.dat
    Assets.xcassets/
```

`Design.swift` 定义间距、浅深色配色、冲突课程布局和今日课程状态。`DetailViews.swift` 包含课程详情、今日安排、周次选择与数据管理。所有旧版 Swift 文件已由新实现替换或删除，旧数据导出、打包辅助脚本也已移除。

## 打包与安装

保留仓库现有 `project.yml`、`.github/workflows/build-ipa.yml`、`.gitignore` 和整个 `CourseTable/Resources/`，不提交 `.xcodeproj` 或手写 `Info.plist`。

推送到 `main` 后由原有 GitHub Actions 流程生成 Xcode 工程，并产出未签名的 `CourseTable.ipa`。也可以在 Actions 页面手动运行工作流，产物名为 `CourseTable-ipa`。安装到 iPhone 前仍需使用自己的 Apple ID 签名。

本次重写不执行本地编译或测试，也不等待云端构建结果。

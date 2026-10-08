// ============================================================
//  从学校教务系统网页里导出课表数据
// ============================================================
//
//  什么时候用：
//    下学期课表变了，想更新 App 里的数据时。
//
//  怎么用：
//    1. 在浏览器里登录你学校的教务系统，打开平时看课表的那个页面
//    2. 按 F12 打开开发者工具，切到「控制台 / Console」
//    3. 把下面整段代码粘进去，回车
//    4. 控制台会打印出课程清单，并自动下载一个 timetable.json
//    5. 想更新手机上的数据：把这个文件发到手机，用 App 里的「导入课表文件」选它，
//       立刻就能更新；想更新仓库里自带的那份：在仓库根目录跑 node tools/pack-data.js
//
//  注意：导出来的数据里只有课程本身，没有你的密码，也不含任何身份信息。
//
// ============================================================

(() => {
  const root = document.querySelector('.newTable');
  if (!root) {
    console.error('没找到课表页面。请确认地址是 #/new/tableIndex，并且课表已经显示出来。');
    return;
  }

  let node = root;
  while (node && !node.__vue__) node = node.parentElement;
  if (!node) {
    console.error('没能读到页面数据，刷新一次页面再试。');
    return;
  }
  const vm = node.__vue__;

  // 把「3-17」「3,5,7」这类写法展开成具体周次
  const parseWeeks = (text) => {
    const set = new Set();
    String(text || '').split(',').forEach((part) => {
      const piece = part.trim();
      const range = piece.match(/^(\d+)\s*-\s*(\d+)$/);
      if (range) {
        for (let w = +range[1]; w <= +range[2]; w++) set.add(w);
      } else if (/^\d+$/.test(piece)) {
        set.add(+piece);
      }
    });
    return [...set].sort((a, b) => a - b);
  };

  // 左侧那一列有哪几个大节
  const blocks = (vm.jcList || [])
    .filter((item) => item && item.XJMC)
    .map((item, i) => ({ index: i, label: item.DJMC, sections: item.XJMC }));

  // 一门一课地摊平。页面里的表格是「每天 × 每个起始小节」的格子，
  // 一个格子里可能挤着不止一门课，所以要再展开一层。
  const courses = [];
  (vm.list || []).forEach((daySlots, dayIndex) => {
    (daySlots || []).forEach((slot) => {
      if (!slot) return;
      const items = Array.isArray(slot) ? slot : [slot];
      items.forEach((c) => {
        if (!c || typeof c !== 'object') return;
        // classTime 是 5 位数字：[周几][起始小节][结束小节]，例如 10506 = 周1 第05到06节
        const code = String(c.classTime || '');
        const startSection = parseInt(code.slice(1, 3), 10);
        const endSection = parseInt(code.slice(3, 5), 10);
        // 一个大节 = 两小节，所以「第几个大节」要除以 2
        const startBlock = isNaN(startSection) ? 0 : Math.max(0, Math.floor((startSection - 1) / 2));
        const endBlock = isNaN(endSection) ? startBlock : Math.max(startBlock, Math.floor((endSection - 1) / 2));

        courses.push({
          id: c.jx0408id || `${dayIndex + 1}_${startBlock}_${c.courseName}`,
          name: c.courseName || '',
          teacher: c.teacherName || '',
          location: c.location || '',
          day: dayIndex + 1,
          startBlock: startBlock,
          span: endBlock - startBlock + 1,
          weeks: parseWeeks(c.classWeek),
          weeksText: c.classWeek || '',
          time: `${c.startTime || ''}-${c.endTIme || ''}`,
          className: c.ktmc || '',
          examType: c.khfs || '',
          hours: c.zxs,
          courseCode: c.kch || ''
        });
      });
    });
  });

  // 学期第一周的周一。页面上显示的是当前周的日期，倒推回去就是第一周。
  // 如果换了学期，这里要按实际情况改：把当前周显示的第一个日期往前推 (周次-1)*7 天。
  const firstMonday = '2026-09-07';

  const doc = {
    schemaVersion: 1,
    exportedAt: new Date().toISOString().slice(0, 10),
    term: (vm.args && vm.args.xnxq01id && vm.args.xnxq01id.dm) || '',
    termStartDate: firstMonday,
    totalWeeks: 22,
    blocks,
    courses
  };

  const text = JSON.stringify(doc, null, 2);
  console.log(`导出完成：${courses.length} 门课`);
  console.table(courses.map((c) => ({ 课程: c.name, 周几: c.day, 大节: c.startBlock + 1, 周次: c.weeksText, 地点: c.location })));

  const blob = new Blob([text], { type: 'application/json' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = 'timetable.json';
  link.click();

  return doc;
})();

// ============================================================
//  把明文的 timetable.json 转成混淆过的 timetable.dat
//  （timetable.dat 就是打包进 App 的那份自带数据）
// ============================================================
//
//  用法：在仓库根目录执行
//    node tools/pack-data.js          读 ./timetable.json，写出 CourseTable/Resources/timetable.dat
//    node tools/pack-data.js --check  只检查现有的 .dat 能不能正常还原
//
//  说清楚：这只是「不让人一眼看懂」，**不是加密**。
//  懂技术的人拿到文件仍然能还原出内容。真要藏住，就别传上去。
//
// ============================================================

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const source = path.join(root, 'timetable.json');
const target = path.join(root, 'CourseTable', 'Resources', 'timetable.dat');

/// 混淆：转成 base64，并每 120 个字符断一行，方便在仓库里翻看
function encode(text) {
  const base64 = Buffer.from(text, 'utf8').toString('base64');
  return base64.replace(/(.{120})/g, '$1\n') + '\n';
}

/// 还原：去掉所有空白后再解 base64
function decode(raw) {
  return Buffer.from(raw.replace(/\s+/g, ''), 'base64').toString('utf8');
}

if (process.argv.includes('--check')) {
  if (!fs.existsSync(target)) {
    console.error('找不到 ' + target);
    process.exit(1);
  }
  const doc = JSON.parse(decode(fs.readFileSync(target, 'utf8')));
  console.log('能正常还原：学期 ' + doc.term + '，' + doc.courses.length + ' 门课，' + doc.blocks.length + ' 个大节');
  process.exit(0);
}

if (!fs.existsSync(source)) {
  console.error('找不到 ' + source);
  console.error('先把从网页导出的 timetable.json 放到仓库根目录，再跑这个命令。');
  process.exit(1);
}

const text = fs.readFileSync(source, 'utf8');
const doc = JSON.parse(text); // 先确认是合法 JSON，免得把坏数据写进去

fs.writeFileSync(target, encode(text), 'utf8');
console.log('已写入 ' + path.relative(root, target));
console.log('学期 ' + doc.term + '，' + doc.courses.length + ' 门课，' + doc.blocks.length + ' 个大节');

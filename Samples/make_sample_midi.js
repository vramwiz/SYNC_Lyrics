// Run with Node.js to regenerate the demonstration MIDI and lyrics text.
const fs = require('fs');
const path = require('path');

const lines = [
  { text: '[朝](あさ)の[光](ひかり)が', lyrics: ['あ', 'さ', 'の', 'ひ', 'か', 'り', 'が'] },
  { text: '[窓](まど)を[照](て)らす', lyrics: ['ま', 'ど', 'を', 'て', 'ら', 'す'] },
  { text: '[星](ほし)のメロディ', lyrics: ['ほ', 'し', 'の', 'メ', 'ロ', 'ディ'] },
  { text: '[空](そら)へ[歌](うた)を[届](とど)けよう', lyrics: ['そ', 'ら', 'へ', 'う', 'た', 'を', 'と', 'ど', 'け', 'よ', 'う'] },
];

const ticksPerBeat = 480;
const noteLength = 420;
const beatLength = 480;
const lineGap = 480;
const scale = [0, 2, 4, 7, 9, 7, 4, 2];
const events = [];
let tick = 0;
let noteIndex = 0;

function variableLength(value) {
  const bytes = [value & 0x7f];
  while ((value >>= 7) > 0) bytes.unshift((value & 0x7f) | 0x80);
  return bytes;
}

function addEvent(at, order, bytes) {
  events.push({ at, order, bytes });
}

function meta(type, value) {
  const bytes = Buffer.from(value, 'utf8');
  return [0xff, type, ...variableLength(bytes.length), ...bytes];
}

addEvent(0, 0, meta(0x03, 'SYNC Lyrics Sample'));
addEvent(0, 1, [0xff, 0x51, 0x03, 0x07, 0xa1, 0x20]); // 120 BPM
addEvent(0, 2, [0xc0, 0x00]); // Acoustic piano

for (const line of lines) {
  for (const lyric of line.lyrics) {
    const pitch = 60 + scale[noteIndex % scale.length];
    addEvent(tick, 10, [0x90, pitch, 88]);
    addEvent(tick, 11, meta(0x05, lyric));
    addEvent(tick + noteLength, 20, [0x80, pitch, 0]);
    tick += beatLength;
    noteIndex++;
  }
  tick += lineGap;
}

events.sort((a, b) => a.at - b.at || a.order - b.order);
const track = [];
let previousTick = 0;
for (const event of events) {
  track.push(...variableLength(event.at - previousTick), ...event.bytes);
  previousTick = event.at;
}
track.push(...variableLength(tick - previousTick), 0xff, 0x2f, 0x00);

const header = Buffer.alloc(14);
header.write('MThd', 0, 'ascii');
header.writeUInt32BE(6, 4);
header.writeUInt16BE(0, 8); // Single track: lyrics and notes use track 0.
header.writeUInt16BE(1, 10);
header.writeUInt16BE(ticksPerBeat, 12);
const trackHeader = Buffer.alloc(8);
trackHeader.write('MTrk', 0, 'ascii');
trackHeader.writeUInt32BE(track.length, 4);

const directory = __dirname;
fs.writeFileSync(path.join(directory, 'SYNC_Lyrics_sample.mid'),
  Buffer.concat([header, trackHeader, Buffer.from(track)]));
fs.writeFileSync(path.join(directory, 'SYNC_Lyrics_sample_lyrics.txt'),
  lines.map(line => line.text).join('\r\n') + '\r\n', 'utf8');

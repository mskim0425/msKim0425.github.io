---
layout: page
icon: fas fa-wrench
order: 4
title: Dev Tools
description: Free online developer tools — JSON Formatter, Diff Checker and more. No data sent to any server, runs entirely in your browser.
---

<style>
  /* ===== Tab Navigation ===== */
  .tool-tabs {
    display: flex; gap: 0; margin-bottom: 16px;
    border-bottom: 2px solid #313244;
  }
  .tool-tab {
    padding: 10px 24px; font-size: 0.9rem; font-weight: 600;
    cursor: pointer; border: none; background: transparent;
    color: #6c7086; border-bottom: 2px solid transparent;
    margin-bottom: -2px; transition: all 0.2s;
    line-height: 1.3; text-align: center;
  }
  .tool-tab:hover { color: #cdd6f4; }
  .tool-tab.active { color: #89b4fa; border-bottom-color: #89b4fa; }
  .tool-tab .kr { display: block; font-size: 0.7rem; font-weight: 400; opacity: 0.6; }
  .tool-panel { display: none; }
  .tool-panel.active { display: block; }

  /* ===== Shared ===== */
  .tc { display: flex; flex-direction: column; gap: 12px; }
  .tool-row { display: flex; gap: 12px; }
  .tool-row > div { flex: 1; display: flex; flex-direction: column; }
  .tool-label { font-size: 0.85rem; font-weight: 600; margin-bottom: 6px; color: var(--text-color, #eee); }
  .tool-textarea {
    width: 100%; min-height: 350px; padding: 12px; border: 1px solid #444;
    border-radius: 8px; background: #1e1e2e; color: #cdd6f4; font-family: 'Fira Code', 'Consolas', monospace;
    font-size: 13px; line-height: 1.5; resize: vertical; tab-size: 2;
  }
  .tool-textarea:focus { outline: none; border-color: #89b4fa; box-shadow: 0 0 0 2px rgba(137,180,250,0.2); }
  .tool-textarea.error { border-color: #f38ba8; }
  .tool-btn-row { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
  .tool-btn {
    padding: 8px 20px; border: none; border-radius: 6px; font-size: 0.85rem; font-weight: 600;
    cursor: pointer; transition: all 0.2s; line-height: 1.3; text-align: center;
  }
  .tool-btn .kr { font-size: 0.72rem; font-weight: 400; opacity: 0.65; }
  .tool-btn-primary { background: #89b4fa; color: #1e1e2e; }
  .tool-btn-primary:hover { background: #74c7ec; }
  .tool-btn-secondary { background: #313244; color: #cdd6f4; border: 1px solid #444; }
  .tool-btn-secondary:hover { background: #45475a; }
  .tool-status {
    padding: 8px 14px; border-radius: 6px; font-size: 0.85rem; font-weight: 500;
    display: none; margin-top: 4px;
  }
  .tool-status.success { display: block; background: rgba(166,227,161,0.15); color: #a6e3a1; }
  .tool-status.error { display: block; background: rgba(243,139,168,0.15); color: #f38ba8; }
  .tool-status.info { display: block; background: rgba(137,180,250,0.15); color: #89b4fa; }
  .tool-stats { font-size: 0.8rem; color: #6c7086; margin-top: 4px; }
  .tool-divider { width: 1px; height: 22px; background: #444; margin: 0 4px; flex-shrink: 0; }

  /* ===== Diff specific ===== */
  .diff-output {
    padding: 16px; border-radius: 8px; background: #1e1e2e; border: 1px solid #444;
    font-family: 'Fira Code', 'Consolas', monospace; font-size: 13px; line-height: 1.7;
    overflow-x: auto; min-height: 200px; white-space: pre-wrap; word-break: break-word;
  }
  .diff-line { padding: 2px 8px; border-radius: 3px; margin: 1px 0; display: block; }
  .diff-added { background: rgba(166,227,161,0.15); color: #a6e3a1; }
  .diff-removed { background: rgba(243,139,168,0.15); color: #f38ba8; }
  .diff-same { color: #6c7086; }
  .diff-stats { display: flex; gap: 16px; margin-top: 8px; font-size: 0.85rem; }
  .diff-stats .added { color: #a6e3a1; }
  .diff-stats .removed { color: #f38ba8; }
  .diff-stats .unchanged { color: #6c7086; }
  .opt-btn {
    padding: 6px 14px; border-radius: 6px; font-size: 0.8rem; font-weight: 600;
    cursor: pointer; transition: all 0.2s; border: 1px solid #444;
    background: #313244; color: #f38ba8; line-height: 1.3;
  }
  .opt-btn:hover { background: #45475a; }
  .opt-btn.active { background: rgba(166,227,161,0.15); color: #a6e3a1; border-color: #a6e3a1; }
  .opt-btn .kr { font-size: 0.68rem; font-weight: 400; opacity: 0.65; }

  @media (max-width: 768px) { .tool-row { flex-direction: column; } }
</style>

<!-- ===== Tab Bar ===== -->
<div class="tool-tabs">
  <button class="tool-tab active" onclick="switchTab('json', this)">JSON Formatter<span class="kr">JSON 포맷터</span></button>
  <button class="tool-tab" onclick="switchTab('diff', this)">Diff Checker<span class="kr">텍스트 비교</span></button>
</div>

<!-- ===== JSON Formatter Panel ===== -->
<div id="panel-json" class="tool-panel active">
  <div class="tc">
    <div class="tool-btn-row">
      <button class="tool-btn tool-btn-primary" onclick="jsonFormat()">Format <span class="kr">정리</span></button>
      <button class="tool-btn tool-btn-secondary" onclick="jsonMinify()">Minify <span class="kr">압축</span></button>
      <button class="tool-btn tool-btn-secondary" onclick="jsonValidate()">Validate <span class="kr">검증</span></button>
      <button class="tool-btn tool-btn-secondary" onclick="jsonCopy()">Copy <span class="kr">복사</span></button>
      <button class="tool-btn tool-btn-secondary" onclick="jsonClear()">Clear <span class="kr">초기화</span></button>
      <span class="tool-divider"></span>
      <select id="indentSize" class="tool-btn tool-btn-secondary" style="appearance:auto;">
        <option value="2" selected>2 spaces</option>
        <option value="4">4 spaces</option>
        <option value="tab">Tab</option>
      </select>
    </div>
    <div id="jsonStatus" class="tool-status"></div>
    <div class="tool-row">
      <div>
        <span class="tool-label">INPUT</span>
        <textarea id="jsonInput" class="tool-textarea" placeholder='Paste your JSON here...&#10;&#10;Example:&#10;{"name":"SoThoughtful","type":"blog","topics":["dev","food","culture"]}'></textarea>
        <div id="jsonInputStats" class="tool-stats"></div>
      </div>
      <div>
        <span class="tool-label">OUTPUT</span>
        <textarea id="jsonOutput" class="tool-textarea" placeholder="Formatted JSON will appear here..." readonly></textarea>
        <div id="jsonOutputStats" class="tool-stats"></div>
      </div>
    </div>
  </div>
</div>

<!-- ===== Diff Checker Panel ===== -->
<div id="panel-diff" class="tool-panel">
  <div class="tc">
    <div class="tool-btn-row">
      <button class="tool-btn tool-btn-primary" onclick="diffRun()">Compare <span class="kr">비교</span></button>
      <button class="tool-btn tool-btn-secondary" onclick="diffSwap()">Swap <span class="kr">교체</span></button>
      <button class="tool-btn tool-btn-secondary" onclick="diffClear()">Clear <span class="kr">초기화</span></button>
      <span class="tool-divider"></span>
      <button class="opt-btn" id="btnWhitespace" onclick="diffToggleOpt('ignoreWhitespace')">Whitespace <span class="kr">공백 무시</span></button>
      <button class="opt-btn" id="btnCase" onclick="diffToggleOpt('ignoreCase')">Case <span class="kr">대소문자 무시</span></button>
    </div>
    <div id="diffStatus" class="tool-status"></div>
    <div class="tool-row">
      <div>
        <span class="tool-label">ORIGINAL</span>
        <textarea id="diffA" class="tool-textarea" placeholder="Paste original text here..."></textarea>
      </div>
      <div>
        <span class="tool-label">MODIFIED</span>
        <textarea id="diffB" class="tool-textarea" placeholder="Paste modified text here..."></textarea>
      </div>
    </div>
    <span class="tool-label">DIFF RESULT</span>
    <div id="diffOutput" class="diff-output"><span class="diff-same">Click "Compare" to see differences...</span></div>
    <div id="diffStats" class="diff-stats"></div>
  </div>
</div>

<script>
/* ===== Tab Switching ===== */
function switchTab(name, btn) {
  document.querySelectorAll('.tool-tab').forEach(function(t) { t.classList.remove('active'); });
  document.querySelectorAll('.tool-panel').forEach(function(p) { p.classList.remove('active'); });
  document.getElementById('panel-' + name).classList.add('active');
  btn.classList.add('active');
  history.replaceState(null, '', '#' + name);
}
(function() {
  var h = location.hash.replace('#','');
  if (h === 'diff' || h === 'json') {
    document.querySelectorAll('.tool-tab').forEach(function(t) { t.classList.remove('active'); });
    document.querySelectorAll('.tool-panel').forEach(function(p) { p.classList.remove('active'); });
    document.getElementById('panel-' + h).classList.add('active');
    document.querySelectorAll('.tool-tab')[h === 'diff' ? 1 : 0].classList.add('active');
  }
})();

/* ===== JSON Formatter ===== */
function jsonGetIndent() {
  var v = document.getElementById('indentSize').value;
  return v === 'tab' ? '\t' : Number(v);
}
function jsonShowStatus(msg, type) {
  var el = document.getElementById('jsonStatus');
  el.textContent = msg; el.className = 'tool-status ' + type;
}
function jsonUpdateStats() {
  var i = document.getElementById('jsonInput').value;
  var o = document.getElementById('jsonOutput').value;
  document.getElementById('jsonInputStats').textContent = i ? i.length + ' chars \u00b7 ' + i.split('\n').length + ' lines' : '';
  document.getElementById('jsonOutputStats').textContent = o ? o.length + ' chars \u00b7 ' + o.split('\n').length + ' lines' : '';
}
function jsonFormat() {
  var inp = document.getElementById('jsonInput'), out = document.getElementById('jsonOutput');
  try {
    out.value = JSON.stringify(JSON.parse(inp.value), null, jsonGetIndent());
    inp.classList.remove('error');
    jsonShowStatus('\u2713 Valid JSON \u2014 formatted successfully', 'success');
  } catch (e) {
    inp.classList.add('error'); out.value = '';
    jsonShowStatus('\u2717 Invalid JSON \u2014 ' + e.message, 'error');
  }
  jsonUpdateStats();
}
function jsonMinify() {
  var inp = document.getElementById('jsonInput'), out = document.getElementById('jsonOutput');
  try {
    out.value = JSON.stringify(JSON.parse(inp.value));
    inp.classList.remove('error');
    var saved = inp.value.length - out.value.length;
    jsonShowStatus('\u2713 Minified \u2014 saved ' + saved + ' chars (' + Math.round(saved/inp.value.length*100) + '% smaller)', 'success');
  } catch (e) {
    inp.classList.add('error');
    jsonShowStatus('\u2717 Invalid JSON \u2014 ' + e.message, 'error');
  }
  jsonUpdateStats();
}
function jsonValidate() {
  var inp = document.getElementById('jsonInput');
  try {
    var parsed = JSON.parse(inp.value);
    var type = Array.isArray(parsed) ? 'Array' : typeof parsed;
    var info = Array.isArray(parsed) ? parsed.length + ' items' : (typeof parsed === 'object' && parsed !== null ? Object.keys(parsed).length + ' keys' : '');
    inp.classList.remove('error');
    jsonShowStatus('\u2713 Valid JSON \u2014 Type: ' + type + (info ? ', ' + info : ''), 'success');
  } catch (e) {
    inp.classList.add('error');
    var match = e.message.match(/position (\d+)/);
    if (match) {
      var line = inp.value.substring(0, parseInt(match[1])).split('\n').length;
      jsonShowStatus('\u2717 Invalid JSON at line ' + line + ' \u2014 ' + e.message, 'error');
    } else {
      jsonShowStatus('\u2717 Invalid JSON \u2014 ' + e.message, 'error');
    }
  }
}
function jsonCopy() {
  var out = document.getElementById('jsonOutput');
  if (!out.value) { jsonShowStatus('Nothing to copy', 'error'); return; }
  navigator.clipboard.writeText(out.value).then(function() {
    jsonShowStatus('\u2713 Copied to clipboard', 'success');
  });
}
function jsonClear() {
  document.getElementById('jsonInput').value = '';
  document.getElementById('jsonOutput').value = '';
  document.getElementById('jsonInput').classList.remove('error');
  document.getElementById('jsonStatus').className = 'tool-status';
  jsonUpdateStats();
}
document.getElementById('jsonInput').addEventListener('keydown', function(e) {
  if (e.key === 'Tab') {
    e.preventDefault();
    var s = this.selectionStart;
    this.value = this.value.substring(0, s) + '  ' + this.value.substring(this.selectionEnd);
    this.selectionStart = this.selectionEnd = s + 2;
  }
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') jsonFormat();
});

/* ===== Diff Checker ===== */
var diffOpt = { ignoreWhitespace: false, ignoreCase: false };

function diffToggleOpt(key) {
  diffOpt[key] = !diffOpt[key];
  var btn = document.getElementById(key === 'ignoreWhitespace' ? 'btnWhitespace' : 'btnCase');
  if (diffOpt[key]) { btn.classList.add('active'); } else { btn.classList.remove('active'); }
}
function diffShowStatus(msg, type) {
  var el = document.getElementById('diffStatus');
  el.textContent = msg; el.className = 'tool-status ' + type;
}
function diffLcs(a, b) {
  var m = a.length, n = b.length;
  var dp = [];
  for (var x = 0; x <= m; x++) { dp[x] = []; for (var y = 0; y <= n; y++) dp[x][y] = 0; }
  for (var i = 1; i <= m; i++)
    for (var j = 1; j <= n; j++)
      dp[i][j] = a[i-1] === b[j-1] ? dp[i-1][j-1] + 1 : Math.max(dp[i-1][j], dp[i][j-1]);
  var result = [], ci = m, cj = n;
  while (ci > 0 && cj > 0) {
    if (a[ci-1] === b[cj-1]) { result.unshift({type:'same',value:a[ci-1]}); ci--; cj--; }
    else if (dp[ci-1][cj] > dp[ci][cj-1]) { result.unshift({type:'removed',value:a[ci-1]}); ci--; }
    else { result.unshift({type:'added',value:b[cj-1]}); cj--; }
  }
  while (ci > 0) { result.unshift({type:'removed',value:a[--ci]}); }
  while (cj > 0) { result.unshift({type:'added',value:b[--cj]}); }
  return result;
}
function diffRun() {
  var a = document.getElementById('diffA').value;
  var b = document.getElementById('diffB').value;
  if (!a && !b) { diffShowStatus('Paste text in both panels', 'info'); return; }
  var linesA = a.split('\n'), linesB = b.split('\n');
  var compA = linesA.map(function(l) { var s = l; if (diffOpt.ignoreWhitespace) s = s.trim().replace(/\s+/g,' '); if (diffOpt.ignoreCase) s = s.toLowerCase(); return s; });
  var compB = linesB.map(function(l) { var s = l; if (diffOpt.ignoreWhitespace) s = s.trim().replace(/\s+/g,' '); if (diffOpt.ignoreCase) s = s.toLowerCase(); return s; });
  var diff = diffLcs(compA, compB);
  var html = '', idxA = 0, idxB = 0, added = 0, removed = 0, unchanged = 0;
  var esc = function(s) { return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); };
  diff.forEach(function(d) {
    if (d.type === 'same') { html += '<span class="diff-line diff-same">  ' + esc(linesA[idxA]) + '</span>\n'; idxA++; idxB++; unchanged++; }
    else if (d.type === 'removed') { html += '<span class="diff-line diff-removed">- ' + esc(linesA[idxA]) + '</span>\n'; idxA++; removed++; }
    else { html += '<span class="diff-line diff-added">+ ' + esc(linesB[idxB]) + '</span>\n'; idxB++; added++; }
  });
  document.getElementById('diffOutput').innerHTML = html || '<span class="diff-same">No differences found!</span>';
  document.getElementById('diffStats').innerHTML = '<span class="added">+' + added + ' added</span><span class="removed">-' + removed + ' removed</span><span class="unchanged">' + unchanged + ' unchanged</span>';
  if (added === 0 && removed === 0) diffShowStatus('\u2713 Texts are identical', 'success');
  else diffShowStatus('Found ' + (added + removed) + ' differences', 'info');
}
function diffSwap() {
  var a = document.getElementById('diffA'), b = document.getElementById('diffB');
  var tmp = a.value; a.value = b.value; b.value = tmp;
}
function diffClear() {
  document.getElementById('diffA').value = '';
  document.getElementById('diffB').value = '';
  document.getElementById('diffOutput').innerHTML = '<span class="diff-same">Click "Compare" to see differences...</span>';
  document.getElementById('diffStats').innerHTML = '';
  document.getElementById('diffStatus').className = 'tool-status';
}
document.getElementById('diffA').addEventListener('keydown', function(e) { if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') diffRun(); });
document.getElementById('diffB').addEventListener('keydown', function(e) { if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') diffRun(); });
</script>

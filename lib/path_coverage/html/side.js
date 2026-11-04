// SPIKE: puts a file page's trees in a rail to the left of the
// code, each level with its site, and its path grids in a rail
// to the right. Each method whose paths are counted gets a bar
// on the code's right edge, from its def to its end, that opens
// its grid. One tree or grid is open at a time; opening one
// widens its rail, sliding the code away from it.
(function () {
  var code = document.querySelector('.code');
  if (!code) { return; }
  var box = code.parentElement;
  var trees = Array.prototype.slice.call(document.querySelectorAll('.tree'));
  var grids = Array.prototype.slice.call(document.querySelectorAll('.pathgrid'));
  var ccRail = document.createElement('div');
  ccRail.className = 'rail cc';
  var pcRail = document.createElement('div');
  pcRail.className = 'rail pc';
  // The code of each method's lines, from its def to its end. Each
  // is marked with its def's column, and its def line with its
  // text's length, so style.css draws the method's stripe and band
  // in character units, which the code's own layout keeps aligned
  // whatever else changes width.
  var methodSrcs = grids.map(function (grid) {
    var first = Number(grid.getAttribute('data-first'));
    var last = Number(grid.getAttribute('data-last'));
    var srcs = [];
    for (var n = first; n <= last; n++) {
      var src = srcOf(n);
      if (!src) { continue; }
      src.classList.add('in-method');
      src.setAttribute('data-method-status', grid.getAttribute('data-status'));
      src.style.setProperty('--def-col', grid.getAttribute('data-col'));
      srcs.push(src);
    }
    if (srcs.length > 0) {
      srcs[0].classList.add('def-line');
      srcs[0].style.setProperty('--def-end', srcs[0].textContent.length);
    }
    return srcs;
  });
  // Within each method, the number of each method's def line,
  // styled and acting as a site's button does within each
  // decision: in its method's status colour, opening its grid.
  var defs = grids.map(function (grid) {
    var number = document.getElementById('L' + grid.getAttribute('data-first'));
    number.classList.add('mdef');
    number.setAttribute('data-status', grid.getAttribute('data-status'));
    number.setAttribute('aria-expanded', 'false');
    return number;
  });

  // Within each method, the gutter left of the def of each method
  // with gaps holds arrows to the defs of the methods with gaps
  // before and after it, wrapping round at either end, as a site
  // with gaps has arrows to the other sites with gaps within each
  // decision. A covered method has none.
  var defLines = defs.filter(function (number) {
    return number.getAttribute('data-status') === 'gaps';
  }).map(function (number) { return number.getAttribute('data-line'); });
  defLines.forEach(function (line, i) {
    var count = defLines.length;
    var nav = document.getElementById('L' + line).closest('.line, .block').querySelector('.nav');
    nav.appendChild(methodArrow('prev', defLines[(i + count - 1) % count], '▲', 'Previous'));
    nav.appendChild(methodArrow('next', defLines[(i + 1) % count], '▼', 'Next'));
  });

  // An arrow, way prev or next, to the def on line, of a method
  // with gaps, showing glyph.
  function methodArrow(way, line, glyph, name) {
    var arrow = document.createElement('a');
    arrow.setAttribute('data-' + way, '');
    arrow.setAttribute('data-method', '');
    arrow.href = '#L' + line;
    arrow.setAttribute('aria-label', name + ' method with gaps, line ' + line);
    arrow.textContent = glyph;
    return arrow;
  }

  // The grid of the method whose def line holds element, when
  // methods are shown and its number is one of defs; else null.
  function defGridOf(element) {
    if (document.documentElement.getAttribute('data-mode') !== 'methods') { return null; }
    var row = element.closest('.line, .block');
    var number = row && row.querySelector('.lineno.mdef');
    return number ? grids[defs.indexOf(number)] : null;
  }

  // The line-number button that opens tree.
  function buttonOf(tree) {
    return document.querySelector('button.lnum[aria-controls="' + tree.id + '"]');
  }

  // The number span of line n.
  function lineno(n) {
    return document.getElementById('L' + n);
  }

  // Element's top, middle and bottom relative to within's top.
  function spot(element, within) {
    var rect = element.getBoundingClientRect();
    var top = rect.top - within.getBoundingClientRect().top;
    return { top: top, middle: top + rect.height / 2, bottom: top + rect.height };
  }

  // Opens panel, a tree or a grid, alone; null closes all. Any
  // path shown or pinned goes with the grid it was in. The box
  // drops any height a tree it held gave it.
  function openOnly(panel) {
    pin(null);
    clear();
    box.style.minHeight = '';
    trees.forEach(function (tree) {
      tree.hidden = tree !== panel;
      buttonOf(tree).setAttribute('aria-expanded', tree === panel ? 'true' : 'false');
    });
    grids.forEach(function (grid, i) {
      grid.hidden = grid !== panel;
      methodSrcs[i].forEach(function (src) { src.classList.toggle('method-open', grid === panel); });
      if (defs[i]) { defs[i].setAttribute('aria-expanded', grid === panel ? 'true' : 'false'); }
    });
    var side = !panel ? '' : panel.classList.contains('tree') ? 'cc' : 'pc';
    document.body.setAttribute('data-open', side);
    place();
    showWhole(panel);
  }

  // Scrolls the page just enough to show all of panel when it
  // is a tree, eg one opened from a line near the bottom of the
  // window, so its last rows are not below the fold. Its first
  // row stays level with its site's line.
  function showWhole(panel) {
    if (panel && panel.classList.contains('tree')) {
      panel.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }
  }

  // The narrowest the rail drags to, and the narrowest the code
  // beside it is left.
  var RAIL_MIN = 240;
  var CODE_MIN = 320;
  var RAIL_KEY = 'path_coverage.rail';

  // The divider between the rail and the code: dragging it sets
  // the rail's width, kept within RAIL_MIN and leaving CODE_MIN for
  // the code, and kept in the browser, where it can be, for the
  // next page.
  var divider = document.createElement('div');
  divider.className = 'divider';
  divider.setAttribute('role', 'separator');
  divider.setAttribute('aria-orientation', 'vertical');
  divider.title = 'Drag to share the width between paths and code';

  // Sets the rail to width pixels, kept within its bounds, and
  // places everything again around it.
  function setRail(width) {
    var most = box.getBoundingClientRect().width - CODE_MIN;
    var rail = Math.round(Math.max(RAIL_MIN, Math.min(most, width)));
    document.body.style.setProperty('--rail', rail + 'px');
    place();
    return rail;
  }

  divider.addEventListener('pointerdown', function (event) {
    divider.setPointerCapture(event.pointerId);
    divider.classList.add('dragging');
    document.body.classList.add('dragging');
    event.preventDefault();
  });
  divider.addEventListener('pointermove', function (event) {
    if (!divider.classList.contains('dragging')) { return; }
    setRail(event.clientX - box.getBoundingClientRect().left - 6);
  });
  divider.addEventListener('pointerup', function (event) {
    divider.releasePointerCapture(event.pointerId);
    divider.classList.remove('dragging');
    document.body.classList.remove('dragging');
    var rail = parseInt(document.body.style.getPropertyValue('--rail'), 10);
    try { window.localStorage.setItem(RAIL_KEY, String(rail)); } catch (e) { /* this page only */ }
  });

  // The rail's width kept from an earlier page, if any.
  function keptRail() {
    try { return parseInt(window.localStorage.getItem(RAIL_KEY), 10); } catch (e) { return NaN; }
  }

  // Sets an open tree's top so its first site's row, naming its
  // operator and path counts, is level with the first line of
  // its site's code. The box grows to hold the whole tree, as
  // one overflowing it would make the box scroll, sliding the
  // code's first lines out of sight.
  function placeTree(tree) {
    var block = buttonOf(tree).closest('.block');
    tree.style.top = '0px';
    var line = spot(block.querySelector('.src'), ccRail).middle;
    var row = spot(tree.querySelector('.site .row'), tree).middle;
    tree.style.top = (line - row) + 'px';
    box.style.minHeight = Math.ceil(spot(tree, box).bottom) + 'px';
  }

  // Sets an open grid's top level with its def, its calls row
  // first and its decision rows straight after, with no gaps;
  // each row's label names its decision's line.
  // When the def has scrolled up under the sticky header, the
  // grid slides down to stay just below it, but never past its
  // method's last line.
  function placeGrid(grid) {
    var rows = Array.prototype.slice.call(grid.querySelectorAll('.prow'));
    var first = spot(lineno(grid.getAttribute('data-first')), pcRail);
    var last = spot(lineno(grid.getAttribute('data-last')), pcRail);
    var height = rows[0].getBoundingClientRect().height + 2;
    var tall = rows.length * height + 2 * GRID_PAD;
    var head = document.querySelector('.head').getBoundingClientRect().bottom;
    var below = head - pcRail.getBoundingClientRect().top + 8;
    var top = first.middle - height / 2 - GRID_PAD;
    top = Math.max(top, Math.min(below, last.bottom - tall));
    grid.style.top = top + 'px';
    grid.style.height = tall + 'px';
    rows.forEach(function (row, i) {
      row.style.top = (GRID_PAD + i * height) + 'px';
    });
  }

  // The space above a grid's first row and below its last, as a
  // tree has, as style.css has it.
  var GRID_PAD = 10;

  // Places panel, a tree or a grid.
  function placeOne(panel) {
    if (panel.classList.contains('tree')) { placeTree(panel); } else { placeGrid(panel); }
  }

  // Places whichever tree or grid is open.
  function place() {
    trees.concat(grids).forEach(function (panel) {
      if (!panel.hidden) { placeOne(panel); }
    });
  }

  // The trees in one rail and the grids in another, both left of
  // the code, sharing one column, as a page shows one mode's only;
  // the divider after them, at any width kept from an earlier
  // page; nothing open.
  function beside() {
    box.insertBefore(ccRail, code);
    box.insertBefore(pcRail, code);
    box.appendChild(divider);
    trees.forEach(function (tree) { ccRail.appendChild(tree); });
    grids.forEach(function (grid) { pcRail.appendChild(grid); });
    var kept = keptRail();
    if (kept > 0) { setRail(kept); }
    openOnly(null);
  }

  // The code span of line n, whether a plain line or one of a
  // site's lines.
  function srcOf(n) {
    var number = lineno(n);
    if (!number) { return null; }
    var button = number.closest('button.lnum');
    if (!button) { return number.parentElement.querySelector('.src'); }
    var index = Array.prototype.indexOf.call(button.querySelectorAll('.lineno'), number);
    return button.closest('.block').querySelectorAll('.srcs > .src')[index];
  }

  // [first, last] from a "first,last" attribute, null for "".
  function span(text) {
    return text ? text.split(',').map(Number) : null;
  }

  var lit = [];
  var chips = [];
  var hot = [];

  // Lights the code of every line in span, [first, last].
  function light(lines) {
    if (!lines) { return; }
    for (var n = lines[0]; n <= lines[1]; n++) {
      var src = srcOf(n);
      if (src) { src.classList.add('lit'); lit.push(src); }
    }
  }

  // Puts a T or F chip in the gutter of line n's row.
  function chip(n, text) {
    var number = lineno(n);
    if (!number) { return; }
    var nav = number.closest('.line, .block').querySelector('.nav');
    nav.setAttribute('data-chip', text);
    chips.push(nav);
  }

  // Undoes the lights and chips of the last path shown.
  function clear() {
    lit.forEach(function (src) { src.classList.remove('lit'); });
    chips.forEach(function (nav) { nav.removeAttribute('data-chip'); });
    hot.forEach(function (cell) { cell.classList.remove('hot'); });
    lit = [];
    chips = [];
    hot = [];
  }

  // Shows in the code the path in column col of grid: for each
  // decision it makes, its if lit with the arm taken and its
  // end, T lighting the then arm, F the else (none without
  // one), and a T or F chip in the gutter. Decisions after a
  // path leaves early stay unlit.
  function show(grid, col) {
    clear();
    grid.querySelectorAll('.prow').forEach(function (row) {
      var cell = row.querySelectorAll('.pcell')[col];
      cell.classList.add('hot');
      hot.push(cell);
      if (row.classList.contains('calls') || cell.classList.contains('ended')) { return; }
      var taken = cell.classList.contains('true');
      light(span(row.getAttribute('data-head')));
      light(span(row.getAttribute(taken ? 'data-then' : 'data-else')));
      light(span(row.getAttribute('data-end')));
      chip(Number(row.getAttribute('data-line')), taken ? 'T' : 'F');
    });
  }

  // The pinned path, { grid, col }, shown whenever no other is
  // hovered; null when none is pinned.
  var pinned = null;

  // The grid and column of a cell.
  function columnOf(cell) {
    var cells = Array.prototype.slice.call(cell.parentElement.querySelectorAll('.pcell'));
    return { grid: cell.closest('.pathgrid'), col: cells.indexOf(cell) };
  }

  // Pins column, or unpins with null, outlining the pinned
  // column's cells.
  function pin(column) {
    document.querySelectorAll('.pcell.pinned').forEach(function (cell) {
      cell.classList.remove('pinned');
    });
    pinned = column;
    if (!column) { return; }
    column.grid.querySelectorAll('.prow').forEach(function (row) {
      row.querySelectorAll('.pcell')[column.col].classList.add('pinned');
    });
  }

  // Shows the pinned path, or nothing when none is pinned.
  function showPinned() {
    if (pinned) { show(pinned.grid, pinned.col); } else { clear(); }
  }

  pcRail.addEventListener('mouseover', function (event) {
    var cell = event.target.closest('.pathgrid .pcell');
    if (!cell) { return; }
    var column = columnOf(cell);
    show(column.grid, column.col);
  });
  pcRail.addEventListener('mouseleave', showPinned);

  // The code spans whose characters are marked, with the text
  // each had before.
  var markedSrcs = [];

  // The length of text's leading whitespace.
  function indentOf(text) {
    return text.match(/^\s*/)[0].length;
  }

  // Puts back every span marked as it was, site tints and all.
  function unmarkChars() {
    markedSrcs.forEach(function (entry) { entry.src.innerHTML = entry.html; });
    markedSrcs = [];
  }

  // Tints each site's own characters by its status, gaps when
  // any of its paths was never taken, rather than its whole
  // lines; where sites overlap, gaps wins.
  function tintSites() {
    var perLine = {};
    document.querySelectorAll('.tree .site').forEach(function (site) {
      var row = site.querySelector('.row[data-at]');
      if (!row) { return; }
      var at = row.getAttribute('data-at').split(',').map(Number);
      var gaps = site.querySelector('.count.never') !== null;
      for (var n = at[0]; n <= at[2]; n++) {
        (perLine[n] = perLine[n] || []).push({
          from: n === at[0] ? at[1] : -1, to: n === at[2] ? at[3] : Infinity,
          status: gaps ? 'gaps' : 'covered'
        });
      }
    });
    Object.keys(perLine).forEach(function (n) {
      var src = srcOf(n);
      if (!src) { return; }
      var text = src.textContent;
      var marks = text.split('').map(function () { return null; });
      perLine[n].forEach(function (span) {
        // A continuation line (from -1) is tinted from its first
        // character after the indent.
        var from = span.from < 0 ? indentOf(text) : span.from;
        for (var i = from; i < Math.min(span.to, text.length); i++) {
          if (marks[i] !== 'gaps') { marks[i] = span.status; }
        }
      });
      paint(src, function (i) { return marks[i]; }, function (status) {
        var mark = document.createElement('mark');
        mark.className = 'site';
        mark.setAttribute('data-status', status);
        return mark;
      });
    });
  }

  // Marks the characters from line l1, column c1 to line l2,
  // column c2, each line's part in a mark of its own.
  function markChars(l1, c1, l2, c2) {
    unmarkChars();
    for (var n = l1; n <= l2; n++) {
      var src = srcOf(n);
      if (!src) { continue; }
      var text = src.textContent;
      var from = n === l1 ? c1 : indentOf(text);
      var to = n === l2 ? c2 : text.length;
      markedSrcs.push({ src: src, html: src.innerHTML });
      paint(src, function (i) { return i >= from && i < to ? 'chars' : null; }, function () {
        var mark = document.createElement('mark');
        mark.className = 'chars';
        return mark;
      });
    }
    reveal(document.querySelectorAll('mark.chars'));
  }

  // The colour class of each of src's characters, the class of the
  // token span it is in, null for one in none.
  function tokensOf(src) {
    var tokens = [];
    var walker = document.createTreeWalker(src, NodeFilter.SHOW_TEXT);
    for (var node = walker.nextNode(); node; node = walker.nextNode()) {
      var parent = node.parentNode;
      var css = parent !== src && parent.tagName === 'SPAN' ? parent.className : null;
      for (var i = 0; i < node.length; i++) { tokens.push(css); }
    }
    return tokens;
  }

  // Rebuilds src's code, each run of characters keyAt gives one key
  // to in the element wrap makes of that key, the others bare, every
  // character still in a span of its token's colour class.
  function paint(src, keyAt, wrap) {
    var text = src.textContent;
    var tokens = tokensOf(src);
    src.textContent = '';
    var i = 0;
    while (i < text.length) {
      var j = i;
      var key = keyAt(i);
      while (j < text.length && keyAt(j) === key) { j++; }
      var box = key ? wrap(key) : src;
      appendTokens(box, text, tokens, i, j);
      if (key) { src.appendChild(box); }
      i = j;
    }
  }

  // Appends text's characters i to j to box, each run of one token
  // class in a span of that class, the rest bare.
  function appendTokens(box, text, tokens, i, j) {
    var k = i;
    while (k < j) {
      var m = k;
      while (m < j && tokens[m] === tokens[k]) { m++; }
      var part = text.slice(k, m);
      if (tokens[k]) {
        var span = document.createElement('span');
        span.className = tokens[k];
        span.textContent = part;
        box.appendChild(span);
      } else {
        box.appendChild(document.createTextNode(part));
      }
      k = m;
    }
  }

  // The width of the code pane's left columns (gap arrows and
  // line numbers), which code scrolls under.
  var GUTTER = 108;

  // Scrolls the code pane sideways so all of marks are in view,
  // their start kept in view when they are wider than the pane.
  function reveal(marks) {
    if (marks.length === 0) { return; }
    var pane = code.getBoundingClientRect();
    var left = Infinity;
    var right = -Infinity;
    marks.forEach(function (mark) {
      var rect = mark.getBoundingClientRect();
      left = Math.min(left, rect.left);
      right = Math.max(right, rect.right);
    });
    var shift = 0;
    if (right > pane.right - 8) { shift = right - pane.right + 8; }
    if (left - shift < pane.left + GUTTER) { shift = left - pane.left - GUTTER; }
    if (shift !== 0) { code.scrollBy({ left: shift, behavior: 'smooth' }); }
  }

  // Hovering a tree's row marks in the code the characters of
  // its operand, or of its operator's whole condition.
  var markedRow = null;
  ccRail.addEventListener('mouseover', function (event) {
    var row = event.target.closest('.tree .row[data-at]');
    if (row === markedRow) { return; }
    markedRow = row;
    if (!row) { unmarkChars(); return; }
    var at = row.getAttribute('data-at').split(',').map(Number);
    markChars(at[0], at[1], at[2], at[3]);
  });
  ccRail.addEventListener('mouseleave', function () {
    markedRow = null;
    unmarkChars();
  });

  // A click on a cell pins its column, or unpins it when it is
  // the one pinned.
  pcRail.addEventListener('click', function (event) {
    var cell = event.target.closest('.pathgrid .pcell');
    if (!cell) { return; }
    var column = columnOf(cell);
    var same = pinned && pinned.grid === column.grid && pinned.col === column.col;
    pin(same ? null : column);
    show(column.grid, column.col);
  });

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && pinned) { pin(null); clear(); }
  });

  // Opening one tree or grid closes the others; a click never
  // closes the one open, so the rail always shows one. Within each
  // method, a click on the number or code of a def line in defs
  // opens its method's grid, and no tree opens. Within each
  // decision, a click on a site's code acts as one on its button.
  // A gap arrow or jump opens the tree or grid of the line it jumps
  // to.
  document.addEventListener('click', function (event) {
    var methods = document.documentElement.getAttribute('data-mode') === 'methods';
    if (methods && !event.target.closest('a')) {
      var method = defGridOf(event.target);
      if (method) { openOnly(method); }
      return;
    }
    var line = event.target.closest('.line');
    if (line && !event.target.closest('button, a')) { return; }
    var block = event.target.closest('.block');
    if (block && !event.target.closest('button, a')) {
      block.querySelector('button[aria-controls]').click();
      return;
    }
    var button = event.target.closest('button.lnum');
    if (button) {
      openOnly(document.getElementById(button.getAttribute('aria-controls')));
      return;
    }
    var arrow = event.target.closest('.nav a, a.jump');
    if (arrow) {
      // A method's jump opens its grid; any other its line's tree.
      var kind = arrow.hasAttribute('data-method') ? 'paths-' : 'tree-';
      var target = document.getElementById(kind + arrow.hash.slice(2));
      if (target) { openOnly(target); }
    }
  });

  window.addEventListener('resize', place);
  // A page opening in a mode, or changing to one, opens a panel of
  // that mode in place of any the old mode had open.
  document.addEventListener('path-coverage-mode', function (event) {
    openForMode(event.detail.mode);
  });

  // On a page at a linked line, eg #L8, opens that line's own tree,
  // within each decision, or grid, within each method, when it has
  // one; otherwise opens mode's first gap, or, with none, its first
  // tree or grid, its line scrolled into view. Opens nothing only
  // on a page with no site, or no method, at all.
  function openForMode(mode) {
    var linked = /^#L(\d+)$/.exec(window.location.hash);
    var own = linked && panelOf(mode, linked[1]);
    if (own) { openOnly(own); return; }
    var jump = document.querySelector('.jump-list[data-jumps="' + mode + '"] a.jump');
    var first = (mode === 'methods' ? grids : trees)[0];
    var panel = jump ? panelOf(mode, jump.hash.slice(2)) : first;
    if (!panel) { openOnly(null); return; }
    var line = mode === 'methods' ? panel.getAttribute('data-first') : panel.id.replace('tree-', '');
    lineno(line).scrollIntoView({ block: 'center' });
    openOnly(panel);
  }

  // The panel of mode for line n: within each method the grid of the
  // method whose def is on n; within each decision the tree of the
  // site whose lines hold n. null when n has none.
  function panelOf(mode, n) {
    if (mode === 'methods') { return document.getElementById('paths-' + n); }
    var number = lineno(n);
    var button = number && number.closest('button.lnum');
    return button ? document.getElementById(button.getAttribute('aria-controls')) : null;
  }
  window.addEventListener('scroll', function () {
    grids.forEach(function (grid) { if (!grid.hidden) { placeGrid(grid); } });
  });

  // Puts two rows of jumps, each labelled Gaps and in line order, in
  // the header, one per mode, the page's CSS showing the mode's own:
  // within each decision, a jump to each site with gaps; within each
  // method, a jump to the def line of each method with gaps. A row
  // with no jumps keeps its place, hidden, so the header is the same
  // height in either mode.
  function jumpRows() {
    var lists = document.querySelectorAll('.jump-list');
    if (lists.length === 0) { return; }
    var jumps = Array.prototype.slice.call(document.querySelectorAll('a.jump[data-status="gaps"]'));
    jumps.sort(function (a, b) { return Number(a.textContent) - Number(b.textContent); });
    var row = lists[0];
    row.setAttribute('data-jumps', 'decisions');
    row.querySelector('.jump-label').textContent = 'Gaps';
    row.querySelectorAll('a.jump').forEach(function (jump) { jump.remove(); });
    jumps.forEach(function (jump) { row.appendChild(jump); });
    for (var i = 1; i < lists.length; i++) { lists[i].remove(); }
    var methods = row.cloneNode(false);
    methods.setAttribute('data-jumps', 'methods');
    methods.appendChild(row.querySelector('.jump-label').cloneNode(true));
    grids.forEach(function (grid) {
      if (grid.getAttribute('data-status') !== 'gaps') { return; }
      var first = grid.getAttribute('data-first');
      var jump = document.createElement('a');
      jump.className = 'jump';
      jump.setAttribute('data-status', 'gaps');
      jump.setAttribute('data-method', '');
      jump.href = '#L' + first;
      jump.textContent = first;
      methods.appendChild(jump);
    });
    row.parentNode.appendChild(methods);
    [row, methods].forEach(function (list) {
      if (!list.querySelector('a.jump')) { list.setAttribute('data-empty', ''); }
    });
  }

  // The cell kind that draws each of a tree's branch glyphs.
  var BRANCH_CELLS = { '│': 'v', '├': 't', '└': 'l', '─': 'h' };

  // Redraws each tree's branch glyphs as cells a whole row tall,
  // whose lines run edge to edge, so the branches join from row
  // to row as the glyphs, shorter than a row, cannot.
  function drawBranches() {
    document.querySelectorAll('.tree .branch').forEach(function (branch) {
      var text = branch.textContent;
      branch.setAttribute('aria-hidden', 'true');
      branch.textContent = '';
      text.split('').forEach(function (ch) {
        var cell = document.createElement('span');
        cell.className = 'bx';
        cell.setAttribute('data-bx', BRANCH_CELLS[ch] || 's');
        branch.appendChild(cell);
      });
    });
  }

  drawBranches();
  jumpRows();
  tintSites();
  beside();
  // A page with no mode toggle, as when methods are not measured,
  // shows decisions only; with one, the mode it opens in decides.
  if (!document.querySelector('.modes')) { openForMode('decisions'); }
})();

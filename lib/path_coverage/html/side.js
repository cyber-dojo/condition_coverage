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
  // whatever else changes width. A top card, of top-level lines,
  // is no method's, so has none.
  var methodSrcs = grids.map(function (grid) {
    if (isTop(grid)) { return []; }
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
      srcs[srcs.length - 1].classList.add('method-end');
    }
    return srcs;
  });
  // The rows of each method's body, after its def line to its end,
  // folded away within each method until its def's number opens
  // its card. A row holding its def line too, as a site's block
  // over both can, is never folded, so every def line shows. A top
  // card has no body, its lines being the top level's.
  var methodRows = grids.map(function (grid) {
    if (isTop(grid)) { return []; }
    var first = Number(grid.getAttribute('data-first'));
    var last = Number(grid.getAttribute('data-last'));
    var def = lineno(first).closest('.line, .block');
    var rows = [];
    for (var n = first + 1; n <= last; n++) {
      var number = lineno(n);
      var row = number && number.closest('.line, .block');
      if (row && row !== def && rows.indexOf(row) < 0) { rows.push(row); }
    }
    rows.forEach(function (row) { row.classList.add('method-folded'); });
    return rows;
  });

  // Within each method, the number of each method's def line,
  // styled and acting as a site's button does within each
  // decision: in its method's status colour, opening its grid. A
  // top card has none, its line's site button opening it.
  var defs = grids.map(function (grid) {
    if (isTop(grid)) { return null; }
    var number = document.getElementById('L' + grid.getAttribute('data-first'));
    number.classList.add('mdef');
    number.setAttribute('data-status', grid.getAttribute('data-status'));
    number.setAttribute('aria-expanded', 'false');
    return number;
  });

  // Within each method, the gutter left of the first line of each
  // card, a method's def or a top card's line, holds arrows to those
  // of the cards of its status before and after it, in line order,
  // wrapping round at either end: orange between the cards with
  // gaps, blue between the covered ones, as each number is.
  ['gaps', 'covered'].forEach(function (status) {
    var lines = grids.filter(function (grid) {
      return grid.getAttribute('data-status') === status;
    }).map(function (grid) { return grid.getAttribute('data-first'); })
      .sort(function (a, b) { return Number(a) - Number(b); });
    lines.forEach(function (line, i) {
      var count = lines.length;
      var nav = document.getElementById('L' + line).closest('.line, .block').querySelector('.nav');
      nav.appendChild(methodArrow('prev', lines[(i + count - 1) % count], '▲', 'Previous', status));
      nav.appendChild(methodArrow('next', lines[(i + 1) % count], '▼', 'Next', status));
    });
  });

  // Within each method, the button of each site outside every
  // method, at the top level or in a class's body, is marked loose:
  // as no method's card holds it, it opens its lines' top card, and
  // wears that card's status, from its paths, as a def's number
  // wears its method's, so its colour and its arrows agree.
  trees.forEach(function (tree) {
    var line = Number(tree.id.replace('tree-', ''));
    var inside = grids.some(function (grid) {
      return !isTop(grid) && Number(grid.getAttribute('data-first')) <= line &&
        line <= Number(grid.getAttribute('data-last'));
    });
    if (inside) { return; }
    var button = buttonOf(tree);
    button.classList.add('loose');
    button.setAttribute('data-status', document.getElementById('paths-' + line).getAttribute('data-status'));
  });

  // True for a top card, of sites outside every method.
  function isTop(grid) {
    return grid.classList.contains('top-level');
  }

  // An arrow, way prev or next, to line, the first of a card of
  // status, gaps or covered, showing glyph in that status's colour.
  function methodArrow(way, line, glyph, name, status) {
    var arrow = document.createElement('a');
    arrow.setAttribute('data-' + way, '');
    arrow.setAttribute('data-method', '');
    arrow.setAttribute('data-status', status);
    arrow.href = '#L' + line;
    var kind = status === 'gaps' ? 'with gaps' : 'covered';
    arrow.setAttribute('aria-label', name + ' card ' + kind + ', line ' + line);
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

  // Opens panel, a tree or a grid, alone; null closes all. A grid
  // opens its method's body, every other method's folded. Any
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
      if (isTop(grid)) {
        var button = document.querySelector('button.lnum[aria-controls="tree-' + grid.getAttribute('data-first') + '"]');
        button.setAttribute('aria-expanded', grid === panel ? 'true' : 'false');
      }
    });
    foldBodies(grids.indexOf(panel));
    var side = !panel ? '' : panel.classList.contains('tree') ? 'cc' : 'pc';
    document.body.setAttribute('data-open', side);
    place();
    stickDef();
    showWhole(panel);
  }

  // The def line's row of the method of grids[i].
  function defRow(i) {
    return lineno(grids[i].getAttribute('data-first')).closest('.line, .block');
  }

  // True when the method of grids[inner] is defined inside that of
  // grids[outer], eg a def inside a def.
  function nests(inner, outer) {
    var first = function (i) { return Number(grids[i].getAttribute('data-first')); };
    var last = function (i) { return Number(grids[i].getAttribute('data-last')); };
    return first(outer) < first(inner) && last(inner) <= last(outer);
  }

  // Folds every method's body but that of grids[open], none for -1:
  // its rows show, but for those of any method inside it, which stay
  // folded under their def lines; and its def line shows, with those
  // of the methods it is inside, though they lie in folded bodies.
  function foldBodies(open) {
    var shown = [];
    if (open >= 0) {
      shown = methodRows[open].filter(function (row) {
        return !grids.some(function (grid, j) {
          return nests(j, open) && methodRows[j].indexOf(row) >= 0;
        });
      });
      grids.forEach(function (grid, j) {
        if (j === open || nests(open, j)) { shown.push(defRow(j)); }
      });
    }
    methodRows.forEach(function (rows) {
      rows.forEach(function (row) { row.classList.toggle('method-folded', shown.indexOf(row) < 0); });
    });
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

  // Sets an open card's top so its title row is level with its
  // def; its rows, and any fold open among them, flow down it.
  // When the def has scrolled up under the sticky header, the
  // card slides down to stay just below it, but never past its
  // method's last line.
  function placeGrid(grid) {
    var first = spot(lineno(grid.getAttribute('data-first')), pcRail);
    var last = spot(lineno(grid.getAttribute('data-last')), pcRail);
    var title = spot(grid.querySelector('.prow'), grid).middle;
    var tall = grid.getBoundingClientRect().height;
    var head = document.querySelector('.head').getBoundingClientRect().bottom;
    var below = head - pcRail.getBoundingClientRect().top + 8;
    var top = first.middle - title;
    top = Math.max(top, Math.min(below, last.bottom - tall));
    grid.style.top = top + 'px';
  }

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
    var cell = event.target.closest('.pathgrid:not(.statements) .pcell');
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

  // Hovering a row of a tree, or of a fold in a statement card,
  // marks in the code the characters of its operand, or of its
  // operator's whole condition.
  var markedRow = null;
  [ccRail, pcRail].forEach(function (rail) {
    rail.addEventListener('mouseover', function (event) {
      var row = event.target.closest(':is(.tree, .fold) .row[data-at]');
      if (row === markedRow) { return; }
      markedRow = row;
      if (!row) { unmarkChars(); return; }
      var at = row.getAttribute('data-at').split(',').map(Number);
      markChars(at[0], at[1], at[2], at[3]);
    });
    rail.addEventListener('mouseleave', function () {
      markedRow = null;
      unmarkChars();
    });
  });

  // Hovering a statement's row in a card lights its line in the
  // code, scrolling the page only when that line is out of view.
  var litRow = null;
  pcRail.addEventListener('mouseover', function (event) {
    var row = event.target.closest('.statements .prow[data-line]:not(.calls)');
    if (row === litRow) { return; }
    litRow = row;
    clear();
    if (!row) { return; }
    var n = Number(row.getAttribute('data-line'));
    light([n, n]);
    // A number's scroll margin keeps it clear of the sticky header
    // and the def line stuck below it.
    lineno(n).scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  });
  pcRail.addEventListener('mouseleave', function () { litRow = null; });

  // A click on a site's row in a statement card unfolds that
  // site's tree in the row's place, folding up any other open; a
  // click on the row of the one open, or on its fold's first row,
  // which stands in the row's place, folds it back.
  pcRail.addEventListener('click', function (event) {
    if (event.target.closest('.fold .site > .row:first-child')) { unfold(null); return; }
    var row = event.target.closest('.statements .prow.site');
    var fold = row && row.nextElementSibling;
    if (!fold || !fold.classList.contains('fold')) { return; }
    unfold(fold.hidden ? fold : null);
  });

  // Shows fold alone, null folding them all up, the arrow of each
  // site's row pointing up while its fold shows; then places the
  // open card again, as its height has changed.
  function unfold(fold) {
    pcRail.querySelectorAll('.fold').forEach(function (each) {
      each.hidden = each !== fold;
      var arrow = each.previousElementSibling.querySelector('.fold-arrow');
      arrow.setAttribute('aria-expanded', String(each === fold));
    });
    place();
  }

  // A click on a cell pins its column, or unpins it when it is
  // the one pinned.
  pcRail.addEventListener('click', function (event) {
    var cell = event.target.closest('.pathgrid:not(.statements) .pcell');
    if (!cell) { return; }
    var column = columnOf(cell);
    var same = pinned && pinned.grid === column.grid && pinned.col === column.col;
    pin(same ? null : column);
    show(column.grid, column.col);
  });

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && pinned) { pin(null); clear(); }
  });

  // Opening one tree or grid closes the others, and a click never
  // closes the one open, so the rail always shows one. Within each
  // method, a click on the number or code of a def line in defs
  // opens its method's grid and body, and no tree opens; a loose
  // site's block, outside every method, opens its lines' top card
  // as a def line does its method's. Within each decision, a click
  // on a site's code acts as one on its button.
  // A gap arrow or jump opens the tree or grid of the line it jumps
  // to.
  document.addEventListener('click', function (event) {
    var methods = document.documentElement.getAttribute('data-mode') === 'methods';
    if (methods && !event.target.closest('a')) {
      var block = event.target.closest('.block');
      var loose = block && block.querySelector('button.lnum.loose');
      if (loose) {
        var line = loose.getAttribute('aria-controls').replace('tree-', '');
        openOnly(document.getElementById('paths-' + line));
        return;
      }
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

  // On a page at a linked line, eg #L8, opens that line's own tree,
  // within each decision, or card, within each method, when it has
  // one. Otherwise opens the mode's first gap, or, with none, its
  // first tree or card, its line scrolled into view, so one is
  // always open, every other method's body folded under its def
  // line; opens nothing only on a page with none at all.
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
  // innermost method whose def to end hold n, so a linked line in a
  // body is never left folded away; within each decision the tree of
  // the site whose lines hold n. null when n has none.
  function panelOf(mode, n) {
    if (mode === 'methods') {
      var holding = grids.filter(function (grid) {
        return Number(grid.getAttribute('data-first')) <= n && n <= Number(grid.getAttribute('data-last'));
      });
      return holding.length ? holding[holding.length - 1] : null;
    }
    var number = lineno(n);
    var button = number && number.closest('button.lnum');
    return button ? document.getElementById(button.getAttribute('aria-controls')) : null;
  }
  // Keeps the header, the open card and its def line in view as the
  // page scrolls, and as a pinch-zoomed view pans or zooms. Pinch
  // zoom pans a lens over the page, which CSS sticky ignores, so
  // the header is shifted down by the lens's pan; the card and def
  // line then follow the header's drawn bottom.
  function followView() {
    var pan = window.visualViewport ? window.visualViewport.offsetTop : 0;
    document.querySelector('.head').style.transform = pan > 0 ? 'translateY(' + pan + 'px)' : '';
    grids.forEach(function (grid) { if (!grid.hidden) { placeGrid(grid); } });
    stickDef();
  }
  window.addEventListener('scroll', followView);
  window.addEventListener('resize', stickDef);
  if (window.visualViewport) {
    window.visualViewport.addEventListener('scroll', followView);
    window.visualViewport.addEventListener('resize', followView);
  }

  // Keeps the def line of the open method in view: once it would
  // scroll up under the sticky header, it is shifted down to sit
  // just below it, over the body lines passing beneath, but never
  // past the method's last line. The code pane scrolls sideways, so
  // CSS sticky, which would stick within the pane, cannot do this.
  function stickDef() {
    grids.forEach(function (grid) {
      var row = lineno(grid.getAttribute('data-first')).closest('.line, .block');
      row.style.transform = '';
      row.classList.remove('def-stuck');
      if (grid.hidden) { return; }
      var head = document.querySelector('.head').getBoundingClientRect().bottom;
      var rect = row.getBoundingClientRect();
      var last = lineno(grid.getAttribute('data-last')).getBoundingClientRect();
      var shift = Math.min(head - rect.top, last.bottom - rect.bottom);
      if (shift <= 0) { return; }
      row.style.transform = 'translateY(' + shift + 'px)';
      row.classList.add('def-stuck');
    });
  }

  // Puts two rows of jumps, each labelled Gaps and in line order, in
  // the header, one per mode, the page's CSS showing the mode's own:
  // within each decision, a jump to each site with gaps; within each
  // method, a jump to the first line of each card with gaps, a
  // method's or a top card's, in line order. A row with no jumps
  // keeps its place, hidden, so the header is the same height in
  // either mode.
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
    var byLine = grids.slice().sort(function (a, b) {
      return Number(a.getAttribute('data-first')) - Number(b.getAttribute('data-first'));
    });
    byLine.forEach(function (grid) {
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

  // Redraws each tree's and fold's branch glyphs as cells a whole row tall,
  // whose lines run edge to edge, so the branches join from row
  // to row as the glyphs, shorter than a row, cannot.
  function drawBranches() {
    document.querySelectorAll(':is(.tree, .fold) .branch').forEach(function (branch) {
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
  // A page opens in the mode its html element names: within each
  // method when methods are measured, else within each decision.
  openForMode(document.documentElement.getAttribute('data-mode') || 'decisions');
})();

// Shows the paths of one mode only, within each decision or within
// each method, as the toggle's pressed button says: the page's html
// element names the mode, and the page's CSS hides the other's
// parts. Every link to another page of the report carries the mode,
// as ?mode=, so the page it opens shows the same one. Some browsers
// keep nothing shared between a report's local files, so the link is
// what carries it; the mode is also kept in the browser where it
// can be, for a page opened afresh. A page with neither opens within
// each decision.
(function () {
  var KEY = 'path_coverage.mode';
  var buttons = Array.prototype.slice.call(document.querySelectorAll('.modes button'));
  if (buttons.length === 0) { return; }
  var modes = buttons.map(function (button) { return button.getAttribute('data-mode'); });

  // The mode the link that opened this page carried, else the mode
  // last kept, else null.
  function given() {
    var match = /[?&]mode=([a-z]+)/.exec(window.location.search);
    if (match) { return match[1]; }
    try { return window.localStorage.getItem(KEY); } catch (e) { return null; }
  }

  // Keeps mode as the one picked, where the browser allows it.
  function keep(mode) {
    try { window.localStorage.setItem(KEY, mode); } catch (e) { /* carried by links only */ }
  }

  // href, a link to another page of the report, carrying mode: its
  // ?mode= replaced, before any #fragment.
  function carrying(href, mode) {
    var hash = href.indexOf('#');
    var fragment = hash < 0 ? '' : href.slice(hash);
    var page = (hash < 0 ? href : href.slice(0, hash)).replace(/\?.*$/, '');
    return page + '?mode=' + mode + fragment;
  }

  // Names mode on the html element, presses its button alone, and
  // makes every link to another of the report's pages carry it.
  function show(mode) {
    document.documentElement.setAttribute('data-mode', mode);
    buttons.forEach(function (button) {
      button.setAttribute('aria-pressed', String(button.getAttribute('data-mode') === mode));
    });
    document.querySelectorAll('a[href]').forEach(function (link) {
      var href = link.getAttribute('href');
      if (/^[a-z]+:|^#/.test(href) || !/\.html(\?|#|$)/.test(href)) { return; }
      link.setAttribute('href', carrying(href, mode));
    });
  }

  var start = given();
  show(modes.indexOf(start) >= 0 ? start : modes[0]);
  buttons.forEach(function (button) {
    button.addEventListener('click', function () {
      var mode = button.getAttribute('data-mode');
      show(mode);
      keep(mode);
      // Tells the page's other scripts, eg to close what the old
      // mode had open.
      document.dispatchEvent(new CustomEvent('path-coverage-mode', { detail: mode }));
    });
  });
})();

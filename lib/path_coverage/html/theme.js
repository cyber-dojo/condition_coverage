// Switches the page between light and dark as the title bar's theme
// button is pressed: the page's html element names the theme, and
// the page's CSS draws it. A page opens in the theme the link that
// opened it carried, as ?theme=, else the one last kept in the
// browser, else dark. Every link to another
// page of the report carries the theme, as some browsers keep
// nothing shared between a report's local files.
(function () {
  var KEY = 'path_coverage.theme';
  var button = document.querySelector('button.theme');
  if (!button) { return; }

  // The theme the opening link carried, else the one last kept,
  // else dark.
  function given() {
    var match = /[?&]theme=(light|dark)/.exec(window.location.search);
    if (match) { return match[1]; }
    try {
      var kept = window.localStorage.getItem(KEY);
      if (kept === 'light' || kept === 'dark') { return kept; }
    } catch (e) { /* nothing kept */ }
    return 'dark';
  }

  // Keeps theme as the one picked, where the browser allows it.
  function keep(theme) {
    try { window.localStorage.setItem(KEY, theme); } catch (e) { /* carried by links only */ }
  }

  // href, a link to another page of the report, with its ?name=
  // set to value, before any #fragment, its other ?settings kept.
  function carrying(href, name, value) {
    var hash = href.indexOf('#');
    var fragment = hash < 0 ? '' : href.slice(hash);
    var rest = hash < 0 ? href : href.slice(0, hash);
    var query = rest.indexOf('?');
    var page = query < 0 ? rest : rest.slice(0, query);
    var settings = query < 0 ? [] : rest.slice(query + 1).split('&').filter(function (pair) {
      return pair && pair.split('=')[0] !== name;
    });
    settings.push(name + '=' + value);
    return page + '?' + settings.join('&') + fragment;
  }

  // Names theme on the html element, labels the button with the
  // theme it switches to, and makes every link to another of the
  // report's pages carry theme.
  function show(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    var other = theme === 'dark' ? 'light' : 'dark';
    button.textContent = theme === 'dark' ? '☀' : '☾';
    button.setAttribute('aria-label', 'Switch to ' + other);
    button.title = 'Switch to ' + other;
    document.querySelectorAll('a[href]').forEach(function (link) {
      var href = link.getAttribute('href');
      if (/^[a-z]+:|^#/.test(href) || !/\.html(\?|#|$)/.test(href)) { return; }
      link.setAttribute('href', carrying(href, 'theme', theme));
    });
  }

  show(given());
  button.addEventListener('click', function () {
    var theme = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    show(theme);
    keep(theme);
  });
})();

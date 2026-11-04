// Shows the paths of one mode only, within each decision or within
// each method, as the toggle's pressed button says: the page's html
// element names the mode, and the page's CSS hides the other's
// parts. The mode is a setting, carried from page to page as
// settings.js has it; a page with none opens within each decision.
(function () {
  var settings = window.pathCoverageSettings;
  var buttons = Array.prototype.slice.call(document.querySelectorAll('.modes button'));
  if (buttons.length === 0) { return; }
  var modes = buttons.map(function (button) { return button.getAttribute('data-mode'); });

  // Names mode on the html element, presses its button alone, makes
  // every link carry it, and tells the page's other scripts, eg to
  // open that mode's first gap.
  function show(mode) {
    document.documentElement.setAttribute('data-mode', mode);
    buttons.forEach(function (button) {
      button.setAttribute('aria-pressed', String(button.getAttribute('data-mode') === mode));
    });
    settings.carry('mode', mode);
    document.dispatchEvent(new CustomEvent('path-coverage-mode', { detail: { mode: mode } }));
  }

  show(settings.given('mode', modes) || modes[0]);
  buttons.forEach(function (button) {
    button.addEventListener('click', function () {
      var mode = button.getAttribute('data-mode');
      show(mode);
      settings.keep('mode', mode);
    });
  });
})();

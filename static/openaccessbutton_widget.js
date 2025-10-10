// Accessible retirement shim for EmbedOA / Open Access Button widget
window.openaccessbutton_widget = function (opts) {
  opts = opts || {};
  var sel = opts.element || '#openaccessbutton_widget';
  var el = (typeof sel === 'string') ? document.querySelector(sel) : sel;
  if (!el) { 
    el = document.createElement('div');
    el.id = (typeof sel === 'string' && sel[0] === '#') ? sel.slice(1) : 'openaccessbutton_widget';
    (document.body || document.documentElement).appendChild(el);
  }

  el.innerHTML =
    '<div role="status" aria-live="polite" tabindex="-1">' +
      '<p><strong>The Open Access Button & EmbedOA are retiring.</strong> This widget no longer works.</p>' +
      '<p>Please contact this site’s administrator. ' +
      '<a href="https://blog.oa.works/sunsetting-the-open-access-button-instantill/" target="_blank" rel="noopener">Learn more</a>.</p>' +
    '</div>';

  if (opts.focus === true) el.firstElementChild.focus();
};

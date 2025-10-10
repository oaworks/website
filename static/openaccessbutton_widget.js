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

  // Build UTM-tracked blog URL with host in utm_content (for Simple Analytics)
  var url = "https://blog.oa.works/sunsetting-the-open-access-button-instantill/"
          + "?utm_source=embedoa&utm_medium=widget&utm_campaign=shutdown_notice"
          + "&utm_content=" + encodeURIComponent(location.hostname || '');

  el.innerHTML =
    '<div role="status" aria-live="polite" tabindex="-1">'
      + '<p><strong>The Open Access Button & EmbedOA are retiring.</strong> This widget no longer works.</p>'
      + '<p>Please contact this site’s administrator. '
      + '<a href="' + url + '" target="_blank" rel="noopener">Learn more</a>.</p>'
    + '</div>';

  if (opts.focus === true && el.firstElementChild) el.firstElementChild.focus();
};
// Accessible retirement shim for retired Open Access search widget
window.openaccessbutton_widget = function (opts) {
  opts = opts || {};
  var sel = opts.element || '#openaccessbutton_widget';
  var el = (typeof sel === 'string') ? document.querySelector(sel) : sel;
  if (!el) {
    el = document.createElement('div');
    el.id = (typeof sel === 'string' && sel[0] === '#') ? sel.slice(1) : 'openaccessbutton_widget';
    (document.body || document.documentElement).appendChild(el);
  }

  // Build blog URL with UTM parameters for Simple Analytics
  var url = "https://blog.oa.works/sunsetting-the-open-access-button-instantill/"
          + "?utm_source=embedoa&utm_medium=widget&utm_campaign=shutdown_notice"
          + "&utm_content=" + encodeURIComponent(location.hostname || '');

  el.innerHTML =
    '<div role="status" aria-live="polite" tabindex="-1" style="font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; font-size: 16px; line-height: 1.5;">'
      + '<p><strong>This search tool (the “Open Access Button”) is no longer available.</strong></p>'
      + '<p>Please contact your library or this site’s administrator. '
      + '<a href="' + url + '" target="_blank" rel="noopener">Learn more</a>.</p>'
    + '</div>';

  if (opts.focus === true && el.firstElementChild) el.firstElementChild.focus();
};
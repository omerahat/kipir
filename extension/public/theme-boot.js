// Applies the saved appearance before first paint (no theme flash). Classic script: CSP-safe, no inline code.
try {
  var a = localStorage.getItem('kipir.appearance');
  if (a === 'light' || a === 'dark') document.documentElement.dataset.theme = a;
} catch { /* storage unavailable: follow the system appearance */ }

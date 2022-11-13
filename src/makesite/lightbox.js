document.addEventListener('keydown', (e) => {
  let h =  window.location.hash;
  if (h == "") { return }

  let sel = null;
  switch (e.key) { 
  case "ArrowLeft": sel = ".lbprev"; break;
  case "ArrowRight": sel = ".lbnext"; break;
  case "Escape": sel = ".lbclose"; break;
  default: return
  }

  let targ = document.getElementById(h.substr(1));
  if (!targ) { return }
  let n = targ.querySelector(sel);
  if (!n) { return }
  n.click();
});

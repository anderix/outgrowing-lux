document.querySelectorAll("a[href^=\"http\"]").forEach((link) => {
  if (link.host !== location.host) link.target = "_blank";
});

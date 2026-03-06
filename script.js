const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    });
  },
  {
    threshold: 0.16,
    rootMargin: "0px 0px -5% 0px",
  }
);

document.querySelectorAll("[data-reveal]").forEach((element, index) => {
  element.style.transitionDelay = `${Math.min(index * 70, 280)}ms`;
  observer.observe(element);
});

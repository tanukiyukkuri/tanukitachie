const analyticsConfig = window.ANALYTICS_CONFIG || {};
const analyticsState = {
  initialized: false,
  sectionViews: new Set(),
  scrollMilestones: new Set(),
};

const sendAnalyticsEvent = (eventName, params = {}) => {
  const payload = {
    page_location: window.location.href,
    page_title: document.title,
    ...params,
  };

  if (analyticsConfig.debug) {
    payload.debug_mode = true;
  }

  if (typeof window.gtag === "function") {
    window.gtag("event", eventName, payload);
  }

  if (analyticsConfig.debug) {
    console.debug("[analytics]", eventName, payload);
  }
};

const trackScrollMilestone = (milestone) => {
  if (analyticsState.scrollMilestones.has(milestone)) {
    return;
  }

  analyticsState.scrollMilestones.add(milestone);
  sendAnalyticsEvent("scroll_depth", {
    percent_scrolled: milestone,
  });
};

const trackSectionView = (sectionId, sectionName) => {
  if (analyticsState.sectionViews.has(sectionId)) {
    return;
  }

  analyticsState.sectionViews.add(sectionId);
  sendAnalyticsEvent("section_view", {
    section_id: sectionId,
    section_name: sectionName,
  });
};

if (!analyticsState.initialized) {
  analyticsState.initialized = true;
}

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

const sampleToggles = document.querySelectorAll("[data-sample-set]");
const sampleImages = document.querySelectorAll(".sample-image[data-normal][data-mirror]");
const preview = document.getElementById("imagePreview");
const previewContent = document.getElementById("imagePreviewContent");
const previewClose = document.querySelector(".image-preview-close");
const previewPrev = document.querySelector(".image-preview-prev");
const previewNext = document.querySelector(".image-preview-next");
let currentPreviewIndex = -1;
let currentSampleSet = "normal";

const applySampleSet = (setName) => {
  currentSampleSet = setName;

  sampleToggles.forEach((toggle) => {
    toggle.classList.toggle("is-active", toggle.dataset.sampleSet === setName);
  });

  sampleImages.forEach((image) => {
    image.src = setName === "mirror" ? image.dataset.mirror : image.dataset.normal;
  });

  if (currentPreviewIndex !== -1) {
    const image = sampleImages[currentPreviewIndex];
    previewContent.src = setName === "mirror" ? image.dataset.mirror : image.dataset.normal;
    previewContent.alt = image.alt;
  }
};

sampleToggles.forEach((button) => {
  button.addEventListener("click", () => {
    applySampleSet(button.dataset.sampleSet);
    sendAnalyticsEvent("sample_toggle", {
      sample_set: button.dataset.sampleSet,
      toggle_context: button.dataset.previewToggle === "true" ? "preview" : "gallery",
    });
  });
});

const closePreview = () => {
  preview.classList.add("is-hidden");
  preview.setAttribute("aria-hidden", "true");
  previewContent.src = "";
  previewContent.alt = "";
  currentPreviewIndex = -1;
};

const openPreview = (index) => {
  const image = sampleImages[index];
  if (!image) {
    return;
  }
  currentPreviewIndex = index;
  previewContent.src = currentSampleSet === "mirror" ? image.dataset.mirror : image.dataset.normal;
  previewContent.alt = image.alt;
  preview.classList.remove("is-hidden");
  preview.setAttribute("aria-hidden", "false");
  sendAnalyticsEvent("sample_preview_open", {
    sample_index: index + 1,
    sample_alt: image.alt,
    sample_set: currentSampleSet,
  });
};

const movePreview = (direction) => {
  if (currentPreviewIndex === -1) {
    return;
  }
  const nextIndex = (currentPreviewIndex + direction + sampleImages.length) % sampleImages.length;
  openPreview(nextIndex);
};

sampleImages.forEach((image) => {
  image.addEventListener("click", () => {
    openPreview(Array.from(sampleImages).indexOf(image));
  });
});

preview.addEventListener("click", (event) => {
  if (event.target === preview) {
    closePreview();
  }
});

previewClose.addEventListener("click", closePreview);
previewPrev.addEventListener("click", () => movePreview(-1));
previewNext.addEventListener("click", () => movePreview(1));

document.addEventListener("keydown", (event) => {
  if (preview.classList.contains("is-hidden")) {
    return;
  }
  if (event.key === "Escape") {
    closePreview();
  } else if (event.key === "ArrowLeft") {
    movePreview(-1);
  } else if (event.key === "ArrowRight") {
    movePreview(1);
  }
});

const trackedLinks = document.querySelectorAll("[data-track-click]");
const interstitialTriggers = document.querySelectorAll("[data-interstitial-target]");
const downloadModal = document.getElementById("downloadModal");
const downloadCountdown = document.getElementById("downloadCountdown");
const downloadCountdownLabel = document.getElementById("downloadCountdownLabel");
const downloadCloseButton = document.getElementById("downloadCloseButton");
const downloadAdLink = document.getElementById("downloadAdLink");
let downloadTimerId = null;
let countdownTimerId = null;
let downloadRemainingSeconds = 5;
let activeInterstitialTarget = null;

trackedLinks.forEach((element) => {
  element.addEventListener("click", () => {
    sendAnalyticsEvent("select_content", {
      content_type: "link",
      content_id: element.dataset.trackClick,
      link_url: element.href || "",
      link_text: element.textContent.trim(),
    });
  });
});

if (downloadAdLink) {
  if (analyticsConfig.sponsorUrl) {
    downloadAdLink.href = analyticsConfig.sponsorUrl;
  } else {
    downloadAdLink.removeAttribute("href");
    downloadAdLink.removeAttribute("target");
    downloadAdLink.classList.add("is-disabled");
  }

  downloadAdLink.addEventListener("click", (event) => {
    if (!analyticsConfig.sponsorUrl) {
      event.preventDefault();
      return;
    }

    event.preventDefault();
    window.open(analyticsConfig.sponsorUrl, "_blank", "noopener,noreferrer");
  });
}

const resetDownloadCountdown = () => {
  downloadRemainingSeconds = 5;
  if (downloadCountdown) {
    downloadCountdown.textContent = String(downloadRemainingSeconds);
  }
};

const clearDownloadTimers = () => {
  window.clearTimeout(downloadTimerId);
  window.clearInterval(countdownTimerId);
  downloadTimerId = null;
  countdownTimerId = null;
};

const closeDownloadModal = () => {
  if (!downloadModal) {
    return;
  }

  clearDownloadTimers();
  resetDownloadCountdown();
  activeInterstitialTarget = null;
  downloadModal.classList.add("is-hidden");
  downloadModal.setAttribute("aria-hidden", "true");
};

const startInterstitialNavigation = () => {
  if (!activeInterstitialTarget) {
    return;
  }

  const target = activeInterstitialTarget;
  clearDownloadTimers();
  closeDownloadModal();

  if (target.dataset.interstitialTarget === "download") {
    sendAnalyticsEvent("file_download", {
      file_name: "tanuki-yukkuri.zip",
      file_extension: "zip",
      link_url: target.href,
    });
    window.location.href = target.href;
    return;
  }

  sendAnalyticsEvent("interstitial_navigation", {
    destination_type: target.dataset.interstitialTarget || "",
    link_url: target.href,
  });
  window.location.href = target.href;
};

const openDownloadModal = (trigger) => {
  if (!downloadModal) {
    return;
  }

  activeInterstitialTarget = trigger;
  clearDownloadTimers();
  resetDownloadCountdown();
  if (downloadCountdownLabel) {
    downloadCountdownLabel.textContent = trigger.dataset.interstitialLabel || "ダウンロードします";
  }
  downloadModal.classList.remove("is-hidden");
  downloadModal.setAttribute("aria-hidden", "false");
  sendAnalyticsEvent("download_interstitial_view", {
    destination: trigger ? trigger.href : "",
    destination_type: trigger ? trigger.dataset.interstitialTarget || "" : "",
  });

  countdownTimerId = window.setInterval(() => {
    downloadRemainingSeconds -= 1;
    if (downloadCountdown) {
      downloadCountdown.textContent = String(Math.max(downloadRemainingSeconds, 0));
    }
  }, 1000);

  downloadTimerId = window.setTimeout(() => {
    startInterstitialNavigation();
  }, 5000);
};

interstitialTriggers.forEach((trigger) => {
  trigger.addEventListener("click", (event) => {
    event.preventDefault();
    openDownloadModal(trigger);
  });
});

if (downloadCloseButton) {
  downloadCloseButton.addEventListener("click", () => {
    sendAnalyticsEvent("download_interstitial_close", {
      destination: activeInterstitialTarget ? activeInterstitialTarget.href : "",
      destination_type: activeInterstitialTarget ? activeInterstitialTarget.dataset.interstitialTarget || "" : "",
    });
    closeDownloadModal();
  });
}

if (downloadModal) {
  downloadModal.addEventListener("click", (event) => {
    if (event.target === downloadModal) {
      sendAnalyticsEvent("download_interstitial_close", {
        destination: activeInterstitialTarget ? activeInterstitialTarget.href : "",
        destination_type: activeInterstitialTarget ? activeInterstitialTarget.dataset.interstitialTarget || "" : "",
      });
      closeDownloadModal();
    }
  });
}

window.addEventListener(
  "scroll",
  () => {
    const scrollTop = window.scrollY;
    const scrollableHeight = document.documentElement.scrollHeight - window.innerHeight;

    if (scrollableHeight <= 0) {
      trackScrollMilestone(100);
      return;
    }

    const percentScrolled = Math.round((scrollTop / scrollableHeight) * 100);

    [25, 50, 75, 100].forEach((milestone) => {
      if (percentScrolled >= milestone) {
        trackScrollMilestone(milestone);
      }
    });
  },
  { passive: true }
);

const sectionObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) {
        return;
      }

      const section = entry.target;
      trackSectionView(section.id, section.dataset.sectionName || section.id);
      sectionObserver.unobserve(section);
    });
  },
  {
    threshold: 0.45,
  }
);

document.querySelectorAll("section[id]").forEach((section) => {
  sectionObserver.observe(section);
});

document.addEventListener("keydown", (event) => {
  if (!downloadModal || downloadModal.classList.contains("is-hidden")) {
    return;
  }

  if (event.key === "Escape") {
    sendAnalyticsEvent("download_interstitial_close", {
      destination: activeInterstitialTarget ? activeInterstitialTarget.href : "",
      destination_type: activeInterstitialTarget ? activeInterstitialTarget.dataset.interstitialTarget || "" : "",
    });
    closeDownloadModal();
  }
});

const MODE_KEY = 'pi-v3-theme-mode';
let mediaQuery = null;
let mediaHandler = null;

function getRoot() {
  return document.querySelector('.pi-v3');
}

function disableAuto() {
  if (mediaQuery && mediaHandler) {
    mediaQuery.removeEventListener('change', mediaHandler);
  }
  mediaQuery = null;
  mediaHandler = null;
}

function enableAuto(root) {
  disableAuto();
  mediaQuery = window.matchMedia('(prefers-color-scheme: light)');
  mediaHandler = (event) => {
    root.classList.toggle('is-light', event.matches);
  };
  mediaQuery.addEventListener('change', mediaHandler);
  root.classList.toggle('is-light', mediaQuery.matches);
  root.classList.remove('force-dark');
}

export const Theme = {
  setMode(mode) {
    const root = getRoot();
    if (!root) return;
    disableAuto();
    root.classList.remove('is-light', 'force-dark');

    switch (mode) {
      case 'light':
        root.classList.add('is-light');
        break;
      case 'dark':
        root.classList.add('force-dark');
        break;
      case 'auto':
      default:
        enableAuto(root);
        break;
    }

    try {
      localStorage.setItem(MODE_KEY, mode);
    } catch {
      /* no-op */
    }
  },

  applyQuickKnobs({ brand, radius, density } = {}) {
    const root = getRoot();
    if (!root) return;
    if (brand) {
      root.style.setProperty('--pi-brand', brand);
    }
    if (radius != null) {
      root.style.setProperty('--pi-radius', `${radius}px`);
    }
    if (density != null) {
      root.setAttribute('data-density', String(density));
    }
  },

  initFromStorage() {
    const root = getRoot();
    if (!root) return 'dark';
    let mode = 'dark';
    try {
      const stored = localStorage.getItem(MODE_KEY);
      if (stored) mode = stored;
    } catch {
      /* ignore */
    }
    this.setMode(mode);
    return mode;
  }
};

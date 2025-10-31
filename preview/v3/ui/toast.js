const HOST_ID = 'pi-v3-toasts';
const DEFAULT_TTL = 4000;

const queue = [];
let counter = 0;

function host() {
  let el = document.getElementById(HOST_ID);
  if (!el) {
    el = document.createElement('div');
    el.id = HOST_ID;
    el.setAttribute('aria-live', 'polite');
    el.setAttribute('aria-atomic', 'true');
    document.body.appendChild(el);
  }
  return el;
}

function render() {
  const container = host();
  container.innerHTML = '';
  queue.forEach((toast) => {
    const el = document.createElement('div');
    el.className = `pi-toast pi-toast--${toast.kind}`;
    el.setAttribute('role', 'status');

    const message = document.createElement('p');
    message.className = 'pi-toast__message';
    message.textContent = toast.message;

    const dismiss = document.createElement('button');
    dismiss.className = 'pi-toast__dismiss';
    dismiss.type = 'button';
    dismiss.textContent = '×';
    dismiss.setAttribute('aria-label', 'Dismiss notification');
    dismiss.addEventListener('click', () => remove(toast.id));

    el.appendChild(message);
    el.appendChild(dismiss);
    container.appendChild(el);
  });
}

function remove(id) {
  const index = queue.findIndex((item) => item.id === id);
  if (index === -1) return;
  queue.splice(index, 1);
  render();
}

function push(kind, message, options = {}) {
  if (!message) return;
  const id = `toast-${Date.now()}-${counter++}`;
  const ttl = typeof options.ttl === 'number' ? options.ttl : DEFAULT_TTL;
  queue.push({ id, kind, message });
  render();
  if (ttl > 0) {
    window.setTimeout(() => remove(id), ttl);
  }
}

export const toast = {
  info(message, options) {
    push('info', message, options);
  },
  success(message, options) {
    push('success', message, options);
  },
  error(message, options) {
    push('error', message, options);
  }
};

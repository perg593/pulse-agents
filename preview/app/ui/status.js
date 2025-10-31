export function addStatus(listEl, message, state = 'pending') {
  const li = document.createElement('li');
  li.textContent = message;
  li.classList.add(`status--${state}`);
  listEl.appendChild(li);
  return li;
}

export function clearStatus(listEl) {
  listEl.innerHTML = '';
}

export function updateStatus(li, message, state) {
  if (!li) return;
  li.textContent = message;
  ['status--pending', 'status--ready', 'status--error'].forEach((cls) => li.classList.remove(cls));
  li.classList.add(`status--${state}`);
}

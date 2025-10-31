export function renderTriggers(container, triggers, { onTrigger } = {}) {
  container.innerHTML = '';
  triggers.forEach((trigger) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'button button--secondary';
    button.textContent = trigger.label;
    button.dataset.triggerId = trigger.id;
    button.addEventListener('click', () => {
      if (typeof onTrigger === 'function') {
        onTrigger(trigger);
      }
    });
    container.appendChild(button);
  });
}

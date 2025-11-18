import elements from './elements.js';

function noop() {}

export function initThemeManager({ onThemesChanged = noop, notify = noop } = {}) {
  const {
    manageThemesBtn,
    themeManager,
    themeManagerCloseBtn,
    themeManagerCloseFooterBtn,
    themeManagerChooseBtn,
    themeManagerReconnectBtn,
    themeManagerSupport,
    themeManagerConnect,
    themeManagerLoading,
    themeManagerContent,
    themeManagerClients,
    themeManagerStatus,
    themeManagerCount,
    themeManagerPath
  } = elements;

  if (!manageThemesBtn || !themeManager) {
    return;
  }

  const supportsFileSystemAccess = typeof window.showDirectoryPicker === 'function';

  let rootDirHandle = null;
  let clientThemesHandle = null;
  let indexFileHandle = null;
  let manifestFileHandle = null;
  let indexData = null;
  let manifestData = null;
  let busy = false;

  manageThemesBtn.addEventListener('click', () => {
    openOverlay();
  });

  [themeManagerCloseBtn, themeManagerCloseFooterBtn].forEach((btn) => {
    if (btn) {
      btn.addEventListener('click', () => {
        closeOverlay();
      });
    }
  });

  if (themeManagerChooseBtn) {
    themeManagerChooseBtn.addEventListener('click', () => {
      connectToOutputFolder();
    });
  }

  if (themeManagerReconnectBtn) {
    themeManagerReconnectBtn.addEventListener('click', () => {
      connectToOutputFolder();
    });
  }

  if (themeManagerClients) {
    themeManagerClients.addEventListener('click', (event) => {
      const target = event.target.closest('[data-action="delete-theme"]');
      if (!target || busy) return;
      const { clientId, themeId } = target.dataset;
      if (!clientId || !themeId) return;
      deleteTheme(clientId, themeId);
    });
  }

  function openOverlay() {
    themeManager.setAttribute('aria-hidden', 'false');
    themeManager.classList.add('visible');
    document.addEventListener('keydown', handleKeydown);
    if (!supportsFileSystemAccess) {
      if (themeManagerSupport) {
        themeManagerSupport.hidden = false;
      }
      if (themeManagerConnect) {
        themeManagerConnect.hidden = true;
      }
      if (themeManagerLoading) {
        themeManagerLoading.hidden = true;
      }
      if (themeManagerContent) {
        themeManagerContent.hidden = true;
      }
      return;
    }
    if (themeManagerSupport) {
      themeManagerSupport.hidden = true;
    }
    renderState();
  }

  function closeOverlay() {
    themeManager.setAttribute('aria-hidden', 'true');
    themeManager.classList.remove('visible');
    document.removeEventListener('keydown', handleKeydown);
    setStatus('');
    if (manageThemesBtn) {
      manageThemesBtn.focus();
    }
  }

  function handleKeydown(event) {
    if (event.key === 'Escape') {
      event.preventDefault();
      closeOverlay();
    }
  }

  function renderState() {
    if (!supportsFileSystemAccess) return;
    const connected = Boolean(rootDirHandle && indexFileHandle && manifestFileHandle);
    if (themeManagerConnect) {
      themeManagerConnect.hidden = connected;
    }
    if (themeManagerLoading) {
      const shouldShowLoading = connected && (!indexData || !manifestData);
      themeManagerLoading.hidden = !shouldShowLoading;
    }
    if (themeManagerContent) {
      const hasData = connected && indexData && manifestData;
      themeManagerContent.hidden = !hasData;
    }
    if (themeManagerReconnectBtn) {
      themeManagerReconnectBtn.hidden = !connected;
    }
    if (themeManagerPath) {
      themeManagerPath.textContent = connected ? `Connected to ${rootDirHandle.name || 'output'}` : '';
    }
    if (connected && indexData && manifestData) {
      renderClientList();
    } else if (themeManagerClients) {
      themeManagerClients.innerHTML = '';
    }
  }

  async function connectToOutputFolder() {
    if (!supportsFileSystemAccess) return;
    setStatus('');
    try {
      const directoryHandle = await window.showDirectoryPicker({
        mode: 'readwrite',
        id: 'pulse-theme-output'
      });
      if (!directoryHandle) return;
      const hasRootPermission = await ensurePermission(directoryHandle, 'readwrite');
      if (!hasRootPermission) {
        throw new Error('Permission denied for selected folder.');
      }
      const themesHandle = await directoryHandle.getDirectoryHandle('client-themes');
      const hasThemesPermission = await ensurePermission(themesHandle, 'readwrite');
      if (!hasThemesPermission) {
        throw new Error('Permission denied for client-themes directory.');
      }
      const indexHandle = await themesHandle.getFileHandle('index.json');
      const manifestHandle = await directoryHandle.getFileHandle('preview-manifest.json');
      const hasIndexPermission = await ensurePermission(indexHandle, 'readwrite');
      const hasManifestPermission = await ensurePermission(manifestHandle, 'readwrite');
      if (!hasIndexPermission || !hasManifestPermission) {
        throw new Error('Permission denied for required manifest files.');
      }

      rootDirHandle = directoryHandle;
      clientThemesHandle = themesHandle;
      indexFileHandle = indexHandle;
      manifestFileHandle = manifestHandle;
      setStatus('Loading theme catalog…');
      if (themeManagerLoading) {
        themeManagerLoading.hidden = false;
      }
      await loadThemeCatalog();
      setStatus('Theme catalog ready.', 'success');
    } catch (error) {
      if (error && error.name === 'AbortError') {
        return;
      }
      console.error('Theme manager connect failed', error);
      setStatus(`Failed to open folder: ${error.message}`, 'error');
      rootDirHandle = null;
      clientThemesHandle = null;
      indexFileHandle = null;
      manifestFileHandle = null;
      indexData = null;
      manifestData = null;
    } finally {
      renderState();
    }
  }

  async function loadThemeCatalog() {
    if (!indexFileHandle || !manifestFileHandle) return;
    setBusy(true);
    try {
      const [indexJson, manifestJson] = await Promise.all([
        readJson(indexFileHandle),
        readJson(manifestFileHandle)
      ]);
      indexData = indexJson && typeof indexJson === 'object' ? indexJson : {};
      manifestData = Array.isArray(manifestJson) ? manifestJson : [];
    } catch (error) {
      console.error('Failed to load theme catalog', error);
      indexData = null;
      manifestData = null;
      throw error;
    } finally {
      setBusy(false);
    }
  }

  async function deleteTheme(clientId, themeId) {
    if (!indexData || !manifestData) return;
    const clientEntry = indexData[clientId];
    if (!clientEntry) {
      setStatus(`Client ${clientId} not found in index.`, 'error');
      return;
    }
    const themeEntry = (clientEntry.themes || []).find((theme) => theme.id === themeId);
    if (!themeEntry) {
      setStatus(`Theme ${themeId} not found for client ${clientId}.`, 'error');
      return;
    }
    const clientLabel = clientEntry.name || clientId;
    const confirmed = window.confirm(
      `Delete theme "${themeEntry.name}" for ${clientLabel}? This removes the CSS file and updates manifests.`
    );
    if (!confirmed) return;

    setStatus(`Deleting ${themeEntry.name}…`);
    setBusy(true);
    try {
      const clientDirHandle = await clientThemesHandle.getDirectoryHandle(clientId);
      await ensurePermission(clientDirHandle, 'readwrite');
      await removeThemeFile(clientDirHandle, themeEntry.file);
      await updateClientThemesMetadata(clientDirHandle, themeEntry.name);

      clientEntry.themes = (clientEntry.themes || []).filter((theme) => theme.id !== themeId);
      if (clientEntry.themes.length === 0) {
        delete indexData[clientId];
      } else {
        clientEntry.lastUpdated = new Date().toISOString();
      }
      await writeJson(indexFileHandle, indexData);

      manifestData = manifestData.reduce((acc, entry) => {
        if (entry.clientId !== clientId) {
          acc.push(entry);
          return acc;
        }
        const remaining = (entry.themes || []).filter((theme) => theme.themeId !== themeId);
        if (remaining.length > 0) {
          acc.push({ ...entry, themes: remaining });
        }
        return acc;
      }, []);
      await writeJson(manifestFileHandle, manifestData);

      setStatus(`Deleted ${themeEntry.name}.`, 'success');
      renderClientList();
      // Theme generator moved to separate repository - CSS path no longer available
      const cssPath = null;
      await onThemesChanged({
        clientId,
        themeId,
        themeName: themeEntry.name,
        cssPath
      });
      notify(`Deleted theme ${themeEntry.name} (${clientId}).`, 'success');
    } catch (error) {
      console.error('Failed to delete theme', error);
      setStatus(`Failed to delete theme: ${error.message}`, 'error');
      notify(`Failed to delete theme ${themeId}: ${error.message}`, 'error');
    } finally {
      setBusy(false);
      renderState();
    }
  }

  function renderClientList() {
    if (!themeManagerClients) return;
    themeManagerClients.innerHTML = '';
    const entries = Object.entries(indexData || {}).sort(([a], [b]) =>
      a.localeCompare(b, undefined, { sensitivity: 'base' })
    );
    let themeTotal = 0;

    if (!entries.length) {
      const empty = document.createElement('div');
      empty.className = 'theme-manager__message';
      empty.textContent = 'No generated themes found in the selected folder.';
      themeManagerClients.appendChild(empty);
      updateSummary(0, 0);
      return;
    }

    entries.forEach(([clientId, client]) => {
      const themeList = Array.isArray(client.themes) ? client.themes : [];
      themeTotal += themeList.length;
      const wrapper = document.createElement('div');
      wrapper.className = 'theme-manager__client';

      const header = document.createElement('div');
      header.className = 'theme-manager__client-header';
      const title = document.createElement('span');
      title.textContent = client.name || clientId;
      const meta = document.createElement('span');
      meta.className = 'theme-manager__client-meta';
      meta.textContent = `${themeList.length} theme${themeList.length === 1 ? '' : 's'}`;
      header.appendChild(title);
      header.appendChild(meta);
      wrapper.appendChild(header);

      if (themeList.length) {
        const list = document.createElement('ul');
        list.className = 'theme-manager__themes';
        themeList
          .slice()
          .sort((a, b) => (a.name || a.id).localeCompare(b.name || b.id, undefined, { sensitivity: 'base' }))
          .forEach((theme, index) => {
            const item = document.createElement('li');
            item.className = 'theme-manager__theme';
            item.dataset.index = String(index);

            const info = document.createElement('div');
            info.className = 'theme-manager__theme-info';
            const name = document.createElement('strong');
            name.textContent = theme.name || theme.id;
            const metaLine = document.createElement('span');
            metaLine.className = 'theme-manager__theme-meta';
            metaLine.textContent = `${theme.id} — ${theme.file}`;
            info.appendChild(name);
            info.appendChild(metaLine);

            const actions = document.createElement('div');
            actions.className = 'theme-manager__theme-actions';
            const deleteBtn = document.createElement('button');
            deleteBtn.className = 'button button--ghost';
            deleteBtn.type = 'button';
            deleteBtn.dataset.action = 'delete-theme';
            deleteBtn.dataset.clientId = clientId;
            deleteBtn.dataset.themeId = theme.id;
            deleteBtn.textContent = 'Delete';
            actions.appendChild(deleteBtn);

            item.appendChild(info);
            item.appendChild(actions);
            list.appendChild(item);
          });
        wrapper.appendChild(list);
      }

      themeManagerClients.appendChild(wrapper);
    });

    updateSummary(entries.length, themeTotal);
  }

  function updateSummary(clientCount, themeCount) {
    if (!themeManagerCount) return;
    if (themeCount === 0) {
      themeManagerCount.textContent = 'No themes';
      return;
    }
    const clientLabel = clientCount === 1 ? 'client' : 'clients';
    const themeLabel = themeCount === 1 ? 'theme' : 'themes';
    themeManagerCount.textContent = `${themeCount} ${themeLabel} across ${clientCount} ${clientLabel}`;
  }

  function setBusy(value) {
    busy = Boolean(value);
    themeManager.classList.toggle('theme-manager--busy', busy);
  }

  function setStatus(message, tone) {
    if (!themeManagerStatus) return;
    themeManagerStatus.textContent = message || '';
    themeManagerStatus.classList.remove('theme-manager__status--error', 'theme-manager__status--success');
    if (!message) return;
    if (tone === 'error') {
      themeManagerStatus.classList.add('theme-manager__status--error');
    } else if (tone === 'success') {
      themeManagerStatus.classList.add('theme-manager__status--success');
    }
  }
}

async function ensurePermission(handle, mode = 'readwrite') {
  if (!handle || typeof handle.queryPermission !== 'function') return true;
  const options = { mode };
  if ((await handle.queryPermission(options)) === 'granted') {
    return true;
  }
  if ((await handle.requestPermission(options)) === 'granted') {
    return true;
  }
  return false;
}

async function readJson(fileHandle) {
  const file = await fileHandle.getFile();
  const text = await file.text();
  return text ? JSON.parse(text) : null;
}

async function writeJson(fileHandle, payload) {
  const writable = await fileHandle.createWritable();
  await writable.write(`${JSON.stringify(payload, null, 2)}\n`);
  await writable.close();
}

async function updateClientThemesMetadata(clientDirHandle, themeName) {
  try {
    const metaHandle = await clientDirHandle.getFileHandle('themes.json');
    const data = await readJson(metaHandle);
    if (!Array.isArray(data)) return;
    const filtered = data.filter((entry) => entry && entry.name !== themeName);
    await writeJson(metaHandle, filtered);
  } catch (error) {
    if (error && error.name === 'NotFoundError') {
      return;
    }
    throw error;
  }
}

async function removeThemeFile(clientDirHandle, fileName) {
  try {
    await clientDirHandle.removeEntry(fileName);
  } catch (error) {
    if (error && error.name === 'NotFoundError') {
      return;
    }
    throw error;
  }
}
